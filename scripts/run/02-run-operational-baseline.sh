#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

KUBECTL="$(detect_kubectl)"
RESULTS_DIR="${ROOT_DIR}/results/raw"

mkdir -p "$RESULTS_DIR"

log "Validando prerequisitos del Escenario A..."
${KUBECTL} get ns iiot-poc >/dev/null || fail "Foundation no está desplegada."

wait_http "health-app" "http://10.10.0.152:8080/health" 5 2
wait_http "telemetry-api" "http://10.10.0.153:8080/telemetry" 5 2
wait_http "vulnerable-app" "http://10.10.0.154:8080/health" 5 2
wait_mqtt "10.10.0.151" 5 2

log "Limpiando resultados previos del baseline..."
rm -f "${RESULTS_DIR}/http_baseline.csv" "${RESULTS_DIR}/mqtt_messages.csv" "${RESULTS_DIR}/k8s_resources.csv" "${RESULTS_DIR}/experiment_metadata.json"

START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "${RESULTS_DIR}/experiment_metadata.json" <<EOF
{
  "scenario": "A",
  "name": "Operational Baseline",
  "start_timestamp_utc": "${START_TS}",
  "iterations": "${ITERATIONS:-300}",
  "sleep_seconds": "${SLEEP_SECONDS:-2}",
  "duration_seconds": "${DURATION_SECONDS:-600}",
  "services": {
    "mqtt": "10.10.0.151:1883",
    "health_app": "10.10.0.152:8080",
    "telemetry_api": "10.10.0.153:8080",
    "vulnerable_app": "10.10.0.154:8080"
  }
}
EOF

log "Iniciando collectors. Se esperará hasta que todos terminen."
echo "[EXPECTED] HTTP/MQTT/K8s generarán CSV en results/raw/."

bash "${ROOT_DIR}/scripts/collectors/collect-http.sh" "${RESULTS_DIR}/http_baseline.csv" &
HTTP_PID=$!

bash "${ROOT_DIR}/scripts/collectors/collect-mqtt.sh" "${RESULTS_DIR}/mqtt_messages.csv" &
MQTT_PID=$!

bash "${ROOT_DIR}/scripts/collectors/collect-k8s.sh" "${RESULTS_DIR}/k8s_resources.csv" &
K8S_PID=$!

trap 'warn "Interrupción detectada. Deteniendo collectors..."; kill $HTTP_PID $MQTT_PID $K8S_PID 2>/dev/null || true; exit 130' INT TERM

echo "[INFO] HTTP collector PID: ${HTTP_PID}"
echo "[INFO] MQTT collector PID: ${MQTT_PID}"
echo "[INFO] K8S collector PID: ${K8S_PID}"

wait "$HTTP_PID"
wait "$MQTT_PID"
wait "$K8S_PID"

END_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

log "Validando archivos generados..."
csv_has_data "${RESULTS_DIR}/http_baseline.csv"
csv_has_data "${RESULTS_DIR}/mqtt_messages.csv"
csv_has_data "${RESULTS_DIR}/k8s_resources.csv"

python3 - <<PY
import json
from pathlib import Path
p=Path("${RESULTS_DIR}/experiment_metadata.json")
d=json.loads(p.read_text())
d["end_timestamp_utc"]="${END_TS}"
d["status"]="completed"
p.write_text(json.dumps(d, indent=2))
PY

HTTP_LINES=$(wc -l < "${RESULTS_DIR}/http_baseline.csv")
MQTT_LINES=$(wc -l < "${RESULTS_DIR}/mqtt_messages.csv")
K8S_LINES=$(wc -l < "${RESULTS_DIR}/k8s_resources.csv")

log "Resumen de archivos:"
ls -lh "${RESULTS_DIR}"

summary_header "Escenario A — Operational Baseline"
summary_ok "Prerequisitos Foundation validados"
summary_ok "HTTP collector completado: ${HTTP_LINES} líneas"
summary_ok "MQTT collector completado: ${MQTT_LINES} líneas"
summary_ok "K8s resource collector completado: ${K8S_LINES} líneas"
summary_ok "Metadata experimental actualizada con inicio, fin y estado completed"
summary_ok "Resultados disponibles en results/raw/"
summary_ok "Escenario A queda listo para congelamiento"
