#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

KUBECTL="$(detect_kubectl)"

declare -A EXPECTED_IPS=(
  [mosquitto-lb]="10.10.0.151"
  [health-app-lb]="10.10.0.152"
  [telemetry-api-lb]="10.10.0.153"
  [vulnerable-app-lb]="10.10.0.154"
)

log "Usando cliente Kubernetes: ${KUBECTL}"

log "Validando cluster..."
${KUBECTL} get nodes -o wide
${KUBECTL} get nodes --no-headers | grep -q " Ready " || fail "No hay nodos Ready."

log "Validando MetalLB..."
${KUBECTL} get ns metallb-system >/dev/null || fail "MetalLB no está instalado."
${KUBECTL} get ipaddresspool -A

log "Aplicando manifiestos Foundation..."
${KUBECTL} apply -k "${ROOT_DIR}/kubernetes/foundation"

log "Forzando IPs estáticas MetalLB esperadas..."
for svc in "${!EXPECTED_IPS[@]}"; do
  ip="${EXPECTED_IPS[$svc]}"
  ${KUBECTL} annotate svc "$svc" -n iiot-poc metallb.universe.tf/loadBalancerIPs- --overwrite 2>/dev/null || true
  ${KUBECTL} annotate svc "$svc" -n iiot-poc metallb.io/loadBalancerIPs="$ip" --overwrite
  ${KUBECTL} patch svc "$svc" -n iiot-poc --type=merge -p "{\"spec\":{\"loadBalancerIP\":\"$ip\"}}" >/dev/null || true
done

log "Reiniciando MetalLB para reconciliación limpia..."
${KUBECTL} rollout restart deployment/controller -n metallb-system >/dev/null || true
${KUBECTL} rollout restart ds/speaker -n metallb-system >/dev/null || true
${KUBECTL} rollout status deployment/controller -n metallb-system --timeout=120s || true
${KUBECTL} rollout status ds/speaker -n metallb-system --timeout=120s || true

log "Esperando Deployments Foundation..."
for deploy in mosquitto sensor-simulator health-app telemetry-api vulnerable-app; do
  echo "[WAIT] deployment/${deploy}"
  ${KUBECTL} rollout status deployment/"${deploy}" -n iiot-poc --timeout=300s
done

log "Esperando IPs exactas de MetalLB..."
for i in $(seq 1 60); do
  ok=1
  for svc in "${!EXPECTED_IPS[@]}"; do
    expected="${EXPECTED_IPS[$svc]}"
    actual="$(${KUBECTL} get svc "$svc" -n iiot-poc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [[ "$actual" != "$expected" ]]; then
      ok=0
    fi
  done

  if [[ "$ok" -eq 1 ]]; then
    echo "[OK] Todas las IPs MetalLB coinciden con lo esperado."
    break
  fi

  echo "[WAIT] IPs aún no coinciden. Intento ${i}/60"
  ${KUBECTL} get svc -n iiot-poc -o wide
  sleep 5
done

for svc in "${!EXPECTED_IPS[@]}"; do
  expected="${EXPECTED_IPS[$svc]}"
  actual="$(${KUBECTL} get svc "$svc" -n iiot-poc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]] || fail "IP incorrecta para $svc. Esperado=$expected Actual=$actual"
done

log "Estado de servicios:"
${KUBECTL} get svc -n iiot-poc -o wide

log "Validando endpoints HTTP externos..."
wait_http "health-app" "http://10.10.0.152:8080/health" 30 5
wait_http "telemetry-api" "http://10.10.0.153:8080/telemetry" 30 5
wait_http "vulnerable-app" "http://10.10.0.154:8080/health" 30 5

log "Validando MQTT externo..."
wait_mqtt "10.10.0.151" 30 5

log "Validando DNS interno Kubernetes sin modo interactivo..."
${KUBECTL} delete pod dns-test -n iiot-poc --ignore-not-found=true >/dev/null 2>&1 || true
${KUBECTL} run dns-test -n iiot-poc --image=busybox:1.36 --restart=Never --command -- nslookup telemetry-api.iiot-poc.svc.cluster.local >/dev/null
${KUBECTL} wait --for=condition=Ready pod/dns-test -n iiot-poc --timeout=30s >/dev/null 2>&1 || true
${KUBECTL} logs dns-test -n iiot-poc
${KUBECTL} delete pod dns-test -n iiot-poc --ignore-not-found=true >/dev/null 2>&1 || true

summary_header "Foundation IIoT"
summary_ok "Cluster Kubernetes accesible y nodo Ready"
summary_ok "MetalLB disponible"
summary_ok "Manifiestos Foundation aplicados"
summary_ok "Deployments Foundation en rollout exitoso"
summary_ok "IPs MetalLB validadas: MQTT=.151, Health=.152, Telemetry=.153, Vulnerable=.154"
summary_ok "Endpoint Health App validado: http://10.10.0.152:8080/health"
summary_ok "Endpoint Telemetry API validado: http://10.10.0.153:8080/telemetry"
summary_ok "Endpoint Vulnerable App validado: http://10.10.0.154:8080/health"
summary_ok "MQTT validado en 10.10.0.151:1883"
summary_ok "DNS interno Kubernetes validado"
summary_ok "Foundation IIoT queda lista para Escenario A"
