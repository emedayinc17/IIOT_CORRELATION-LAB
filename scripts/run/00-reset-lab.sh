#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

KUBECTL="$(detect_kubectl)"

RESET_COLLECTORS="OK"
RESET_FOUNDATION="OK"
RESET_RESULTS="OK"

log "Deteniendo collectors previos si existen..."
pkill -f collect-http.sh || true
pkill -f collect-mqtt.sh || true
pkill -f collect-k8s.sh || true
pkill -f run-operational-baseline || true

log "Eliminando despliegue Foundation si existe..."
${KUBECTL} delete -k "${ROOT_DIR}/kubernetes/foundation" --ignore-not-found=true || true

log "Esperando limpieza del namespace iiot-poc..."
for i in $(seq 1 60); do
  if ! ${KUBECTL} get ns iiot-poc >/dev/null 2>&1; then
    echo "[OK] Namespace iiot-poc eliminado."
    break
  fi
  echo "[WAIT] iiot-poc aún existe. Intento ${i}/60"
  sleep 3
done

if ${KUBECTL} get ns iiot-poc >/dev/null 2>&1; then
  RESET_FOUNDATION="PENDING"
  warn "El namespace iiot-poc aún existe. Revisar si quedó en Terminating."
fi

log "Limpiando resultados crudos anteriores..."
mkdir -p "${ROOT_DIR}/results/raw"
rm -f "${ROOT_DIR}/results/raw/"*.csv "${ROOT_DIR}/results/raw/"*.json || true

summary_header "Reset del laboratorio"
summary_ok "Collectors previos detenidos o no existentes"
if [[ "$RESET_FOUNDATION" == "OK" ]]; then
  summary_ok "Foundation eliminada correctamente"
else
  summary_warn "Foundation no terminó de eliminarse; revisar namespace iiot-poc"
fi
summary_ok "Resultados crudos anteriores limpiados"
summary_ok "El entorno queda listo para ejecutar 01-deploy-foundation.sh"
