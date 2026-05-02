#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_FILE="${1:-results/raw/zabbix_items_snapshot.csv}"

ITERATIONS="${ITERATIONS:-1}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
HISTORY_LOOKBACK_SECONDS="${HISTORY_LOOKBACK_SECONDS:-900}"
ZABBIX_URL="${ZABBIX_URL:-http://10.10.0.160/api_jsonrpc.php}"
ZABBIX_USER="${ZABBIX_USER:-Admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-zabbix}"

mkdir -p "$(dirname "$OUT_FILE")"

export OUT_FILE ITERATIONS SLEEP_SECONDS HISTORY_LOOKBACK_SECONDS ZABBIX_URL ZABBIX_USER ZABBIX_PASSWORD

python3 <<'PY'
import csv
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

url = os.environ["ZABBIX_URL"]
user = os.environ["ZABBIX_USER"]
password = os.environ["ZABBIX_PASSWORD"]
out_file = Path(os.environ["OUT_FILE"])
iterations = int(os.environ["ITERATIONS"])
sleep_seconds = float(os.environ["SLEEP_SECONDS"])
lookback = int(os.environ["HISTORY_LOOKBACK_SECONDS"])

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

def safe_float(value):
    try:
        return float(value)
    except Exception:
        return ""

fieldnames = [
    "timestamp_utc", "host", "item", "key", "itemid", "value_type",
    "history_clock", "history_utc", "history_value", "lastvalue", "lastclock",
    "source", "samples_in_window"
]

with out_file.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()

auth = api("user.login", {"username": user, "password": password})

for _ in range(iterations):
    now = int(time.time())
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    items = api(
        "item.get",
        {
            "output": ["itemid", "name", "key_", "lastvalue", "lastclock", "value_type", "state", "status"],
            "selectHosts": ["host"],
            "search": {"key_": "net.tcp.service"},
            "sortfield": "name"
        },
        auth
    )

    rows = []
    for item in items:
        hosts = item.get("hosts", [])
        if not hosts:
            continue
        host = hosts[0].get("host", "")
        if host not in LAB_HOSTS:
            continue
        value_type = int(item.get("value_type", 3))
        history = api(
            "history.get",
            {
                "output": "extend",
                "history": value_type,
                "itemids": item["itemid"],
                "time_from": max(0, now - lookback),
                "time_till": now,
                "sortfield": "clock",
                "sortorder": "DESC",
                "limit": 1
            },
            auth
        )
        if history:
            h = history[0]
            clock = int(h.get("clock", 0))
            rows.append({
                "timestamp_utc": ts,
                "host": host,
                "item": item.get("name", ""),
                "key": item.get("key_", ""),
                "itemid": item.get("itemid", ""),
                "value_type": value_type,
                "history_clock": clock,
                "history_utc": datetime.fromtimestamp(clock, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if clock else "",
                "history_value": h.get("value", ""),
                "lastvalue": item.get("lastvalue", ""),
                "lastclock": item.get("lastclock", ""),
                "source": "history.get",
                "samples_in_window": len(history)
            })
        else:
            rows.append({
                "timestamp_utc": ts,
                "host": host,
                "item": item.get("name", ""),
                "key": item.get("key_", ""),
                "itemid": item.get("itemid", ""),
                "value_type": value_type,
                "history_clock": "",
                "history_utc": "",
                "history_value": "",
                "lastvalue": item.get("lastvalue", ""),
                "lastclock": item.get("lastclock", ""),
                "source": "NO_HISTORY_IN_WINDOW",
                "samples_in_window": 0
            })

    with out_file.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writerows(rows)

    if _ < iterations - 1:
        time.sleep(sleep_seconds)

print(f"[OK] Snapshot Zabbix real exportado en: {out_file}")
PY
