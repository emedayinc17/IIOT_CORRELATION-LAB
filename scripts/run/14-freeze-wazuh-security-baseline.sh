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
FREEZE_DIR="${ROOT_DIR}/baseline/scenario_c_wazuh_security"
EVIDENCE_DIR="${ROOT_DIR}/evidence/wazuh"
FROZEN_MANIFEST_DIR="${ROOT_DIR}/kubernetes/security/wazuh-frozen"
DASHBOARD_IP="${WAZUH_DASHBOARD_IP:-10.10.0.161}"
MANAGER_IP="${WAZUH_MANAGER_IP:-10.10.0.162}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

command -v sha256sum >/dev/null 2>&1 || fail "No se encontró sha256sum."
mkdir -p "$FREEZE_DIR" "$EVIDENCE_DIR"

validate_dashboard_ready_for_freeze(){
  local body="/tmp/wazuh_dashboard_freeze_body_${TS}.txt" headers="/tmp/wazuh_dashboard_freeze_headers_${TS}.txt"
  log "Validando Dashboard antes del freeze: https://${DASHBOARD_IP}"
  if curl -k -sS -D "$headers" --max-time 10 "https://${DASHBOARD_IP}" -o "$body"; then
    cp "$headers" "$EVIDENCE_DIR/${TS}-freeze-dashboard-headers.txt" 2>/dev/null || true
    cp "$body" "$EVIDENCE_DIR/${TS}-freeze-dashboard-body.txt" 2>/dev/null || true
    if grep -qi "server is not ready yet" "$body"; then
      fail "Dashboard responde, pero aún indica 'server is not ready yet'. No conviene congelar Escenario C todavía. Ejecuta 12-validate-wazuh-security.sh nuevamente en unos minutos."
    fi
    echo "[OK] Dashboard externo listo para freeze."
  else
    fail "Dashboard externo no responde en https://${DASHBOARD_IP}. No se congela Escenario C."
  fi
}

validate_api_port_for_freeze(){
  log "Validando puerto API Wazuh antes del freeze: ${MANAGER_IP}:55000"
  if timeout 5 bash -lc "</dev/tcp/${MANAGER_IP}/55000" >/dev/null 2>&1; then
    echo "[OK] Puerto API Wazuh 55000 accesible para freeze."
  else
    fail "Puerto API Wazuh 55000 no responde externamente. No se congela Escenario C."
  fi
}

export_live_frozen_manifests(){
  mkdir -p "$FROZEN_MANIFEST_DIR"
  log "Actualizando snapshot local de manifiestos Wazuh en kubernetes/security/wazuh-frozen/"
  for r in \
    sc/wazuh-storage \
    cm/dashboard-conf cm/indexer-conf cm/wazuh-conf cm/wazuh-iiot-rules cm/wazuh-single-node-methodology cm/wazuh-version-lock cm/scenario-c-security-event-schema \
    secret/dashboard-cred secret/indexer-cred secret/wazuh-api-cred secret/wazuh-authd-pass secret/wazuh-cluster-key \
    svc/dashboard svc/indexer svc/wazuh svc/wazuh-cluster svc/wazuh-indexer svc/wazuh-dashboard-lb svc/wazuh-manager-lb \
    statefulset/wazuh-indexer statefulset/wazuh-manager-master deployment/wazuh-dashboard; do
    kind="${r%%/*}"; name="${r##*/}"; out="${FROZEN_MANIFEST_DIR}/${kind}-${name}.yaml"
    if [[ "$kind" == "sc" ]]; then
      ${KUBECTL} get "$r" -o yaml > "$out" 2>/dev/null || true
    else
      ${KUBECTL} -n "$NS" get "$r" -o yaml > "$out" 2>/dev/null || true
    fi
  done
  cat > "${FROZEN_MANIFEST_DIR}/MANIFEST-SNAPSHOT.md" <<EOF_MANIFEST
# Scenario C Wazuh frozen manifest snapshot

- Generated UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Source: validated live MicroK8s namespace ${NS}
- Purpose: reproducibility evidence and offline traceability for the paper
- Scope: Wazuh indexer, manager master, dashboard, controlled services, rules/config maps

This is not a phase README. It is an evidence manifest stored under kubernetes/security/.
EOF_MANIFEST
}

log "Congelando Escenario C — Wazuh Security Baseline"
[[ -f "${ROOT_DIR}/results/raw/scenario_c/wazuh_security_baseline.csv" ]] || fail "Falta results/raw/scenario_c/wazuh_security_baseline.csv. Ejecuta primero 13-run-wazuh-security-baseline.sh."

${KUBECTL} get ns "$NS" >/dev/null 2>&1 || fail "No existe namespace ${NS}."
${KUBECTL} -n "$NS" rollout status statefulset/wazuh-indexer --timeout=120s >/dev/null
${KUBECTL} -n "$NS" rollout status statefulset/wazuh-manager-master --timeout=120s >/dev/null
${KUBECTL} -n "$NS" rollout status deployment/wazuh-dashboard --timeout=120s >/dev/null
validate_dashboard_ready_for_freeze
validate_api_port_for_freeze
export_live_frozen_manifests

cp "${ROOT_DIR}/results/raw/scenario_c/wazuh_security_baseline.csv" "$FREEZE_DIR/wazuh_security_baseline.csv"

${KUBECTL} -n "$NS" get all -o yaml > "$FREEZE_DIR/k8s-security-all.yaml"
${KUBECTL} -n "$NS" get pvc -o yaml > "$FREEZE_DIR/k8s-security-pvc.yaml" || true
${KUBECTL} -n "$NS" get configmap -o yaml > "$FREEZE_DIR/k8s-security-configmaps.yaml"
${KUBECTL} -n "$NS" get svc -o wide > "$FREEZE_DIR/k8s-security-services.txt"
${KUBECTL} get nodes -o wide > "$FREEZE_DIR/k8s-nodes.txt"
${KUBECTL} get sc -o yaml > "$FREEZE_DIR/k8s-storageclasses.yaml"

if [[ -d "$FROZEN_MANIFEST_DIR" ]]; then
  rm -rf "$FREEZE_DIR/wazuh-frozen-manifests"
  cp -a "$FROZEN_MANIFEST_DIR" "$FREEZE_DIR/wazuh-frozen-manifests"
fi

latest_events="$(ls -1t "$EVIDENCE_DIR"/*scenario-c-baseline-events.ndjson 2>/dev/null | head -1 || true)"
if [[ -n "$latest_events" ]]; then cp "$latest_events" "$FREEZE_DIR/scenario-c-baseline-events.ndjson"; fi

cat > "$FREEZE_DIR/scenario_c_freeze_metadata.json" <<EOF_META
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scenario": "SCENARIO_C",
  "scope": "Foundation IIoT + Zabbix + Wazuh",
  "wazuh_deployment_model": "single-node/all-in-one laboratory deployment on MicroK8s single-node",
  "dataset": "baseline/scenario_c_wazuh_security/wazuh_security_baseline.csv",
  "frozen_manifests": "baseline/scenario_c_wazuh_security/wazuh-frozen-manifests",
  "checksums": "baseline/scenario_c_wazuh_security/SHA256SUMS",
  "excluded_scope": ["Kubernetes hardening", "HA SIEM clustering", "Falco", "CIS benchmark", "runtime security", "Prometheus", "Grafana", "Loki", "Istio"]
}
EOF_META

(cd "$ROOT_DIR" && find baseline/scenario_c_wazuh_security -type f -print0 | sort -z | xargs -0 sha256sum) > "$FREEZE_DIR/SHA256SUMS"

cat > "$EVIDENCE_DIR/${TS}-scenario-c-freeze-summary.md" <<EOF_SUMMARY
# Scenario C Freeze Summary

- Timestamp UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Scenario: SCENARIO_C
- Scope: Foundation IIoT + Zabbix + Wazuh
- Wazuh deployment model: single-node/all-in-one laboratory deployment
- Dataset: baseline/scenario_c_wazuh_security/wazuh_security_baseline.csv
- Frozen manifests: baseline/scenario_c_wazuh_security/wazuh-frozen-manifests
- Checksums: baseline/scenario_c_wazuh_security/SHA256SUMS
- Exclusions: Kubernetes hardening, HA SIEM clustering, Falco, CIS benchmark, runtime security
EOF_SUMMARY

summary_header "Scenario C Wazuh Security Freeze"
summary_ok "Dashboard y API Wazuh validados antes del freeze"
summary_ok "Dataset Escenario C congelado"
summary_ok "Snapshot Kubernetes namespace security exportado"
summary_ok "PVC, servicios, configmaps y storageclasses exportados"
summary_ok "Manifiestos Wazuh congelados integrados al freeze"
summary_ok "SHA256SUMS generado"
summary_ok "Resumen freeze generado en evidence/wazuh/"
summary_ok "Escenario C queda listo para Escenario D"
