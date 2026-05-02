#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

prefer_microk8s_kubectl(){
  if command -v microk8s >/dev/null 2>&1; then echo "microk8s kubectl"; elif command -v kubectl >/dev/null 2>&1; then echo kubectl; else fail "No se encontró microk8s ni kubectl."; fi
}

KUBECTL="$(prefer_microk8s_kubectl)"
IIOT_NS="${IIOT_NS:-iiot-poc}"
WAZUH_NS="${WAZUH_NS:-security}"
OUT_DIR="${ROOT_DIR}/results/raw/scenario_d"
EVIDENCE_DIR="${ROOT_DIR}/evidence/wazuh"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
ITERATIONS="${ITERATIONS:-5}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
DOS_REQUESTS="${DOS_REQUESTS:-40}"
DOS_CONCURRENCY="${DOS_CONCURRENCY:-8}"
ATTACKS_FILE="${OUT_DIR}/mitre_ics_attacks.csv"
HTTP_OBS_FILE="${OUT_DIR}/attack_http_observations.csv"
MQTT_HOST="${MQTT_HOST:-10.10.0.151}"
HEALTH_URL="${HEALTH_URL:-http://10.10.0.152:8080/health}"
TELEMETRY_URL="${TELEMETRY_URL:-http://10.10.0.153:8080/telemetry}"
VULN_URL="${VULN_URL:-http://10.10.0.154:8080/health}"
WAZUH_EVENT_FILE="/var/ossec/logs/iiot-lab/scenario_d_attacks.json"

find_manager_pod(){
  local pod=""
  pod="$(${KUBECTL} -n "$WAZUH_NS" get pods -l 'app=wazuh-manager,node-type=master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "$pod" ]]; then
    pod="$(${KUBECTL} -n "$WAZUH_NS" get pods --no-headers 2>/dev/null | awk '/wazuh-manager-master/ && $3 == "Running" {print $1; exit}')"
  fi
  echo "$pod"
}

assert_pod_ready(){
  local ns="$1" pod="$2" label="$3"
  [[ -n "$pod" ]] || fail "No se pudo identificar pod ${label}."
  local phase ready node
  phase="$(${KUBECTL} -n "$ns" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  ready="$(${KUBECTL} -n "$ns" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)"
  node="$(${KUBECTL} -n "$ns" get pod "$pod" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
  [[ "$phase" == "Running" && "$ready" == "true" && -n "$node" ]] || fail "${label} no está Ready. pod=${pod}, phase=${phase:-unknown}, ready=${ready:-unknown}, node=${node:-none}"
}

ensure_mqtt_clients(){
  if command -v mosquitto_pub >/dev/null 2>&1; then return 0; fi
  fail "mosquitto_pub no está instalado. Ejecuta primero los scripts foundation o instala mosquitto-clients para mantener el experimento reproducible."
}

http_probe(){
  local attack_uid="$1" phase="$2" target="$3" url="$4"
  local ts result code total
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  result="$(curl -sS -o /dev/null -w '%{http_code},%{time_total}' --max-time 5 "$url" 2>/dev/null || echo '000,0')"
  code="$(echo "$result" | cut -d',' -f1)"
  total="$(echo "$result" | cut -d',' -f2)"
  echo "${ts},${attack_uid},${phase},${target},${url},${code},${total}" >> "$HTTP_OBS_FILE"
}

append_wazuh_event(){
  local event_json="$1" manager_pod="$2"
  printf '%s\n' "$event_json" | ${KUBECTL} -n "$WAZUH_NS" exec -i "$manager_pod" -- bash -lc "cat >> '${WAZUH_EVENT_FILE}'"
}

ensure_wazuh_scenario_d_localfile(){
  local manager_pod="$1"
  log "Validando localfile Wazuh para eventos Escenario D..."
  ${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- bash -lc "mkdir -p /var/ossec/logs/iiot-lab && touch '${WAZUH_EVENT_FILE}' && chown -R root:wazuh /var/ossec/logs/iiot-lab && chmod 640 '${WAZUH_EVENT_FILE}'"
  if ${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- bash -lc "grep -q '${WAZUH_EVENT_FILE}' /var/ossec/etc/ossec.conf" >/dev/null 2>&1; then
    summary_ok "Localfile Escenario D ya estaba configurado en Wazuh Manager"
    return 0
  fi
  log "Agregando localfile Escenario D a ossec.conf con reinicio controlado de Wazuh Manager..."
  ${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- python3 - <<'PY'
from pathlib import Path
path = Path('/var/ossec/etc/ossec.conf')
text = path.read_text(encoding='utf-8')
block = '''\n  <localfile>\n    <log_format>json</log_format>\n    <location>/var/ossec/logs/iiot-lab/scenario_d_attacks.json</location>\n  </localfile>\n'''
if 'scenario_d_attacks.json' not in text:
    text = text.replace('</ossec_config>', block + '\n</ossec_config>')
    path.write_text(text, encoding='utf-8')
PY
  ${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- bash -lc "/var/ossec/bin/wazuh-control restart"
  sleep 10
  summary_ok "Localfile Escenario D configurado y Wazuh Manager reiniciado de forma controlada"
}

run_t0809(){
  local i="$1" manager_pod="$2" uid="D-T0809-${i}"
  local start_utc start_epoch end_utc end_epoch status="OK" notes="mqtt_unauthorized_command_published"
  http_probe "$uid" "pre" "health-app" "$HEALTH_URL"
  start_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; start_epoch="$(date -u +%s)"
  local payload
  payload="{\"timestamp_utc\":\"${start_utc}\",\"scenario\":\"SCENARIO_D\",\"source_namespace\":\"${IIOT_NS}\",\"component\":\"mosquitto\",\"event_type\":\"unauthorized_command_message\",\"iiot_lab\":{\"scenario\":\"SCENARIO_D\",\"attack_uid\":\"${uid}\",\"attack_id\":\"T0809\",\"mitre_ics\":\"T0809\",\"technique\":\"Unauthorized Command Message\",\"asset\":\"crusher-01\",\"zone\":\"iiot-poc\",\"iteration\":${i}}}"
  if ! mosquitto_pub -h "$MQTT_HOST" -p 1883 -t "commands/mine-site-01/crusher-01/override" -m "$payload" >/dev/null 2>&1; then status="WARN"; notes="mqtt_publish_failed"; fi
  append_wazuh_event "$payload" "$manager_pod"
  sleep "$SLEEP_SECONDS"
  end_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; end_epoch="$(date -u +%s)"
  http_probe "$uid" "post" "health-app" "$HEALTH_URL"
  echo "${uid},${i},T0809,T0809,Unauthorized Command Message,mosquitto,${MQTT_HOST}:1883,${start_utc},${end_utc},${start_epoch},${end_epoch},mqtt_publish,1,${status},${notes}" >> "$ATTACKS_FILE"
}

run_t0814(){
  local i="$1" manager_pod="$2" uid="D-T0814-${i}"
  local start_utc start_epoch end_utc end_epoch status="OK" notes="manipulated_telemetry_posted"
  http_probe "$uid" "pre" "telemetry-api" "$TELEMETRY_URL"
  start_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; start_epoch="$(date -u +%s)"
  local payload http_code
  payload="{\"timestamp_utc\":\"${start_utc}\",\"scenario\":\"SCENARIO_D\",\"source_namespace\":\"${IIOT_NS}\",\"component\":\"telemetry-api\",\"event_type\":\"telemetry_manipulation\",\"temperature_c\":999.9,\"vibration_mm_s\":99.9,\"pressure_bar\":0.01,\"iiot_lab\":{\"scenario\":\"SCENARIO_D\",\"attack_uid\":\"${uid}\",\"attack_id\":\"T0814\",\"mitre_ics\":\"T0814\",\"technique\":\"Data Manipulation\",\"asset\":\"crusher-01\",\"zone\":\"iiot-poc\",\"iteration\":${i}}}"
  http_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 -X POST "$TELEMETRY_URL" -H 'Content-Type: application/json' -d "$payload" 2>/dev/null || echo '000')"
  [[ "$http_code" =~ ^2|3 ]] || { status="WARN"; notes="telemetry_post_http_${http_code}"; }
  append_wazuh_event "$payload" "$manager_pod"
  sleep "$SLEEP_SECONDS"
  end_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; end_epoch="$(date -u +%s)"
  http_probe "$uid" "post" "telemetry-api" "$TELEMETRY_URL"
  echo "${uid},${i},T0814,T0814,Data Manipulation,telemetry-api,${TELEMETRY_URL},${start_utc},${end_utc},${start_epoch},${end_epoch},http_post,1,${status},${notes}" >> "$ATTACKS_FILE"
}

run_t0860(){
  local i="$1" manager_pod="$2" uid="D-T0860-${i}"
  local start_utc start_epoch end_utc end_epoch status="OK" notes="controlled_http_flood"
  http_probe "$uid" "pre" "vulnerable-app" "$VULN_URL"
  start_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; start_epoch="$(date -u +%s)"
  local payload
  payload="{\"timestamp_utc\":\"${start_utc}\",\"scenario\":\"SCENARIO_D\",\"source_namespace\":\"${IIOT_NS}\",\"component\":\"vulnerable-app\",\"event_type\":\"availability_degradation_http_flood\",\"dos_requests\":${DOS_REQUESTS},\"dos_concurrency\":${DOS_CONCURRENCY},\"iiot_lab\":{\"scenario\":\"SCENARIO_D\",\"attack_uid\":\"${uid}\",\"attack_id\":\"T0860\",\"mitre_ics\":\"T0860\",\"technique\":\"Denial of Service\",\"asset\":\"vulnerable-app\",\"zone\":\"iiot-poc\",\"iteration\":${i}}}"
  append_wazuh_event "$payload" "$manager_pod"
  seq 1 "$DOS_REQUESTS" | xargs -P "$DOS_CONCURRENCY" -I{} sh -c "curl -sS -o /dev/null --max-time 3 '${VULN_URL}' >/dev/null 2>&1 || true"
  end_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; end_epoch="$(date -u +%s)"
  http_probe "$uid" "post" "vulnerable-app" "$VULN_URL"
  echo "${uid},${i},T0860,T0860,Denial of Service,vulnerable-app,${VULN_URL},${start_utc},${end_utc},${start_epoch},${end_epoch},http_flood,${DOS_REQUESTS},${status},${notes}" >> "$ATTACKS_FILE"
}

mkdir -p "$OUT_DIR" "$EVIDENCE_DIR"
log "Ejecutando Escenario D — ataques MITRE ATT&CK for ICS controlados"
log "Cliente Kubernetes: ${KUBECTL}"
log "Iteraciones: ${ITERATIONS}; Sleep: ${SLEEP_SECONDS}s; DoS requests: ${DOS_REQUESTS}; DoS concurrency: ${DOS_CONCURRENCY}"

${KUBECTL} get ns "$IIOT_NS" >/dev/null 2>&1 || fail "No existe namespace ${IIOT_NS}."
${KUBECTL} get ns monitoring >/dev/null 2>&1 || fail "No existe namespace monitoring."
${KUBECTL} get ns "$WAZUH_NS" >/dev/null 2>&1 || fail "No existe namespace ${WAZUH_NS}."
${KUBECTL} -n "$IIOT_NS" rollout status deploy/health-app --timeout=180s >/dev/null
${KUBECTL} -n "$IIOT_NS" rollout status deploy/telemetry-api --timeout=180s >/dev/null
${KUBECTL} -n "$IIOT_NS" rollout status deploy/vulnerable-app --timeout=180s >/dev/null
${KUBECTL} -n "$IIOT_NS" rollout status deploy/mosquitto --timeout=180s >/dev/null
ensure_mqtt_clients

manager_pod="$(find_manager_pod)"
assert_pod_ready "$WAZUH_NS" "$manager_pod" "Wazuh Manager master"
ensure_wazuh_scenario_d_localfile "$manager_pod"

echo "attack_uid,iteration,attack_id,mitre_ics,technique,target_component,target_endpoint,start_utc,end_utc,start_epoch,end_epoch,stimulus_type,stimulus_count,status,notes" > "$ATTACKS_FILE"
echo "timestamp_utc,attack_uid,phase,target,url,http_code,time_total_seconds" > "$HTTP_OBS_FILE"

for i in $(seq 1 "$ITERATIONS"); do
  run_t0809 "$i" "$manager_pod"
  sleep "$SLEEP_SECONDS"
  run_t0814 "$i" "$manager_pod"
  sleep "$SLEEP_SECONDS"
  run_t0860 "$i" "$manager_pod"
  sleep "$SLEEP_SECONDS"
done

csv_has_data "$ATTACKS_FILE"
csv_has_data "$HTTP_OBS_FILE"

${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- bash -lc "tail -n 1000 '${WAZUH_EVENT_FILE}'" > "$EVIDENCE_DIR/${TS}-scenario-d-attacks-events.ndjson" 2>/dev/null || true
${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- bash -lc 'tail -n 1000 /var/ossec/logs/alerts/alerts.json' > "$EVIDENCE_DIR/${TS}-scenario-d-wazuh-alerts-tail.json" 2>/dev/null || true
${KUBECTL} -n "$WAZUH_NS" logs --tail=300 -l app=wazuh-manager > "$EVIDENCE_DIR/${TS}-scenario-d-wazuh-manager-logs.txt" 2>/dev/null || true

cat > "$OUT_DIR/scenario_d_attack_metadata.json" <<EOF_META
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scenario": "SCENARIO_D",
  "scope": "MITRE ATT&CK for ICS controlled attacks over IIoT Foundation with Zabbix and Wazuh active",
  "iterations": ${ITERATIONS},
  "sleep_seconds": ${SLEEP_SECONDS},
  "dos_requests": ${DOS_REQUESTS},
  "dos_concurrency": ${DOS_CONCURRENCY},
  "attacks": ["T0809", "T0814", "T0860"],
  "datasets": [
    "results/raw/scenario_d/mitre_ics_attacks.csv",
    "results/raw/scenario_d/attack_http_observations.csv"
  ]
}
EOF_META

summary_header "Scenario D MITRE ICS Controlled Attacks"
summary_ok "Ataques controlados ejecutados: T0809, T0814, T0860"
summary_ok "Dataset generado: results/raw/scenario_d/mitre_ics_attacks.csv"
summary_ok "Observaciones HTTP generadas: results/raw/scenario_d/attack_http_observations.csv"
summary_ok "Eventos SCENARIO_D escritos en Wazuh Manager localfile"
summary_ok "Evidencia Wazuh exportada en evidence/wazuh/"
summary_ok "Escenario D listo para correlación Zabbix/Wazuh"
