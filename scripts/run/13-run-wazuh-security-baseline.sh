#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

prefer_microk8s_kubectl(){
  if command -v microk8s >/dev/null 2>&1; then echo "microk8s kubectl"; elif command -v kubectl >/dev/null 2>&1; then echo kubectl; else fail "No se encontró microk8s ni kubectl."; fi
}

KUBECTL="$(prefer_microk8s_kubectl)"
NS="${WAZUH_NS:-security}"
OUT_DIR="${ROOT_DIR}/results/raw/scenario_c"
OUT_FILE="${OUT_DIR}/wazuh_security_baseline.csv"
EVIDENCE_DIR="${ROOT_DIR}/evidence/wazuh"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
ITERATIONS="${ITERATIONS:-3}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

find_manager_pod(){
  local pod=""
  pod="$(${KUBECTL} -n "$NS" get pods -l 'app=wazuh-manager,node-type=master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "$pod" ]]; then
    pod="$(${KUBECTL} -n "$NS" get pods --no-headers 2>/dev/null | awk '/wazuh-manager-master/ && $3 == "Running" {print $1; exit}')"
  fi
  echo "$pod"
}

assert_manager_ready(){
  local pod="$1"
  [[ -n "$pod" ]] || fail "No se pudo identificar pod Wazuh Manager master en namespace ${NS}."
  local phase node ready
  phase="$(${KUBECTL} -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  node="$(${KUBECTL} -n "$NS" get pod "$pod" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
  ready="$(${KUBECTL} -n "$NS" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)"
  [[ "$phase" == "Running" && -n "$node" && "$ready" == "true" ]] || fail "Wazuh Manager no está listo. pod=${pod}, phase=${phase:-unknown}, ready=${ready:-unknown}, node=${node:-none}"
}

mkdir -p "$OUT_DIR" "$EVIDENCE_DIR"

log "Ejecutando baseline de seguridad Escenario C"
log "Cliente Kubernetes: ${KUBECTL}"
${KUBECTL} get ns iiot-poc >/dev/null 2>&1 || fail "No existe namespace iiot-poc."
${KUBECTL} get ns monitoring >/dev/null 2>&1 || fail "No existe namespace monitoring."
${KUBECTL} get ns "$NS" >/dev/null 2>&1 || fail "No existe namespace ${NS}."

manager_pod="$(find_manager_pod)"
assert_manager_ready "$manager_pod"

${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'test -f /var/ossec/etc/rules/iiot_local_rules.xml' >/dev/null 2>&1 || fail "No existe /var/ossec/etc/rules/iiot_local_rules.xml. Ejecuta 11-deploy-wazuh-security.sh."
${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'grep -q scenario_c_baseline.json /var/ossec/etc/ossec.conf' >/dev/null 2>&1 || fail "No está configurado el localfile scenario_c_baseline.json. Ejecuta 11-deploy-wazuh-security.sh."

echo "timestamp_utc,scenario,source_namespace,component,event_type,attack_id,mitre_ics,collection_mode,wazuh_injection" > "$OUT_FILE"

for i in $(seq 1 "$ITERATIONS"); do
  for component in health-app telemetry-api vulnerable-app mosquitto iiot-sensor; do
    if ${KUBECTL} -n iiot-poc get deploy "$component" >/dev/null 2>&1 || ${KUBECTL} -n iiot-poc get svc "$component" >/dev/null 2>&1 || ${KUBECTL} -n iiot-poc get svc "${component}-lb" >/dev/null 2>&1; then
      ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      event="{\"timestamp_utc\":\"${ts}\",\"scenario\":\"SCENARIO_C\",\"source_namespace\":\"iiot-poc\",\"component\":\"${component}\",\"event_type\":\"baseline_security_probe\",\"iiot_lab\":{\"scenario\":\"SCENARIO_C\",\"attack_id\":\"NONE\",\"asset\":\"${component}\",\"zone\":\"iiot-poc\",\"iteration\":${i}}}"
      printf '%s\n' "$event" | ${KUBECTL} -n "$NS" exec -i "$manager_pod" -- bash -lc 'cat >> /var/ossec/logs/iiot-lab/scenario_c_baseline.json'
      echo "${ts},SCENARIO_C,iiot-poc,${component},baseline_security_probe,NONE,NONE,wazuh_localfile_json,YES" >> "$OUT_FILE"
    fi
  done
  sleep "$SLEEP_SECONDS"
done

csv_has_data "$OUT_FILE"

log "Exportando logs y eventos Wazuh relacionados con baseline..."
${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'tail -n 200 /var/ossec/logs/iiot-lab/scenario_c_baseline.json' > "$EVIDENCE_DIR/${TS}-scenario-c-baseline-events.ndjson" 2>/dev/null || true
${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'tail -n 200 /var/ossec/logs/alerts/alerts.json' > "$EVIDENCE_DIR/${TS}-wazuh-alerts-tail.json" 2>/dev/null || true
${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'tail -n 200 /var/ossec/logs/archives/archives.json' > "$EVIDENCE_DIR/${TS}-wazuh-archives-tail.json" 2>/dev/null || true
${KUBECTL} -n "$NS" logs --tail=200 -l app=wazuh-dashboard > "$EVIDENCE_DIR/${TS}-wazuh-dashboard-logs.txt" 2>/dev/null || true
${KUBECTL} -n "$NS" logs --tail=200 -l app=wazuh-manager > "$EVIDENCE_DIR/${TS}-wazuh-manager-logs.txt" 2>/dev/null || true
${KUBECTL} -n "$NS" logs --tail=200 -l app=wazuh-indexer > "$EVIDENCE_DIR/${TS}-wazuh-indexer-logs.txt" 2>/dev/null || true

cat > "$EVIDENCE_DIR/${TS}-scenario-c-baseline-metadata.json" <<EOF_META
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scenario": "SCENARIO_C",
  "scope": "Foundation IIoT + Zabbix + Wazuh",
  "deployment_model": "Wazuh single-node/all-in-one laboratory deployment on MicroK8s single-node",
  "methodological_rationale": "Prioritize reproducibility, experimental control, and reduction of non-hypothesis variables",
  "excluded_scope": ["Kubernetes hardening", "Falco", "CIS benchmark", "runtime security", "HA Wazuh clustering", "Prometheus", "Grafana", "Loki", "Istio"],
  "dataset": "results/raw/scenario_c/wazuh_security_baseline.csv",
  "event_source": "Wazuh Manager localfile JSON baseline events from IIoT services"
}
EOF_META

summary_header "Scenario C Wazuh Security Baseline"
summary_ok "Dataset generado: results/raw/scenario_c/wazuh_security_baseline.csv"
summary_ok "Eventos estructurados SCENARIO_C escritos en Wazuh Manager master"
summary_ok "Eventos NDJSON exportados en evidence/wazuh/"
summary_ok "Logs Wazuh exportados en evidence/wazuh/"
summary_ok "Metadata experimental exportada en evidence/wazuh/"
summary_ok "Escenario C listo para freeze reproducible"
