#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

KUBECTL="$(detect_kubectl)"
TS="$(date -u +%Y%m%d_%H%M%S)"
FREEZE_DIR="${ROOT_DIR}/baseline/scenario_A_${TS}"

mkdir -p "$FREEZE_DIR"

log "Validando resultados previos..."
csv_has_data "${ROOT_DIR}/results/raw/http_baseline.csv"
csv_has_data "${ROOT_DIR}/results/raw/mqtt_messages.csv"
csv_has_data "${ROOT_DIR}/results/raw/k8s_resources.csv"
[[ -s "${ROOT_DIR}/results/raw/experiment_metadata.json" ]] || fail "Falta experiment_metadata.json"

log "Exportando snapshots Kubernetes..."
${KUBECTL} get nodes -o wide > "${FREEZE_DIR}/nodes.txt"
${KUBECTL} get all -A -o yaml > "${FREEZE_DIR}/cluster_all.yaml"
${KUBECTL} get pods -n iiot-poc -o wide > "${FREEZE_DIR}/pods_iiot_poc.txt"
${KUBECTL} get svc -n iiot-poc -o wide > "${FREEZE_DIR}/services_iiot_poc.txt"
${KUBECTL} top nodes > "${FREEZE_DIR}/top_nodes.txt" || true
${KUBECTL} top pods -A > "${FREEZE_DIR}/top_pods_all.txt" || true

log "Copiando resultados raw..."
cp -a "${ROOT_DIR}/results/raw" "${FREEZE_DIR}/results_raw"

log "Generando archivo comprimido del freeze..."
tar -czf "${ROOT_DIR}/baseline/scenario_A_${TS}.tar.gz" -C "${ROOT_DIR}/baseline" "scenario_A_${TS}"

ARCHIVE="${ROOT_DIR}/baseline/scenario_A_${TS}.tar.gz"

summary_header "Freeze Escenario A"
summary_ok "Resultados raw validados"
summary_ok "Snapshot de nodos exportado"
summary_ok "Snapshot completo cluster_all.yaml exportado"
summary_ok "Pods y servicios iiot-poc exportados"
summary_ok "Métricas top nodes/top pods exportadas cuando estuvieron disponibles"
summary_ok "Resultados raw copiados al directorio de congelamiento"
summary_ok "Archivo comprimido generado: ${ARCHIVE}"
summary_ok "Escenario A queda congelado para comparación con Zabbix/Wazuh/correlación"
