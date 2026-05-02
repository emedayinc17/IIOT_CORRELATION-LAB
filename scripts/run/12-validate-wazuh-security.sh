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
OUT_DIR="${ROOT_DIR}/evidence/wazuh"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DASHBOARD_IP="${WAZUH_DASHBOARD_IP:-10.10.0.161}"
MANAGER_IP="${WAZUH_MANAGER_IP:-10.10.0.162}"
STORAGE_CLASS="${WAZUH_STORAGE_CLASS:-microk8s-hostpath}"

mkdir -p "$OUT_DIR"

find_manager_pod(){
  local pod=""
  pod="$(${KUBECTL} -n "$NS" get pods -l 'app=wazuh-manager,node-type=master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "$pod" ]]; then
    pod="$(${KUBECTL} -n "$NS" get pods --no-headers 2>/dev/null | awk '/wazuh-manager-master/ && $3 == "Running" {print $1; exit}')"
  fi
  echo "$pod"
}

rollout_status_flag(){
  local kind="$1"
  local name="$2"
  local flag="NO"
  if ${KUBECTL} -n "$NS" get "$kind" "$name" >/dev/null 2>&1; then
    if ${KUBECTL} -n "$NS" rollout status "${kind}/${name}" --timeout=120s >/tmp/rollout_${name}.out 2>/tmp/rollout_${name}.err; then
      flag="YES"
    fi
    cat /tmp/rollout_${name}.out >> "${OUT_DIR}/${TS}-wazuh-rollout.txt" 2>/dev/null || true
    cat /tmp/rollout_${name}.err >> "${OUT_DIR}/${TS}-wazuh-rollout.txt" 2>/dev/null || true
  fi
  echo "$flag"
}

log "Validando Escenario C — Wazuh Security Layer"
log "Cliente Kubernetes: ${KUBECTL}"
log "Perfil esperado: MicroK8s v1.30.x single-node, Calico, MetalLB, microk8s-hostpath"

${KUBECTL} get ns "$NS" >/dev/null 2>&1 || fail "No existe namespace ${NS}. Ejecuta 11-deploy-wazuh-security.sh."
${KUBECTL} get ns iiot-poc >/dev/null 2>&1 || fail "No existe namespace iiot-poc."
${KUBECTL} get ns monitoring >/dev/null 2>&1 || fail "No existe namespace monitoring."
${KUBECTL} get sc "$STORAGE_CLASS" >/dev/null 2>&1 || fail "No existe StorageClass ${STORAGE_CLASS}."

ready_nodes="$(${KUBECTL} get nodes --no-headers | awk '$2 ~ /Ready/ {c++} END{print c+0}')"
[[ "$ready_nodes" -eq 1 ]] || fail "El laboratorio esperado es single-node. Nodos Ready detectados: ${ready_nodes}."

log "Exportando estado de Kubernetes para evidencia..."
${KUBECTL} get nodes -o wide | tee "$OUT_DIR/${TS}-cluster-nodes-validation.txt"
${KUBECTL} get sc -o wide | tee "$OUT_DIR/${TS}-cluster-storageclasses-validation.txt"
${KUBECTL} -n "$NS" get all -o wide | tee "$OUT_DIR/${TS}-wazuh-get-all.txt"
${KUBECTL} -n "$NS" get pvc -o wide | tee "$OUT_DIR/${TS}-wazuh-pvc.txt" || true
${KUBECTL} -n "$NS" get pods -o wide > "$OUT_DIR/${TS}-wazuh-pods.txt" || true
${KUBECTL} -n "$NS" describe pods > "$OUT_DIR/${TS}-wazuh-pods-describe.txt" || true
${KUBECTL} -n "$NS" get configmap wazuh-version-lock -o yaml > "$OUT_DIR/${TS}-wazuh-version-lock.yaml" 2>/dev/null || true
${KUBECTL} -n "$NS" get configmap wazuh-iiot-rules -o yaml > "$OUT_DIR/${TS}-wazuh-iiot-rules.yaml" 2>/dev/null || true
${KUBECTL} -n "$NS" get configmap scenario-c-security-event-schema -o yaml > "$OUT_DIR/${TS}-scenario-c-event-schema.yaml" 2>/dev/null || true

IMAGE_PULL_ERRORS="$(${KUBECTL} -n "$NS" get pods --no-headers 2>/dev/null | awk '$3 ~ /ImagePullBackOff|ErrImagePull/ {print $1":"$3}' | xargs || true)"
PVC_PENDING="$(${KUBECTL} -n "$NS" get pvc --no-headers 2>/dev/null | awk '$2 != "Bound" {print $1":"$2}' | xargs || true)"
WORKER_PRESENT="$(${KUBECTL} -n "$NS" get statefulset wazuh-manager-worker --no-headers 2>/dev/null | awk '{print $1}' | xargs || true)"

INDEXER_READY="$(rollout_status_flag statefulset wazuh-indexer)"
MANAGER_READY="$(rollout_status_flag statefulset wazuh-manager-master)"
DASHBOARD_READY="$(rollout_status_flag deployment wazuh-dashboard)"
RULES_READY="NO"
LOCALFILE_READY="NO"
DASHBOARD_HTTP="NO"
MANAGER_API_PORT="NO"
DASHBOARD_API_AUTH="NO"
DASHBOARD_API_CONFIG="NO"

DASHBOARD_SVC="$(${KUBECTL} -n "$NS" get svc wazuh-dashboard-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
MANAGER_SVC="$(${KUBECTL} -n "$NS" get svc wazuh-manager-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

if [[ "${DASHBOARD_SVC:-}" == "$DASHBOARD_IP" ]]; then
  DASH_BODY="/tmp/wazuh_dashboard_body_${TS}.out"
  DASH_HEADERS="/tmp/wazuh_dashboard_headers_${TS}.out"
  for attempt in $(seq 1 "${DASHBOARD_VALIDATE_ATTEMPTS:-40}"); do
    if curl -k -sS -D "$DASH_HEADERS" --max-time 10 "https://${DASHBOARD_IP}" -o "$DASH_BODY"; then
      cp "$DASH_HEADERS" "$OUT_DIR/${TS}-wazuh-dashboard-headers.txt" 2>/dev/null || true
      cp "$DASH_BODY" "$OUT_DIR/${TS}-wazuh-dashboard-body.txt" 2>/dev/null || true
      if ! grep -qi "server is not ready yet" "$DASH_BODY"; then
        DASHBOARD_HTTP="YES"
        break
      fi
    fi
    sleep 15
  done
fi

if [[ "${MANAGER_SVC:-}" == "$MANAGER_IP" ]]; then
  if timeout 5 bash -lc "</dev/tcp/${MANAGER_IP}/55000" >/dev/null 2>&1; then
    MANAGER_API_PORT="YES"
  elif curl -k -sS --max-time 10 "https://${MANAGER_IP}:55000" -o "$OUT_DIR/${TS}-wazuh-api-body.txt" 2>"$OUT_DIR/${TS}-wazuh-api-error.txt"; then
    MANAGER_API_PORT="YES"
  fi
fi


# Validación funcional Dashboard -> Wazuh Manager API.
dashboard_pod="$(${KUBECTL} -n "$NS" get pods -l app=wazuh-dashboard -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "${dashboard_pod:-}" ]] && ${KUBECTL} -n "$NS" get secret wazuh-api-cred >/dev/null 2>&1; then
  api_user="$(${KUBECTL} -n "$NS" get secret wazuh-api-cred -o jsonpath='{.data.username}' | base64 -d)"
  api_pass="$(${KUBECTL} -n "$NS" get secret wazuh-api-cred -o jsonpath='{.data.password}' | base64 -d)"
  if ${KUBECTL} -n "$NS" exec "$dashboard_pod" -- bash -lc 'grep -A6 "hosts:" /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml' > "$OUT_DIR/${TS}-wazuh-dashboard-api-config-validation.txt" 2>/dev/null; then
    if ! grep -q 'password: wazuh-wui' "$OUT_DIR/${TS}-wazuh-dashboard-api-config-validation.txt" && grep -q 'url: https://wazuh' "$OUT_DIR/${TS}-wazuh-dashboard-api-config-validation.txt"; then
      DASHBOARD_API_CONFIG="YES"
    fi
  fi
  if ${KUBECTL} -n "$NS" exec "$dashboard_pod" -- env API_USER="$api_user" API_PASS="$api_pass" bash -lc 'curl -sk -u "${API_USER}:${API_PASS}" -X POST "https://wazuh:55000/security/user/authenticate?raw=true"' > /tmp/wazuh_api_token_${TS}.txt 2>"$OUT_DIR/${TS}-wazuh-dashboard-api-auth.err"; then
    if grep -Eq '^[A-Za-z0-9._=-]{20,}$' /tmp/wazuh_api_token_${TS}.txt; then
      DASHBOARD_API_AUTH="YES"
      echo "TOKEN_OK" > "$OUT_DIR/${TS}-wazuh-dashboard-api-auth.txt"
    else
      cp /tmp/wazuh_api_token_${TS}.txt "$OUT_DIR/${TS}-wazuh-dashboard-api-auth-unexpected.txt" 2>/dev/null || true
    fi
  fi
  rm -f /tmp/wazuh_api_token_${TS}.txt 2>/dev/null || true
fi

manager_pod="$(find_manager_pod)"
if [[ -n "$manager_pod" ]]; then
  phase="$(${KUBECTL} -n "$NS" get pod "$manager_pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  node="$(${KUBECTL} -n "$NS" get pod "$manager_pod" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
  if [[ "$phase" == "Running" && -n "$node" ]]; then
    if ${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'test -r /var/ossec/etc/rules/iiot_local_rules.xml && grep -q "110809" /var/ossec/etc/rules/iiot_local_rules.xml' >/dev/null 2>&1; then
      RULES_READY="YES"
    fi
    if ${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'grep -q "scenario_c_baseline.json" /var/ossec/etc/ossec.conf && test -f /var/ossec/logs/iiot-lab/scenario_c_baseline.json' >/dev/null 2>&1; then
      LOCALFILE_READY="YES"
    fi
  fi
fi

cat > "$OUT_DIR/${TS}-wazuh-validation-summary.csv" <<EOF_SUMMARY
timestamp_utc,namespace,microk8s_single_node,storage_class,indexer_ready,manager_ready,dashboard_ready,dashboard_http,manager_api_port,dashboard_api_config,dashboard_api_auth,rules_ready,localfile_ready,worker_present,pvc_pending,image_pull_errors,dashboard_ip,manager_ip
$(date -u +%Y-%m-%dT%H:%M:%SZ),${NS},YES,${STORAGE_CLASS},${INDEXER_READY},${MANAGER_READY},${DASHBOARD_READY},${DASHBOARD_HTTP},${MANAGER_API_PORT},${DASHBOARD_API_CONFIG},${DASHBOARD_API_AUTH},${RULES_READY},${LOCALFILE_READY},"${WORKER_PRESENT:-NO}","${PVC_PENDING:-NONE}","${IMAGE_PULL_ERRORS:-NONE}",${DASHBOARD_SVC:-PENDING},${MANAGER_SVC:-PENDING}
EOF_SUMMARY

summary_header "Scenario C Wazuh Security Validation"
summary_ok "MicroK8s single-node validado"
summary_ok "StorageClass ${STORAGE_CLASS} validada"
[[ -z "$PVC_PENDING" ]] && summary_ok "PVCs Wazuh Bound" || summary_warn "PVCs pendientes: ${PVC_PENDING}"
[[ -z "$IMAGE_PULL_ERRORS" ]] && summary_ok "Sin errores ImagePullBackOff/ErrImagePull" || summary_warn "Errores de imagen: ${IMAGE_PULL_ERRORS}"
[[ -z "$WORKER_PRESENT" ]] && summary_ok "Sin worker Wazuh adicional: modelo single-node/all-in-one preservado" || summary_warn "Worker Wazuh presente: ${WORKER_PRESENT}"
[[ "$INDEXER_READY" == "YES" ]] && summary_ok "Wazuh Indexer listo" || summary_warn "Wazuh Indexer no quedó validado"
[[ "$MANAGER_READY" == "YES" ]] && summary_ok "Wazuh Manager master listo" || summary_warn "Wazuh Manager master no quedó validado"
[[ "$DASHBOARD_READY" == "YES" ]] && summary_ok "Wazuh Dashboard listo" || summary_warn "Wazuh Dashboard no quedó validado"
[[ "$DASHBOARD_HTTP" == "YES" ]] && summary_ok "Dashboard responde en https://${DASHBOARD_IP}" || summary_warn "Dashboard HTTPS externo pendiente o todavía reporta server is not ready yet"
[[ "$MANAGER_API_PORT" == "YES" ]] && summary_ok "Puerto Wazuh API 55000 accesible en ${MANAGER_IP}" || summary_warn "Puerto Wazuh API 55000 no validado externamente"
[[ "$DASHBOARD_API_CONFIG" == "YES" ]] && summary_ok "Dashboard usa configuración API corregida en wazuh.yml" || summary_warn "Dashboard mantiene configuración API pendiente o password por defecto"
[[ "$DASHBOARD_API_AUTH" == "YES" ]] && summary_ok "Dashboard puede autenticarse contra Wazuh Manager API" || summary_warn "Dashboard no autenticó contra Wazuh Manager API"
[[ "$RULES_READY" == "YES" ]] && summary_ok "Reglas IIoT/MITRE ICS instaladas en Wazuh Manager" || summary_warn "Reglas IIoT/MITRE ICS no verificadas en Wazuh Manager"
[[ "$LOCALFILE_READY" == "YES" ]] && summary_ok "Localfile de baseline IIoT configurado" || summary_warn "Localfile de baseline IIoT no verificado"
summary_ok "Inventario Wazuh exportado en evidence/wazuh/"
summary_ok "Resumen CSV generado: evidence/wazuh/${TS}-wazuh-validation-summary.csv"
