#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

ZABBIX_URL="${ZABBIX_URL:-http://10.10.0.160/api_jsonrpc.php}"
ZABBIX_WEB_URL="${ZABBIX_WEB_URL:-http://10.10.0.160}"
ZABBIX_USER="${ZABBIX_USER:-Admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-zabbix}"
ZABBIX_HISTORY_WAIT_SECONDS="${ZABBIX_HISTORY_WAIT_SECONDS:-180}"
ZABBIX_HISTORY_POLL_SECONDS="${ZABBIX_HISTORY_POLL_SECONDS:-10}"

log "Configurando Zabbix Monitoring — IIoT real history instrumentation"
log "Zabbix API: ${ZABBIX_URL}"
log "Zabbix Web: ${ZABBIX_WEB_URL}"

curl -fsSI --max-time 10 "${ZABBIX_WEB_URL}" >/dev/null || fail "Zabbix Web no responde en ${ZABBIX_WEB_URL}"

export ZABBIX_URL ZABBIX_USER ZABBIX_PASSWORD ZABBIX_HISTORY_WAIT_SECONDS ZABBIX_HISTORY_POLL_SECONDS

python3 - <<'PY'
import json
import os
import sys
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen

url = os.environ["ZABBIX_URL"]
user = os.environ["ZABBIX_USER"]
password = os.environ["ZABBIX_PASSWORD"]
wait_seconds = int(os.environ.get("ZABBIX_HISTORY_WAIT_SECONDS", "180"))
poll_seconds = int(os.environ.get("ZABBIX_HISTORY_POLL_SECONDS", "10"))

SERVICES = [
    {"host": "mqtt-broker", "ip": "10.10.0.151", "port": 1883, "service": "tcp", "display": "mqtt-broker"},
    {"host": "health-app", "ip": "10.10.0.152", "port": 8080, "service": "http", "display": "health-app"},
    {"host": "telemetry-api", "ip": "10.10.0.153", "port": 8080, "service": "http", "display": "telemetry-api"},
    {"host": "vulnerable-app", "ip": "10.10.0.154", "port": 8080, "service": "http", "display": "vulnerable-app"},
]

DESIRED_ITEMS = []

def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def api(method, params=None, auth=None):
    payload = {"jsonrpc": "2.0", "method": method, "params": params or {}, "id": 1}
    if auth:
        payload["auth"] = auth
    req = Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=30) as r:
        data = json.loads(r.read().decode())
    if "error" in data:
        raise RuntimeError(f"{method}: {data['error']}")
    return data["result"]

print(f"[INFO] {utc_now()} Login Zabbix API")
auth = api("user.login", {"username": user, "password": password})

def get_or_create_group(name):
    groups = api("hostgroup.get", {"output": ["groupid"], "filter": {"name": [name]}}, auth)
    if groups:
        return groups[0]["groupid"]
    return api("hostgroup.create", {"name": name}, auth)["groupids"][0]

groupid = get_or_create_group("IIoT Lab Services")
print(f"[OK] Hostgroup IIoT Lab Services: {groupid}")

def ensure_host_and_interface(svc):
    existing = api("host.get", {
        "output": ["hostid", "host", "name"],
        "selectInterfaces": ["interfaceid", "type", "main", "useip", "ip", "dns", "port"],
        "filter": {"host": [svc["host"]]}
    }, auth)

    if existing:
        host = existing[0]
        hostid = host["hostid"]
        api("host.update", {
            "hostid": hostid,
            "name": svc["display"],
            "groups": [{"groupid": groupid}],
            "status": 0
        }, auth)
    else:
        result = api("host.create", {
            "host": svc["host"],
            "name": svc["display"],
            "groups": [{"groupid": groupid}],
            "interfaces": [{
                "type": 1,
                "main": 1,
                "useip": 1,
                "ip": svc["ip"],
                "dns": "",
                "port": "10050"
            }],
            "status": 0
        }, auth)
        hostid = result["hostids"][0]

    interfaces = api("hostinterface.get", {"output": "extend", "hostids": hostid}, auth)
    agent_interfaces = [i for i in interfaces if str(i.get("type")) == "1"]
    desired_interface = {
        "type": 1,
        "main": 1,
        "useip": 1,
        "ip": svc["ip"],
        "dns": "",
        "port": "10050"
    }
    if agent_interfaces:
        main = agent_interfaces[0]
        api("hostinterface.update", {"interfaceid": main["interfaceid"], **desired_interface}, auth)
        for extra in agent_interfaces[1:]:
            try:
                api("hostinterface.delete", [extra["interfaceid"]], auth)
            except Exception:
                pass
    else:
        api("hostinterface.create", {"hostid": hostid, **desired_interface}, auth)

    return hostid

def get_item_by_name(hostid, name):
    items = api("item.get", {"output": ["itemid", "name", "key_", "state", "status", "error"], "hostids": hostid, "filter": {"name": [name]}}, auth)
    return items[0] if items else None

def get_item_by_key(hostid, key):
    items = api("item.get", {"output": ["itemid", "name", "key_", "state", "status", "error"], "hostids": hostid, "filter": {"key_": [key]}}, auth)
    return items[0] if items else None

def upsert_item(hostid, name, key, value_type):
    by_name = get_item_by_name(hostid, name)
    by_key = get_item_by_key(hostid, key)
    params = {
        "name": name,
        "key_": key,
        "type": 3,                 # Zabbix simple check
        "value_type": value_type,  # 3 unsigned integer, 0 float
        "delay": "30s",
        "history": "7d",
        "trends": "30d",
        "status": 0
    }
    if by_name:
        itemid = by_name["itemid"]
        api("item.update", {"itemid": itemid, **params}, auth)
    elif by_key:
        itemid = by_key["itemid"]
        api("item.update", {"itemid": itemid, **params}, auth)
    else:
        itemid = api("item.create", {"hostid": hostid, **params}, auth)["itemids"][0]
    DESIRED_ITEMS.append({"hostid": hostid, "host": None, "itemid": itemid, "name": name, "key": key, "value_type": int(value_type)})
    return itemid

def delete_legacy_empty_ip_items(hostid, desired_itemids):
    items = api("item.get", {"output": ["itemid", "name", "key_"], "hostids": hostid, "search": {"key_": "net.tcp.service"}}, auth)
    for item in items:
        key = item.get("key_", "")
        if item["itemid"] not in desired_itemids and ",," in key:
            print(f"[INFO] Removing legacy unsupported Zabbix item: {item['name']} | {key}")
            api("item.delete", [item["itemid"]], auth)

def trigger_by_description(description):
    res = api("trigger.get", {"output": ["triggerid", "description", "expression"], "filter": {"description": [description]}}, auth)
    return res[0] if res else None

def upsert_trigger(description, expression, priority):
    existing = trigger_by_description(description)
    params = {"description": description, "expression": expression, "priority": priority, "status": 0}
    if existing:
        api("trigger.update", {"triggerid": existing["triggerid"], **params}, auth)
    else:
        api("trigger.create", params, auth)

hostids = {}
for svc in SERVICES:
    hostid = ensure_host_and_interface(svc)
    hostids[svc["host"]] = hostid

    availability_key = f'net.tcp.service[{svc["service"]},{svc["ip"]},{svc["port"]}]'
    latency_key = f'net.tcp.service.perf[{svc["service"]},{svc["ip"]},{svc["port"]}]'

    availability_item = upsert_item(hostid, f'{svc["host"]} availability', availability_key, 3)
    latency_item = upsert_item(hostid, f'{svc["host"]} latency seconds', latency_key, 0)
    delete_legacy_empty_ip_items(hostid, {availability_item, latency_item})

    upsert_trigger(
        f'{svc["host"]} unavailable',
        f'last(/{svc["host"]}/{availability_key})=0',
        4
    )
    upsert_trigger(
        f'{svc["host"]} high latency',
        f'avg(/{svc["host"]}/{latency_key},5m)>1',
        3
    )

# Refresh desired item metadata after item updates.
desired_keys = []
for svc in SERVICES:
    desired_keys.extend([
        f'net.tcp.service[{svc["service"]},{svc["ip"]},{svc["port"]}]',
        f'net.tcp.service.perf[{svc["service"]},{svc["ip"]},{svc["port"]}]'
    ])

all_items = []
for svc in SERVICES:
    hostid = hostids[svc["host"]]
    items = api("item.get", {
        "output": ["itemid", "name", "key_", "value_type", "state", "status", "error", "delay", "lastvalue", "lastclock"],
        "hostids": hostid,
        "filter": {"key_": desired_keys},
        "selectHosts": ["host"]
    }, auth)
    for item in items:
        host = item.get("hosts", [{}])[0].get("host", svc["host"])
        all_items.append({**item, "host": host})

print("[INFO] Zabbix items configured with explicit IP parameters:")
for item in sorted(all_items, key=lambda x: (x["host"], x["name"])):
    print(f"  - {item['host']} | {item['name']} | {item['key_']} | itemid={item['itemid']} | state={item['state']} | lastclock={item['lastclock']} | error={item.get('error','')}")

# Wait until Zabbix simple checks become supported and history is available.
deadline = time.time() + wait_seconds
last_status = []
while True:
    now = int(time.time())
    problems = []
    ok_count = 0
    last_status = []

    for item in all_items:
        refreshed = api("item.get", {
            "output": ["itemid", "name", "key_", "value_type", "state", "status", "error", "lastvalue", "lastclock"],
            "itemids": item["itemid"],
            "selectHosts": ["host"]
        }, auth)[0]
        history_type = int(refreshed["value_type"])
        history = api("history.get", {
            "output": "extend",
            "history": history_type,
            "itemids": [item["itemid"]],
            "time_from": now - max(wait_seconds, 300),
            "time_till": now,
            "sortfield": "clock",
            "sortorder": "DESC",
            "limit": 1
        }, auth)
        host = refreshed.get("hosts", [{}])[0].get("host", item.get("host", ""))
        state = str(refreshed.get("state", ""))
        status = str(refreshed.get("status", ""))
        lastclock = str(refreshed.get("lastclock", "0"))
        error = refreshed.get("error", "")
        samples = len(history)
        row = f"{host} | {refreshed['name']} | {refreshed['key_']} | state={state} | status={status} | lastclock={lastclock} | history_samples={samples} | error={error}"
        last_status.append(row)
        if state == "0" and status == "0" and samples > 0 and lastclock != "0":
            ok_count += 1
        else:
            problems.append(row)

    if ok_count == len(all_items):
        print(f"[OK] Zabbix history real disponible para {ok_count}/{len(all_items)} items IIoT.")
        break

    if time.time() >= deadline:
        print("[ERROR] Zabbix no generó history real para todos los items dentro de la ventana configurada.", file=sys.stderr)
        print("[ERROR] Estado final de items:", file=sys.stderr)
        for row in last_status:
            print(f"  {row}", file=sys.stderr)
        sys.exit(2)

    print(f"[WAIT] Zabbix history pending: {ok_count}/{len(all_items)} items ready. Retrying in {poll_seconds}s...")
    time.sleep(poll_seconds)

print("Zabbix monitoring objects configured successfully with real history.")
PY

log "Exportando evidencia Zabbix de configuración real..."
mkdir -p "${ROOT_DIR}/evidence/zabbix"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

python3 - <<'PY'
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

url = os.environ["ZABBIX_URL"]
user = os.environ["ZABBIX_USER"]
password = os.environ["ZABBIX_PASSWORD"]
root = Path(os.environ.get("ROOT_DIR", "."))
outdir = root / "evidence" / "zabbix"
outdir.mkdir(parents=True, exist_ok=True)
ts = os.environ.get("TS", "zabbix")

LAB_HOSTS = {"mqtt-broker", "health-app", "telemetry-api", "vulnerable-app"}

def api(method, params=None, auth=None):
    payload = {"jsonrpc": "2.0", "method": method, "params": params or {}, "id": 1}
    if auth:
        payload["auth"] = auth
    req = Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=20) as r:
        data = json.loads(r.read().decode())
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]

auth = api("user.login", {"username": user, "password": password})
hosts = api("host.get", {"output": ["hostid", "host", "name", "status"], "selectInterfaces": "extend"}, auth)
items = api("item.get", {"output": ["itemid", "hostid", "name", "key_", "value_type", "type", "status", "state", "error", "delay", "lastvalue", "lastclock"], "selectHosts": ["host"], "search": {"key_": "net.tcp.service"}}, auth)
triggers = api("trigger.get", {"output": ["triggerid", "description", "expression", "priority", "status"], "selectHosts": ["host"]}, auth)

hosts = [h for h in hosts if h.get("host") in LAB_HOSTS]
items = [i for i in items if i.get("hosts", [{}])[0].get("host", "") in LAB_HOSTS]
triggers = [t for t in triggers if any(h.get("host") in LAB_HOSTS for h in t.get("hosts", []))]

(outdir / f"{ts}-zabbix-hosts-real-monitoring.json").write_text(json.dumps(hosts, indent=2), encoding="utf-8")
(outdir / f"{ts}-zabbix-items-real-monitoring.json").write_text(json.dumps(items, indent=2), encoding="utf-8")
(outdir / f"{ts}-zabbix-triggers-real-monitoring.json").write_text(json.dumps(triggers, indent=2), encoding="utf-8")

summary = outdir / f"{ts}-zabbix-real-monitoring-summary.csv"
summary.write_text("host,item,key,state,status,lastvalue,lastclock,error\n", encoding="utf-8")
with summary.open("a", encoding="utf-8") as f:
    for item in sorted(items, key=lambda x: (x.get("hosts", [{}])[0].get("host", ""), x.get("name", ""))):
        host = item.get("hosts", [{}])[0].get("host", "")
        row = [host, item.get("name", ""), item.get("key_", ""), item.get("state", ""), item.get("status", ""), item.get("lastvalue", ""), item.get("lastclock", ""), item.get("error", "").replace(",", " ")]
        f.write(",".join(map(str, row)) + "\n")
print(f"[OK] Evidence exported to {outdir}")
PY

echo
echo "============================================================"
echo "[SUMMARY] Zabbix Operational Instrumentation"
echo "============================================================"
echo "[OK] Zabbix API accesible"
echo "[OK] Host group IIoT Lab Services configurado"
echo "[OK] Hosts IIoT configurados con interfaces IP explícitas"
echo "[OK] Items simple check corregidos con IP explícita en key_"
echo "[OK] Items legacy con parámetro IP vacío removidos/actualizados"
echo "[OK] Items de disponibilidad generan history real"
echo "[OK] Items de latencia generan history real"
echo "[OK] Triggers operacionales configurados con keys corregidas"
echo "[OK] Evidencia Zabbix exportada en evidence/zabbix/"
echo "[OK] Escenario B/D listo para correlación operacional real"
