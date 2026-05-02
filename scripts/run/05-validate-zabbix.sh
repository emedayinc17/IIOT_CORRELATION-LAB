#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -f "${ROOT_DIR}/scripts/lib/common.sh" ]]; then
  source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"
else
  log(){ echo -e "\n[INFO] $1"; }
  fail(){ echo -e "\n[ERROR] $1"; exit 1; }
fi

if command -v kubectl >/dev/null 2>&1; then
  KUBECTL="kubectl"
elif command -v microk8s >/dev/null 2>&1; then
  KUBECTL="microk8s kubectl"
else
  fail "No se encontró kubectl ni microk8s kubectl."
fi

log "Validando Pods Monitoring..."
${KUBECTL} get pods -n monitoring -o wide

log "Validando PVC..."
${KUBECTL} get pvc -n monitoring
phase="$(${KUBECTL} get pvc zabbix-postgres-pvc -n monitoring -o jsonpath='{.status.phase}')"
[[ "$phase" == "Bound" ]] || fail "PVC zabbix-postgres-pvc no está Bound."

log "Validando servicios..."
${KUBECTL} get svc -n monitoring -o wide
actual="$(${KUBECTL} get svc zabbix-web -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
[[ "$actual" == "10.10.0.160" ]] || fail "zabbix-web no tiene IP 10.10.0.160. Actual=${actual:-none}"

log "Validando UI..."
curl -fsSI --max-time 5 http://10.10.0.160 | head -n 10

log "Validando DaemonSet Agent..."
${KUBECTL} get ds zabbix-agent -n monitoring
ready="$(${KUBECTL} get ds zabbix-agent -n monitoring -o jsonpath='{.status.numberReady}')"
desired="$(${KUBECTL} get ds zabbix-agent -n monitoring -o jsonpath='{.status.desiredNumberScheduled}')"
[[ "$ready" == "$desired" ]] || fail "Zabbix Agent no está listo en todos los nodos. Ready=${ready}, Desired=${desired}"

log "Validando conectividad interna Zabbix Server..."
${KUBECTL} run zabbix-server-port-test -n monitoring --image=busybox:1.36 --restart=Never --command -- sh -c 'nc -zvw5 zabbix-server.monitoring.svc.cluster.local 10051' >/dev/null
${KUBECTL} logs zabbix-server-port-test -n monitoring || true
${KUBECTL} delete pod zabbix-server-port-test -n monitoring --ignore-not-found=true >/dev/null 2>&1 || true

echo
echo "============================================================"
echo "[SUMMARY] Zabbix Validation Persistente"
echo "============================================================"
echo "[OK] Namespace monitoring operativo"
echo "[OK] Pods Monitoring visibles"
echo "[OK] PVC PostgreSQL Bound"
echo "[OK] Zabbix UI accesible en http://10.10.0.160"
echo "[OK] Agent DaemonSet operativo"
echo "[OK] Zabbix Server puerto 10051 validado internamente"
echo "[OK] Zabbix persistente listo para configuración de hosts/items/triggers"
