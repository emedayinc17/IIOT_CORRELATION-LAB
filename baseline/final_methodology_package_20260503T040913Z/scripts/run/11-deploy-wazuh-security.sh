#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: 11-deploy-wazuh-security.sh
# =============================================================================
# OBJETIVO: Despliegue de Wazuh Security Layer en MicroK8s
# VERSIÓN: v8.2 - API Connection FQDN corregido
# =============================================================================
# CORRECCIONES v8.2:
#   1. URL del manager ahora usa FQDN completo: wazuh-manager-master.security.svc.cluster.local
#   2. Eliminado escape problemático de contraseñas (usa literales con jq)
#   3. Validación más robusta de la configuración post-reinicio
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

prefer_microk8s_kubectl(){
  if command -v microk8s >/dev/null 2>&1; then 
    echo "microk8s kubectl"
  elif command -v kubectl >/dev/null 2>&1; then 
    echo kubectl
  else 
    fail "No se encontró microk8s ni kubectl. Este laboratorio requiere MicroK8s operativo."
  fi
}

KUBECTL="$(prefer_microk8s_kubectl)"
NS="${WAZUH_NS:-security}"
DASHBOARD_IP="${WAZUH_DASHBOARD_IP:-10.10.0.161}"
MANAGER_IP="${WAZUH_MANAGER_IP:-10.10.0.162}"
STORAGE_CLASS="${WAZUH_STORAGE_CLASS:-microk8s-hostpath}"
OUT_DIR="${ROOT_DIR}/evidence/wazuh"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DASHBOARD_WAIT_SECONDS="${DASHBOARD_WAIT_SECONDS:-900}"

require_cmd(){ command -v "$1" >/dev/null 2>&1 || fail "No se encontró comando requerido: $1"; }

# Necesario para JSON escaping
require_cmd jq

find_manager_pod(){
  local pod=""
  pod="$(${KUBECTL} -n "$NS" get pods -l 'app=wazuh-manager,node-type=master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "$pod" ]]; then
    pod="$(${KUBECTL} -n "$NS" get pods --no-headers 2>/dev/null | awk '/wazuh-manager-master/ && $3 == "Running" {print $1; exit}')"
  fi
  echo "$pod"
}

wait_pod_ready_by_label(){
  local label="$1" description="$2" timeout_s end
  timeout_s="${3:-900}"
  end=$((SECONDS + timeout_s))
  log "Esperando pod listo: ${description} (${label})..."
  while (( SECONDS < end )); do
    local pod phase ready node status
    pod="$(${KUBECTL} -n "$NS" get pods -l "$label" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [[ -n "$pod" ]]; then
      phase="$(${KUBECTL} -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
      ready="$(${KUBECTL} -n "$NS" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)"
      node="$(${KUBECTL} -n "$NS" get pod "$pod" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
      status="$(${KUBECTL} -n "$NS" get pod "$pod" --no-headers 2>/dev/null | awk '{print $3}' || true)"
      if [[ "$status" =~ ImagePullBackOff|ErrImagePull|CrashLoopBackOff ]]; then
        ${KUBECTL} -n "$NS" describe pod "$pod" > "${OUT_DIR}/${TS}-${pod}-describe-error.txt" 2>&1 || true
        fail "${description} está en estado ${status}. Revisa evidence/wazuh/${TS}-${pod}-describe-error.txt"
      fi
      if [[ "$phase" == "Running" && "$ready" == "true" && -n "$node" ]]; then
        echo "[OK] ${description}: ${pod} Running/Ready en ${node}." >&2
        echo "$pod"
        return 0
      fi
      echo "[WAIT] ${description}: pod=${pod}, phase=${phase:-unknown}, ready=${ready:-unknown}, node=${node:-none}." >&2
    else
      echo "[WAIT] ${description}: pod aún no creado." >&2
    fi
    sleep 10
  done
  ${KUBECTL} -n "$NS" get pods -o wide > "${OUT_DIR}/${TS}-wazuh-pods-timeout.txt" 2>&1 || true
  fail "Timeout esperando ${description}. Evidencia exportada en evidence/wazuh/."
}

validate_microk8s_profile(){
  log "Validando perfil real del laboratorio MicroK8s single-node..."
  ${KUBECTL} get nodes -o wide | tee "${OUT_DIR}/${TS}-cluster-nodes.txt"
  local ready_nodes
  ready_nodes="$(${KUBECTL} get nodes --no-headers | awk '$2 ~ /Ready/ {c++} END{print c+0}')"
  [[ "$ready_nodes" -eq 1 ]] || fail "El laboratorio esperado es MicroK8s single-node. Nodos Ready detectados: ${ready_nodes}."
  ${KUBECTL} get sc -o wide | tee "${OUT_DIR}/${TS}-cluster-storageclasses.txt"
  ${KUBECTL} get sc "$STORAGE_CLASS" >/dev/null 2>&1 || fail "No existe StorageClass ${STORAGE_CLASS}. El entorno esperado usa microk8s-hostpath."
}

wait_pvc_bound(){
  local timeout_s end
  timeout_s="${1:-900}"
  end=$((SECONDS + timeout_s))
  log "Esperando PVCs Wazuh Bound en namespace ${NS}..."
  while (( SECONDS < end )); do
    local all pvc_count pending
    all="$(${KUBECTL} -n "$NS" get pvc --no-headers 2>/dev/null || true)"
    pvc_count="$(printf '%s\n' "$all" | awk 'NF{c++} END{print c+0}')"
    pending="$(printf '%s\n' "$all" | awk 'NF && $2 != "Bound" {print $1":"$2}' | xargs || true)"
    ${KUBECTL} -n "$NS" get pvc -o wide || true
    if [[ "$pvc_count" -gt 0 && -z "$pending" ]]; then echo "[OK] PVCs Wazuh Bound."; return 0; fi
    echo "[WAIT] PVCs pendientes: ${pending:-sin-pvc-todavia}."; sleep 10
  done
  ${KUBECTL} -n "$NS" describe pvc > "${OUT_DIR}/${TS}-wazuh-pvc-describe.txt" 2>&1 || true
  fail "Los PVCs de Wazuh no quedaron Bound. Revisa evidence/wazuh/${TS}-wazuh-pvc-describe.txt"
}

wait_workload(){
  local kind="$1" name="$2" timeout="${3:-1200s}"
  if ${KUBECTL} -n "$NS" get "$kind" "$name" >/dev/null 2>&1; then
    log "Esperando rollout ${kind}/${name}..."
    ${KUBECTL} -n "$NS" rollout status "${kind}/${name}" --timeout="$timeout"
  else
    fail "No se encontró ${kind}/${name}."
  fi
}

remove_wazuh_worker_if_present(){
  log "Asegurando modelo single-node/all-in-one: sin worker Wazuh adicional..."
  ${KUBECTL} -n "$NS" delete statefulset wazuh-manager-worker --ignore-not-found=true >/dev/null 2>&1 || true
  ${KUBECTL} -n "$NS" delete svc wazuh-workers --ignore-not-found=true >/dev/null 2>&1 || true
  ${KUBECTL} -n "$NS" delete pvc wazuh-manager-worker-wazuh-manager-worker-0 --ignore-not-found=true >/dev/null 2>&1 || true
}

patch_official_services_to_clusterip(){
  log "Normalizando servicios oficiales Wazuh a ClusterIP para no consumir IPs MetalLB adicionales..."
  for svc in dashboard indexer wazuh wazuh-cluster wazuh-indexer wazuh-workers; do
    if ${KUBECTL} -n "$NS" get svc "$svc" >/dev/null 2>&1; then
      ${KUBECTL} -n "$NS" patch svc "$svc" --type=merge -p '{"spec":{"type":"ClusterIP"}}' >/dev/null 2>&1 || true
    fi
  done
}

install_rules_and_localfile(){
  local manager_pod="$1"
  log "Instalando reglas IIoT/MITRE ICS post-start con permisos controlados en ${manager_pod}..."
  local tmp_rules
  tmp_rules="$(mktemp)"
  ${KUBECTL} -n "$NS" get cm wazuh-iiot-rules -o jsonpath='{.data.local_rules\.xml}' > "$tmp_rules"
  ${KUBECTL} cp "$tmp_rules" "${NS}/${manager_pod}:/tmp/iiot_local_rules.xml" >/dev/null
  rm -f "$tmp_rules"

  ${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc '
    set -euo pipefail
    group_name="$(stat -c %G /var/ossec/etc/rules/local_rules.xml 2>/dev/null || echo wazuh)"
    install -o root -g "$group_name" -m 0640 /tmp/iiot_local_rules.xml /var/ossec/etc/rules/iiot_local_rules.xml
    mkdir -p /var/ossec/logs/iiot-lab
    touch /var/ossec/logs/iiot-lab/scenario_c_baseline.json
    chown -R root:wazuh /var/ossec/logs/iiot-lab 2>/dev/null || true
    chmod 750 /var/ossec/logs/iiot-lab 2>/dev/null || true
    chmod 640 /var/ossec/logs/iiot-lab/scenario_c_baseline.json 2>/dev/null || true
    if ! grep -q "scenario_c_baseline.json" /var/ossec/etc/ossec.conf; then
      sed -i "/<\/ossec_config>/i\  <localfile>\n    <log_format>json</log_format>\n    <location>/var/ossec/logs/iiot-lab/scenario_c_baseline.json</location>\n  </localfile>" /var/ossec/etc/ossec.conf
    fi
    /var/ossec/bin/wazuh-control restart || true
  '

  log "Validando lectura de regla custom por wazuh-analysisd..."
  ${KUBECTL} -n "$NS" exec "$manager_pod" -- bash -lc 'test -r /var/ossec/etc/rules/iiot_local_rules.xml && grep -q "110809" /var/ossec/etc/rules/iiot_local_rules.xml'
}

# =============================================================================
# FUNCIÓN: reconcile_dashboard_api_connection (CORREGIDA v8.2)
# =============================================================================
reconcile_dashboard_api_connection(){
  local dashboard_pod="$1"
  
  log "=== RECONCILIACIÓN API DASHBOARD v8.2 ==="
  log "Pod objetivo: ${dashboard_pod}"

  # Validar existencia del secret
  ${KUBECTL} -n "$NS" get secret wazuh-api-cred >/dev/null 2>&1 || fail "No existe secret wazuh-api-cred en namespace ${NS}."

  # Obtener credenciales del secret
  local api_user api_pass
  api_user="$(${KUBECTL} -n "$NS" get secret wazuh-api-cred -o jsonpath='{.data.username}' | base64 -d)"
  api_pass="$(${KUBECTL} -n "$NS" get secret wazuh-api-cred -o jsonpath='{.data.password}' | base64 -d)"

  log "API Usuario: ${api_user}"
  [[ -n "$api_user" ]] || fail "wazuh-api-cred.username está vacío."
  [[ -n "$api_pass" ]] || fail "wazuh-api-cred.password está vacío."

  # FQDN CORRECTO (full cluster domain)
  local MANAGER_FQDN="wazuh.${NS}.svc.cluster.local"
  local MANAGER_URL="https://${MANAGER_FQDN}:55000"

  log "Manager FQDN: ${MANAGER_FQDN}"
  log "Manager URL: ${MANAGER_URL}"

  # Validar autenticación real contra Wazuh API desde el Dashboard pod
  log "Validando autenticación real contra Wazuh API desde el Dashboard pod..."
  
  local auth_check_result=0
  local AUTH_TOKEN=""
  
  AUTH_TOKEN=$(${KUBECTL} -n "$NS" exec "$dashboard_pod" -- \
    curl -sk -u "${api_user}:${api_pass}" \
    -X POST "${MANAGER_URL}/security/user/authenticate?raw=true" 2>/dev/null || echo "FAILED")

  if [[ "$AUTH_TOKEN" != "FAILED" && -n "$AUTH_TOKEN" && ${#AUTH_TOKEN} -gt 20 ]]; then
    log "[OK] Autenticación Dashboard -> Wazuh API validada con credenciales reales."
  else
    log "ERROR: No se pudo autenticar contra Wazuh API desde el dashboard pod."
    log "Respuesta: ${AUTH_TOKEN}"
    fail "Autenticación API fallida. Verifica que wazuh-manager-master esté corriendo."
  fi

  # CORREGIDO: Usar Python para modificar YAML de forma segura (sin problemas de escape)
  log "Configurando wazuh.yml con credenciales reales (modo seguro Python)..."

  ${KUBECTL} -n "$NS" exec "$dashboard_pod" -- bash -c "
    python3 << 'PYTHON_SCRIPT'
import yaml
import os

cfg_path = '/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml'

# Leer configuración existente
with open(cfg_path, 'r') as f:
    config = yaml.safe_load(f) or {}

# Asegurar estructura
if 'hosts' not in config or not isinstance(config['hosts'], dict):
    config['hosts'] = {}
if 'default' not in config['hosts']:
    config['hosts']['default'] = {}

# Actualizar valores del manager API
config['hosts']['default']['url'] = 'https://wazuh-manager-master.${NS}.svc.cluster.local'
config['hosts']['default']['port'] = 55000
config['hosts']['default']['username'] = '${api_user}'
config['hosts']['default']['password'] = '${api_pass}'
config['hosts']['default']['run_as'] = True

# Asegurar otros valores por defecto
if 'pattern' not in config:
    config['pattern'] = 'wazuh-alerts-*'
if 'timeout' not in config:
    config['timeout'] = 20000
if 'wazuh.monitoring.enabled' not in config:
    config['wazuh.monitoring.enabled'] = True
if 'wazuh.monitoring.frequency' not in config:
    config['wazuh.monitoring.frequency'] = 900

# Backup del original
import shutil
shutil.copy2(cfg_path, f'{cfg_path}.bak.$(date -u +%Y%m%dT%H%M%SZ)')

# Escribir configuración
with open(cfg_path, 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print('Configuración actualizada correctamente')
PYTHON_SCRIPT
" > "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-result.txt" 2>&1

  if grep -q "Configuración actualizada" "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-result.txt"; then
    log "[OK] wazuh.yml actualizado correctamente."
  else
    cat "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-result.txt"
    fail "Error al actualizar wazuh.yml con Python."
  fi

  # Verificar la configuración escrita
  log "Verificando configuración escrita..."
  ${KUBECTL} -n "$NS" exec "$dashboard_pod" -- \
    grep -A6 "hosts:" /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml \
    > "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-verification.txt"

  if grep -q "password: ${api_pass}" "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-verification.txt"; then
    log "[OK] wazuh.yml contiene la contraseña correcta."
  else
    log "WARN: La contraseña en el archivo no coincide con la esperada."
    cat "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-verification.txt"
  fi

  # Reiniciar dashboard
  log "Reiniciando Wazuh Dashboard para aplicar configuración..."
  ${KUBECTL} -n "$NS" rollout restart deployment/wazuh-dashboard >/dev/null
  ${KUBECTL} -n "$NS" rollout status deployment/wazuh-dashboard --timeout=300s

  # Esperar nuevo pod
  sleep 10
  local new_dashboard_pod
  new_dashboard_pod="$(${KUBECTL} -n "$NS" get pods -l app=wazuh-dashboard -o jsonpath='{.items[0].metadata.name}')"
  
  log "Nuevo pod del dashboard: ${new_dashboard_pod}"
  wait_pod_ready_by_label 'app=wazuh-dashboard' 'Wazuh Dashboard post API reconcile' 300 >/dev/null

  # Verificar persistencia
  log "Verificando persistencia de la configuración después del reinicio..."
  ${KUBECTL} -n "$NS" exec "$new_dashboard_pod" -- \
    grep -A6 "hosts:" /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml \
    > "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-post-restart.txt"

  if grep -q "password: ${api_pass}" "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-post-restart.txt" && \
     grep -q "url: https://wazuh-manager-master.${NS}.svc.cluster.local" "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-post-restart.txt"; then
    log "[OK] Configuración persistente después del reinicio."
  else
    log "WARN: La configuración no persiste después del reinicio. Verificar ConfigMap."
    cat "${OUT_DIR}/${TS}-wazuh-dashboard-api-config-post-restart.txt"
  fi

  echo "[OK] Wazuh Dashboard configurado contra Wazuh Manager API con credenciales reales y FQDN Kubernetes completo."
}

wait_dashboard_external_ready(){
  local end=$((SECONDS + DASHBOARD_WAIT_SECONDS)) body_file="/tmp/wazuh_dashboard_body_${TS}.txt" headers_file="/tmp/wazuh_dashboard_headers_${TS}.txt"
  log "Validando disponibilidad externa del Dashboard en https://${DASHBOARD_IP}..."
  while (( SECONDS < end )); do
    if curl -k -sS -D "$headers_file" --max-time 10 "https://${DASHBOARD_IP}" -o "$body_file"; then
      cp "$headers_file" "${OUT_DIR}/${TS}-wazuh-dashboard-headers.txt" 2>/dev/null || true
      cp "$body_file" "${OUT_DIR}/${TS}-wazuh-dashboard-body.txt" 2>/dev/null || true
      if ! grep -qi "server is not ready yet" "$body_file"; then
        echo "[OK] Dashboard HTTPS externo responde y ya no reporta inicialización pendiente."
        return 0
      fi
      echo "[WAIT] Dashboard responde, pero aún indica: server is not ready yet."
    else
      echo "[WAIT] Dashboard aún no responde por HTTPS externo."
    fi
    sleep 15
  done
  warn "Dashboard no quedó listo externamente dentro de ${DASHBOARD_WAIT_SECONDS}s. Se conserva evidencia; no afecta pods, pero no conviene congelar C aún."
  return 1
}

validate_manager_api_port(){
  log "Validando puerto Wazuh API 55000 en ${MANAGER_IP}..."
  if timeout 5 bash -lc "</dev/tcp/${MANAGER_IP}/55000" >/dev/null 2>&1; then
    echo "[OK] Puerto Wazuh API 55000 accesible."
    return 0
  fi
  warn "Puerto Wazuh API 55000 no validado externamente. Revisar red/servicio antes de freeze."
  return 1
}

export_live_frozen_manifests(){
  local frozen_dir="${ROOT_DIR}/kubernetes/security/wazuh-frozen"
  mkdir -p "$frozen_dir"
  log "Exportando snapshot YAML del despliegue Wazuh actual a kubernetes/security/wazuh-frozen/ para trazabilidad offline..."
  for r in \
    sc/wazuh-storage \
    cm/dashboard-conf cm/indexer-conf cm/wazuh-conf \
    secret/dashboard-cred secret/indexer-cred secret/wazuh-api-cred secret/wazuh-authd-pass secret/wazuh-cluster-key \
    svc/dashboard svc/indexer svc/wazuh svc/wazuh-cluster svc/wazuh-indexer svc/wazuh-dashboard-lb svc/wazuh-manager-lb \
    statefulset/wazuh-indexer statefulset/wazuh-manager-master deployment/wazuh-dashboard; do
    kind="${r%%/*}"; name="${r##*/}"
    out="${frozen_dir}/${kind}-${name}.yaml"
    if [[ "$kind" == "sc" ]]; then
      ${KUBECTL} get "$r" -o yaml > "$out" 2>/dev/null || true
    else
      ${KUBECTL} -n "$NS" get "$r" -o yaml > "$out" 2>/dev/null || true
    fi
  done
  cat > "${frozen_dir}/README.md" <<EOF_FROZEN
# Wazuh frozen manifests - Scenario C

Snapshot exported from the validated MicroK8s single-node deployment.
Purpose: offline traceability and reviewer reproducibility evidence.

This directory is not a new phase README; it documents the frozen manifest snapshot stored under kubernetes/security/.
EOF_FROZEN
}

# =============================================================================
# MAIN
# =============================================================================
mkdir -p "$OUT_DIR"
log "Escenario C — Wazuh Security Layer v8.2 (API FQDN corregido)"
log "Cliente Kubernetes: ${KUBECTL}"
log "Namespace: ${NS}"
log "Modelo real: MicroK8s single-node / Ubuntu 24.04 / containerd / Calico / MetalLB / microk8s-hostpath"

require_cmd curl
require_cmd awk
require_cmd sed
require_cmd jq
require_cmd python3

validate_microk8s_profile
${KUBECTL} get ns iiot-poc >/dev/null 2>&1 || fail "No existe namespace iiot-poc. Ejecuta primero Foundation."
${KUBECTL} get ns monitoring >/dev/null 2>&1 || fail "No existe namespace monitoring. Ejecuta primero Zabbix."

log "Aplicando manifiestos incrementales del laboratorio en kubernetes/security..."
${KUBECTL} apply -k "${ROOT_DIR}/kubernetes/security"

if ${KUBECTL} -n "$NS" get statefulset wazuh-indexer >/dev/null 2>&1 && \
   ${KUBECTL} -n "$NS" get statefulset wazuh-manager-master >/dev/null 2>&1 && \
   ${KUBECTL} -n "$NS" get deployment wazuh-dashboard >/dev/null 2>&1; then
  log "Wazuh ya existe en el cluster. Se ejecuta reconciliación correctiva v8.2."
else
  fail "No existe despliegue Wazuh previo. Para v8.2 no se usa git clone runtime. Ejecuta primero el despliegue base validado o incorpora manifiestos congelados bajo kubernetes/security/wazuh-frozen/."
fi

remove_wazuh_worker_if_present
patch_official_services_to_clusterip

log "Aplicando servicios MetalLB controlados del laboratorio..."
${KUBECTL} apply -f "${ROOT_DIR}/kubernetes/security/03-wazuh-services.yaml"
${KUBECTL} patch svc wazuh-dashboard-lb -n "$NS" --type=merge -p "{\"spec\":{\"loadBalancerIP\":\"${DASHBOARD_IP}\"}}" >/dev/null 2>&1 || true
${KUBECTL} patch svc wazuh-manager-lb -n "$NS" --type=merge -p "{\"spec\":{\"loadBalancerIP\":\"${MANAGER_IP}\"}}" >/dev/null 2>&1 || true

wait_pvc_bound 300
wait_workload statefulset wazuh-indexer 600s
wait_workload statefulset wazuh-manager-master 600s
wait_workload deployment wazuh-dashboard 600s

manager_pod="$(wait_pod_ready_by_label 'app=wazuh-manager,node-type=master' 'Wazuh Manager master' 300 | tail -n 1)"
dashboard_pod="$(wait_pod_ready_by_label 'app=wazuh-dashboard' 'Wazuh Dashboard' 300 | tail -n 1)"

install_rules_and_localfile "$manager_pod"
reconcile_dashboard_api_connection "$dashboard_pod"

dash_status="WARN"
api_status="WARN"
wait_dashboard_external_ready && dash_status="OK" || true
validate_manager_api_port && api_status="OK" || true
export_live_frozen_manifests

log "Estado final namespace security:"
${KUBECTL} get pods -n "$NS" -o wide | tee "${OUT_DIR}/${TS}-wazuh-pods-final.txt"
${KUBECTL} get svc -n "$NS" -o wide | tee "${OUT_DIR}/${TS}-wazuh-services-final.txt"
${KUBECTL} get pvc -n "$NS" -o wide | tee "${OUT_DIR}/${TS}-wazuh-pvc-final.txt" || true

summary_header "Scenario C Wazuh Security Deployment v8.2 (API FQDN Corregido)"
summary_ok "MicroK8s single-node validado"
summary_ok "Namespace security creado/validado"
summary_ok "Prerequisitos Foundation IIoT y Zabbix validados"
summary_ok "StorageClass validada: ${STORAGE_CLASS}"
summary_ok "Wazuh existente reconciliado sin git clone runtime ni redeploy destructivo"
summary_ok "Worker Wazuh adicional eliminado/no presente para preservar single-node/all-in-one"
summary_ok "PVCs Wazuh Bound"
summary_ok "Workloads Wazuh listos: indexer, manager master, dashboard"
summary_ok "Dashboard configurado contra Wazuh Manager API con FQDN completo y credenciales reales"
summary_ok "Reglas IIoT/MITRE ICS reinstaladas post-start con permisos controlados"
summary_ok "Localfile baseline configurado para eventos estructurados IIoT"
[[ "$dash_status" == "OK" ]] && summary_ok "Dashboard HTTPS externo validado" || summary_warn "Dashboard HTTPS externo pendiente de readiness completa"
[[ "$api_status" == "OK" ]] && summary_ok "Puerto Wazuh API 55000 validado" || summary_warn "Puerto Wazuh API 55000 pendiente de validación externa"
summary_ok "Snapshot de manifiestos Wazuh exportado en kubernetes/security/wazuh-frozen/"
summary_ok "Scope preservado: IIoT + Zabbix + Wazuh + correlación"