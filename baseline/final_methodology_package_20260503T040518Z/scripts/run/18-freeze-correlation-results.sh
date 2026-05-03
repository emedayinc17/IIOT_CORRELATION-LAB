#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

prefer_microk8s_kubectl(){
  if command -v microk8s >/dev/null 2>&1; then echo "microk8s kubectl"; elif command -v kubectl >/dev/null 2>&1; then echo kubectl; else fail "No se encontró microk8s ni kubectl."; fi
}

KUBECTL="$(prefer_microk8s_kubectl)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
FREEZE_DIR="${ROOT_DIR}/baseline/scenario_d_correlation_${TS}"
EVIDENCE_DIR="${ROOT_DIR}/evidence/wazuh"

phase "1/2" "Congelamiento reproducible de resultados finales D." "Reproducible freeze of final Scenario D results."
log "Congelando Escenario D — MITRE ICS + correlación Zabbix/Wazuh"
mkdir -p "$FREEZE_DIR/results_raw" "$FREEZE_DIR/results_processed" "$FREEZE_DIR/results_tables" "$FREEZE_DIR/results_figures" "$FREEZE_DIR/evidence" "$FREEZE_DIR/k8s"

[[ -s "${ROOT_DIR}/results/raw/scenario_d/mitre_ics_attacks.csv" ]] || fail "Falta results/raw/scenario_d/mitre_ics_attacks.csv"
[[ -s "${ROOT_DIR}/results/processed/correlation_dataset.csv" ]] || fail "Falta results/processed/correlation_dataset.csv"
[[ -s "${ROOT_DIR}/results/tables/table_attack_detection.csv" ]] || fail "Falta results/tables/table_attack_detection.csv"
[[ -s "${ROOT_DIR}/results/figures/figure_detection_comparison.svg" ]] || fail "Falta results/figures/figure_detection_comparison.svg"

cp -a "${ROOT_DIR}/results/raw/scenario_d/." "$FREEZE_DIR/results_raw/"
cp -a "${ROOT_DIR}/results/processed/." "$FREEZE_DIR/results_processed/"
cp -a "${ROOT_DIR}/results/tables/." "$FREEZE_DIR/results_tables/"
cp -a "${ROOT_DIR}/results/figures/." "$FREEZE_DIR/results_figures/"

${KUBECTL} get nodes -o wide > "$FREEZE_DIR/k8s/nodes.txt" 2>/dev/null || true
${KUBECTL} get all -n iiot-poc -o wide > "$FREEZE_DIR/k8s/iiot-poc-all.txt" 2>/dev/null || true
${KUBECTL} get all -n monitoring -o wide > "$FREEZE_DIR/k8s/monitoring-all.txt" 2>/dev/null || true
${KUBECTL} get all -n security -o wide > "$FREEZE_DIR/k8s/security-all.txt" 2>/dev/null || true
${KUBECTL} get pvc -A -o wide > "$FREEZE_DIR/k8s/pvc-all.txt" 2>/dev/null || true
${KUBECTL} get configmap -n security -o yaml > "$FREEZE_DIR/k8s/security-configmaps.yaml" 2>/dev/null || true

find "$EVIDENCE_DIR" -maxdepth 1 -type f -name "${TS:0:8}*scenario-d*" -exec cp -a {} "$FREEZE_DIR/evidence/" \; 2>/dev/null || true
find "$EVIDENCE_DIR" -maxdepth 1 -type f -name "*scenario-d*" -newermt "1 hour ago" -exec cp -a {} "$FREEZE_DIR/evidence/" \; 2>/dev/null || true

cat > "$FREEZE_DIR/scenario_d_freeze_metadata.json" <<EOF_META
{
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scenario": "SCENARIO_D",
  "scope": "MITRE ATT&CK for ICS controlled attacks and Zabbix/Wazuh correlation",
  "platform": "MicroK8s single-node Ubuntu 24.04 containerd Calico MetalLB microk8s-hostpath",
  "input_scenarios": ["A", "B", "C"],
  "datasets": [
    "results_raw/mitre_ics_attacks.csv",
    "results_raw/wazuh_security_events.csv",
    "results_raw/zabbix_correlation_metrics.csv",
    "results_processed/correlation_dataset.csv",
    "results_tables/table_attack_detection.csv",
    "results_tables/table_correlation_latency.csv",
    "results_tables/table_sla_impact.csv"
  ],
  "excluded_scope": ["Kubernetes security", "HA Wazuh", "Falco", "Prometheus", "Grafana", "Loki", "service mesh"]
}
EOF_META

(
  cd "$FREEZE_DIR"
  find . -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

tar -czf "${FREEZE_DIR}.tar.gz" -C "$(dirname "$FREEZE_DIR")" "$(basename "$FREEZE_DIR")"

cat > "$EVIDENCE_DIR/${TS}-scenario-d-freeze-summary.md" <<EOF_SUMMARY
# Scenario D Freeze Summary

- Timestamp UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Freeze directory: ${FREEZE_DIR}
- Archive: ${FREEZE_DIR}.tar.gz
- Scope: MITRE ICS controlled attacks + Zabbix/Wazuh correlation
- SHA256SUMS: generated
EOF_SUMMARY

phase "2/2" "Resumen de freeze final." "Final freeze summary."
summary_header "Scenario D Correlation Freeze"
summary_ok "Freeze generado: baseline/$(basename "$FREEZE_DIR")"
summary_ok "Archivo comprimido generado: baseline/$(basename "$FREEZE_DIR").tar.gz"
summary_ok "Datasets raw/processed/tables/figures incluidos"
summary_ok "Snapshots Kubernetes incluidos"
summary_ok "SHA256SUMS generado"
summary_ok "Escenario D listo para análisis y redacción de resultados del paper"
