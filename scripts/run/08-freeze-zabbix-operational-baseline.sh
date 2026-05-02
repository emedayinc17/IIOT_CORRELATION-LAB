#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

KUBECTL="$(detect_kubectl)"
TS="$(date -u +%Y%m%d_%H%M%S)"
FREEZE_DIR="${ROOT_DIR}/baseline/scenario_B_${TS}"

mkdir -p "$FREEZE_DIR"

log "Validando resultados previos del Escenario B..."
csv_has_data "${ROOT_DIR}/results/raw/http_baseline_zabbix.csv"
csv_has_data "${ROOT_DIR}/results/raw/mqtt_messages_zabbix.csv"
csv_has_data "${ROOT_DIR}/results/raw/k8s_resources_zabbix.csv"
csv_has_data "${ROOT_DIR}/results/raw/zabbix_items_snapshot.csv"
[[ -s "${ROOT_DIR}/results/raw/experiment_metadata_zabbix.json" ]] || fail "Falta experiment_metadata_zabbix.json"

log "Exportando snapshots Kubernetes..."
${KUBECTL} get nodes -o wide > "${FREEZE_DIR}/nodes.txt"
${KUBECTL} get all -A -o yaml > "${FREEZE_DIR}/cluster_all.yaml"
${KUBECTL} get pods -n iiot-poc -o wide > "${FREEZE_DIR}/pods_iiot_poc.txt"
${KUBECTL} get svc -n iiot-poc -o wide > "${FREEZE_DIR}/services_iiot_poc.txt"
${KUBECTL} get pods -n monitoring -o wide > "${FREEZE_DIR}/pods_monitoring.txt"
${KUBECTL} get svc -n monitoring -o wide > "${FREEZE_DIR}/services_monitoring.txt"
${KUBECTL} get pvc -n monitoring > "${FREEZE_DIR}/pvc_monitoring.txt"
${KUBECTL} top nodes > "${FREEZE_DIR}/top_nodes.txt" || true
${KUBECTL} top pods -A > "${FREEZE_DIR}/top_pods_all.txt" || true

log "Exportando snapshot lógico de Zabbix API..."
ZABBIX_URL="${ZABBIX_URL:-http://10.10.0.160/api_jsonrpc.php}" \
ZABBIX_USER="${ZABBIX_USER:-Admin}" \
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-zabbix}" \
FREEZE_DIR="${FREEZE_DIR}" \
python3 - <<'PY'
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

url = os.environ["ZABBIX_URL"]
user = os.environ["ZABBIX_USER"]
password = os.environ["ZABBIX_PASSWORD"]
freeze = Path(os.environ["FREEZE_DIR"])

def api(method, params=None, auth=None):
    payload = {"jsonrpc":"2.0","method":method,"params":params or {},"id":1}
    if auth:
        payload["auth"] = auth
    req = Request(url, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json"})
    with urlopen(req, timeout=20) as r:
        data = json.loads(r.read().decode())
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]

auth = api("user.login", {"username": user, "password": password})
hosts = api("host.get", {"output": "extend", "selectGroups": "extend"}, auth)
items = api("item.get", {"output": "extend", "selectHosts": ["host"], "search": {"key_": "net.tcp.service"}}, auth)
triggers = api("trigger.get", {"output": "extend", "selectHosts": ["host"]}, auth)

(freeze / "zabbix_hosts.json").write_text(json.dumps(hosts, indent=2))
(freeze / "zabbix_items.json").write_text(json.dumps(items, indent=2))
(freeze / "zabbix_triggers.json").write_text(json.dumps(triggers, indent=2))
PY

log "Copiando resultados raw..."
cp -a "${ROOT_DIR}/results/raw" "${FREEZE_DIR}/results_raw"

log "Generando archivo comprimido del freeze..."
tar -czf "${ROOT_DIR}/baseline/scenario_B_${TS}.tar.gz" -C "${ROOT_DIR}/baseline" "scenario_B_${TS}"

ARCHIVE="${ROOT_DIR}/baseline/scenario_B_${TS}.tar.gz"

summary_header "Freeze Escenario B"
summary_ok "Resultados raw Zabbix validados"
summary_ok "Snapshot completo Kubernetes exportado"
summary_ok "Pods/servicios iiot-poc exportados"
summary_ok "Pods/servicios/PVC monitoring exportados"
summary_ok "Snapshot lógico Zabbix API exportado"
summary_ok "Resultados raw copiados al directorio de congelamiento"
summary_ok "Archivo comprimido generado: ${ARCHIVE}"
summary_ok "Escenario B queda congelado para comparación con Escenario A y futura correlación"
