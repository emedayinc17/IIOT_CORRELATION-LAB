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

log "Validando prerequisitos de Zabbix..."
${KUBECTL} get sc microk8s-hostpath >/dev/null || fail "StorageClass microk8s-hostpath no existe."
${KUBECTL} get ns monitoring >/dev/null 2>&1 || true

log "Desplegando Zabbix persistente..."
${KUBECTL} apply -k "${ROOT_DIR}/kubernetes/zabbix"

log "Esperando PVC PostgreSQL Bound..."
for i in $(seq 1 60); do
  phase="$(${KUBECTL} get pvc zabbix-postgres-pvc -n monitoring -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "$phase" == "Bound" ]]; then
    echo "[OK] PVC zabbix-postgres-pvc Bound."
    break
  fi
  echo "[WAIT] PVC aún no está Bound. Estado=${phase:-unknown}. Intento ${i}/60"
  sleep 5
done

phase="$(${KUBECTL} get pvc zabbix-postgres-pvc -n monitoring -o jsonpath='{.status.phase}' 2>/dev/null || true)"
[[ "$phase" == "Bound" ]] || fail "PVC zabbix-postgres-pvc no quedó Bound."

log "Esperando Deployments..."
${KUBECTL} rollout status deployment/zabbix-postgres -n monitoring --timeout=300s
${KUBECTL} rollout status deployment/zabbix-server -n monitoring --timeout=600s
${KUBECTL} rollout status deployment/zabbix-web -n monitoring --timeout=600s

log "Esperando DaemonSet..."
${KUBECTL} rollout status ds/zabbix-agent -n monitoring --timeout=300s

log "Forzando IP estática de Zabbix Web..."
${KUBECTL} annotate svc zabbix-web -n monitoring metallb.io/loadBalancerIPs=10.10.0.160 --overwrite
${KUBECTL} patch svc zabbix-web -n monitoring --type=merge -p '{"spec":{"loadBalancerIP":"10.10.0.160"}}' >/dev/null || true

log "Esperando LoadBalancer 10.10.0.160..."
for i in $(seq 1 60); do
  actual="$(${KUBECTL} get svc zabbix-web -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  if [[ "$actual" == "10.10.0.160" ]]; then
    echo "[OK] zabbix-web asignado a 10.10.0.160."
    break
  fi
  echo "[WAIT] zabbix-web aún no tiene IP esperada. Actual=${actual:-none}. Intento ${i}/60"
  sleep 5
done

actual="$(${KUBECTL} get svc zabbix-web -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
[[ "$actual" == "10.10.0.160" ]] || fail "zabbix-web no recibió 10.10.0.160."

log "Validando UI Zabbix..."
for i in $(seq 1 60); do
  if curl -fsSI --max-time 5 http://10.10.0.160 >/tmp/zabbix_web_headers.out 2>/tmp/zabbix_web_headers.err; then
    echo "[OK] Zabbix UI responde HTTP."
    head -n 5 /tmp/zabbix_web_headers.out
    break
  fi
  echo "[WAIT] Zabbix UI aún no responde. Intento ${i}/60"
  sleep 5
done

curl -fsSI --max-time 5 http://10.10.0.160 >/dev/null || fail "Zabbix UI no responde en http://10.10.0.160"

log "Estado Monitoring:"
${KUBECTL} get pods -n monitoring -o wide
${KUBECTL} get svc -n monitoring -o wide
${KUBECTL} get pvc -n monitoring

echo
echo "============================================================"
echo "[SUMMARY] Zabbix Deployment Persistente"
echo "============================================================"
echo "[OK] StorageClass microk8s-hostpath validado"
echo "[OK] PVC zabbix-postgres-pvc Bound"
echo "[OK] PostgreSQL desplegado con persistencia"
echo "[OK] Zabbix Server desplegado"
echo "[OK] Zabbix Web desplegado"
echo "[OK] Zabbix Agent DaemonSet desplegado"
echo "[OK] Zabbix UI accesible en http://10.10.0.160"
echo "[OK] Configuración lista para instrumentación operacional"
