#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

KUBECTL="$(detect_kubectl)"
RESULTS_DIR="${ROOT_DIR}/results/raw"

mkdir -p "$RESULTS_DIR"

log "Validando prerequisitos del Escenario B..."
${KUBECTL} get ns iiot-poc >/dev/null || fail "Foundation no está desplegada."
${KUBECTL} get ns monitoring >/dev/null || fail "Zabbix no está desplegado."

wait_http "health-app" "http://10.10.0.152:8080/health" 5 2
wait_http "telemetry-api" "http://10.10.0.153:8080/telemetry" 5 2
wait_http "vulnerable-app" "http://10.10.0.154:8080/health" 5 2
wait_http "zabbix-ui" "http://10.10.0.160" 5 2
wait_mqtt "10.10.0.151" 5 2

log "Limpiando resultados previos del Escenario B..."
rm -f "${RESULTS_DIR}/http_baseline_zabbix.csv" \
      "${RESULTS_DIR}/mqtt_messages_zabbix.csv" \
      "${RESULTS_DIR}/k8s_resources_zabbix.csv" \
      "${RESULTS_DIR}/zabbix_items_snapshot.csv" \
      "${RESULTS_DIR}/experiment_metadata_zabbix.json"

START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "${RESULTS_DIR}/experiment_metadata_zabbix.json" <<EOF
{
  "scenario": "B",
  "name": "Operational Baseline with Zabbix",
  "start_timestamp_utc": "${START_TS}",
  "iterations": "${ITERATIONS:-300}",
  "sleep_seconds": "${SLEEP_SECONDS:-2}",
  "duration_seconds": "${DURATION_SECONDS:-600}",
  "services": {
    "mqtt": "10.10.0.151:1883",
    "health_app": "10.10.0.152:8080",
    "telemetry_api": "10.10.0.153:8080",
    "vulnerable_app": "10.10.0.154:8080",
    "zabbix_ui": "10.10.0.160:80"
  }
}
EOF

log "Iniciando collectors del Escenario B."

bash "${ROOT_DIR}/scripts/collectors/collect-http.sh" "${RESULTS_DIR}/http_baseline_zabbix.csv" &
HTTP_PID=$!

bash "${ROOT_DIR}/scripts/collectors/collect-mqtt.sh" "${RESULTS_DIR}/mqtt_messages_zabbix.csv" &
MQTT_PID=$!

bash "${ROOT_DIR}/scripts/collectors/collect-k8s.sh" "${RESULTS_DIR}/k8s_resources_zabbix.csv" &
K8S_PID=$!

OUT_FILE="${RESULTS_DIR}/zabbix_items_snapshot.csv" \
bash "${ROOT_DIR}/scripts/collectors/collect-zabbix-items.sh" "${RESULTS_DIR}/zabbix_items_snapshot.csv" &
ZBX_PID=$!

trap 'warn "Interrupción detectada. Deteniendo collectors..."; kill $HTTP_PID $MQTT_PID $K8S_PID $ZBX_PID 2>/dev/null || true; exit 130' INT TERM

echo "[INFO] HTTP collector PID: ${HTTP_PID}"
echo "[INFO] MQTT collector PID: ${MQTT_PID}"
echo "[INFO] K8S collector PID: ${K8S_PID}"
echo "[INFO] Zabbix collector PID: ${ZBX_PID}"

wait "$HTTP_PID"
wait "$MQTT_PID"
wait "$K8S_PID"
wait "$ZBX_PID"

END_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

log "Validando archivos generados..."
csv_has_data "${RESULTS_DIR}/http_baseline_zabbix.csv"
csv_has_data "${RESULTS_DIR}/mqtt_messages_zabbix.csv"
csv_has_data "${RESULTS_DIR}/k8s_resources_zabbix.csv"
csv_has_data "${RESULTS_DIR}/zabbix_items_snapshot.csv"

python3 - <<PY
import json
from pathlib import Path
p=Path("${RESULTS_DIR}/experiment_metadata_zabbix.json")
d=json.loads(p.read_text())
d["end_timestamp_utc"]="${END_TS}"
d["status"]="completed"
p.write_text(json.dumps(d, indent=2))
PY

HTTP_LINES=$(wc -l < "${RESULTS_DIR}/http_baseline_zabbix.csv")
MQTT_LINES=$(wc -l < "${RESULTS_DIR}/mqtt_messages_zabbix.csv")
K8S_LINES=$(wc -l < "${RESULTS_DIR}/k8s_resources_zabbix.csv")
ZBX_LINES=$(wc -l < "${RESULTS_DIR}/zabbix_items_snapshot.csv")

log "Resumen de archivos:"
ls -lh "${RESULTS_DIR}"

summary_header "Escenario B — Operational Baseline with Zabbix"
summary_ok "Prerequisitos Foundation y Zabbix validados"
summary_ok "HTTP collector completado: ${HTTP_LINES} líneas"
summary_ok "MQTT collector completado: ${MQTT_LINES} líneas"
summary_ok "K8s resource collector completado: ${K8S_LINES} líneas"
summary_ok "Zabbix item collector completado: ${ZBX_LINES} líneas"
summary_ok "Metadata experimental actualizada con estado completed"
summary_ok "Resultados disponibles en results/raw/"
summary_ok "Escenario B queda listo para congelamiento"
