#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

OUT_DIR="${ROOT_DIR}/evidence/zabbix"
mkdir -p "$OUT_DIR"

ZABBIX_URL="${ZABBIX_URL:-http://10.10.0.160/api_jsonrpc.php}"
ZABBIX_USER="${ZABBIX_USER:-Admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-zabbix}"

log "Validando acceso a Zabbix Web/API..."
curl -fsSI --max-time 5 http://10.10.0.160 >/dev/null || fail "Zabbix UI no responde."

export OUT_DIR ZABBIX_URL ZABBIX_USER ZABBIX_PASSWORD

python3 - <<'PY'
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

out = Path(os.environ["OUT_DIR"])
url = os.environ["ZABBIX_URL"]
user = os.environ["ZABBIX_USER"]
password = os.environ["ZABBIX_PASSWORD"]

LAB_HOSTS = ["mqtt-broker", "health-app", "telemetry-api", "vulnerable-app"]

def api(method, params=None, auth=None):
    payload = {"jsonrpc":"2.0", "method":method, "params":params or {}, "id":1}
    if auth:
        payload["auth"] = auth
    req = Request(url, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json"})
    with urlopen(req, timeout=20) as r:
        data = json.loads(r.read().decode())
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]

auth = api("user.login", {"username": user, "password": password})

hostgroups = api("hostgroup.get", {
    "output": "extend",
    "filter": {"name": ["IIoT Lab Services"]}
}, auth)

hosts = api("host.get", {
    "output": "extend",
    "selectGroups": "extend",
    "filter": {"host": LAB_HOSTS}
}, auth)

hostids = [h["hostid"] for h in hosts]

items = api("item.get", {
    "output": "extend",
    "selectHosts": ["host"],
    "hostids": hostids,
    "search": {"key_": "net.tcp.service"}
}, auth) if hostids else []

triggers = api("trigger.get", {
    "output": "extend",
    "selectHosts": ["host"],
    "hostids": hostids
}, auth) if hostids else []

(out / "zabbix_hostgroups.json").write_text(json.dumps(hostgroups, indent=2))
(out / "zabbix_hosts.json").write_text(json.dumps(hosts, indent=2))
(out / "zabbix_items.json").write_text(json.dumps(items, indent=2))
(out / "zabbix_triggers.json").write_text(json.dumps(triggers, indent=2))

summary = "# Zabbix Configuration Summary\n\n"
summary += "| Object | Count |\n|---|---:|\n"
summary += f"| Host groups | {len(hostgroups)} |\n"
summary += f"| Hosts | {len(hosts)} |\n"
summary += f"| Items | {len(items)} |\n"
summary += f"| Triggers | {len(triggers)} |\n\n"
summary += "## Hosts\n\n"

for h in hosts:
    summary += f"- {h.get('host')} / {h.get('name')}\n"

summary += "\n## Exported files\n\n"
summary += "- zabbix_hostgroups.json\n"
summary += "- zabbix_hosts.json\n"
summary += "- zabbix_items.json\n"
summary += "- zabbix_triggers.json\n"

(out / "zabbix_configuration_summary.md").write_text(summary)
print(summary)
PY

summary_header "Zabbix Configuration Export"
summary_ok "Host groups exportados"
summary_ok "Hosts IIoT exportados"
summary_ok "Items IIoT exportados"
summary_ok "Triggers IIoT exportados"
summary_ok "Resumen generado: evidence/zabbix/zabbix_configuration_summary.md"
summary_ok "Configuración Zabbix lista para reproducibilidad y revisión"
