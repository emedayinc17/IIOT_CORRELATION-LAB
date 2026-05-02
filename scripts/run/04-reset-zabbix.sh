#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -f "${ROOT_DIR}/scripts/lib/common.sh" ]]; then
  source "${ROOT_DIR}/scripts/lib/common.sh"
else
  log(){ echo -e "\n[INFO] $1"; }
  warn(){ echo -e "\n[WARN] $1"; }
fi

if command -v kubectl >/dev/null 2>&1; then
  KUBECTL="kubectl"
elif command -v microk8s >/dev/null 2>&1; then
  KUBECTL="microk8s kubectl"
else
  echo "[ERROR] No se encontró kubectl ni microk8s kubectl."
  exit 1
fi

log "Eliminando Zabbix existente en namespace monitoring..."

${KUBECTL} delete -k "${ROOT_DIR}/kubernetes/zabbix" --ignore-not-found=true || true

log "Esperando eliminación de pods Zabbix..."
for i in $(seq 1 60); do
  remaining="$(${KUBECTL} get pods -n monitoring -l stage=zabbix-monitoring --no-headers 2>/dev/null | wc -l || true)"
  if [[ "$remaining" == "0" ]]; then
    echo "[OK] Pods Zabbix eliminados."
    break
  fi
  echo "[WAIT] Aún quedan pods Zabbix. Intento ${i}/60"
  sleep 3
done

echo
echo "============================================================"
echo "[SUMMARY] Reset Zabbix"
echo "============================================================"
echo "[OK] Recursos Zabbix solicitados para eliminación"
echo "[OK] Si se desea eliminar datos persistentes, borrar manualmente PVC zabbix-postgres-pvc"
echo "[OK] Por defecto, el PVC se conserva para evitar pérdida accidental de datos"
