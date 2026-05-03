#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

TZ_NAME="${TZ_NAME:-America/Lima}"

now_local() {
  TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %z (%Z)'
}

line() {
  printf '%s\n' '============================================================'
}

phase() {
  printf '\n------------------------------------------------------------\n'
  printf '[PHASE %s] ES: %s\n' "$1" "$2"
  printf '[PHASE %s] EN: %s\n' "$1" "$3"
  printf '%s\n\n' '------------------------------------------------------------'
}

ok() {
  printf '[OK] ES: %s\n' "$1"
  printf '[OK] EN: %s\n' "$2"
}

warn() {
  printf '[WARN] ES: %s\n' "$1"
  printf '[WARN] EN: %s\n' "$2"
}

fail() {
  printf '\n[ERROR] ES: %s\n' "$1" >&2
  printf '[ERROR] EN: %s\n' "$2" >&2
  exit 1
}

script_start() {
  line
  printf '[SCRIPT START] %s\n' "$1"
  printf 'Hora de inicio / Start time: %s\n' "$(now_local)"
  printf 'ES: %s\n' "$2"
  printf 'EN: %s\n' "$3"
  line
  printf '\n'
}

script_end() {
  local code="$?"
  line
  printf '[EXECUTION END]\n'
  printf 'Script: %s\n' "$(basename "$0")"
  printf 'Hora de fin / End time: %s\n' "$(now_local)"
  printf 'Exit code: %s\n' "$code"
  if [[ "$code" == "0" ]]; then
    printf 'ES: Ejecución finalizada correctamente.\n'
    printf 'EN: Execution completed successfully.\n'
  else
    printf 'ES: Ejecución finalizada con error; revisar el último mensaje y evidencia generada.\n'
    printf 'EN: Execution finished with an error; review the latest message and generated evidence.\n'
  fi
  line
}
trap script_end EXIT

script_start "16-run-correlation-experiment.sh" \
  "Correlacionar Wazuh con métricas Zabbix reales generando deltas por ejecución." \
  "Correlate Wazuh with real Zabbix metrics generating per-execution deltas."

KUBECTL="${KUBECTL:-microk8s kubectl}"
RAW_D_DIR="${RAW_D_DIR:-results/raw/scenario_d}"
PROCESSED_DIR="${PROCESSED_DIR:-results/processed}"
CORRELATION_WINDOW_SECONDS="${CORRELATION_WINDOW_SECONDS:-120}"
ZABBIX_HISTORY_LOOKBACK_SECONDS="${ZABBIX_HISTORY_LOOKBACK_SECONDS:-120}"
ZABBIX_HISTORY_FORWARD_SECONDS="${ZABBIX_HISTORY_FORWARD_SECONDS:-120}"
ZABBIX_URL="${ZABBIX_URL:-http://10.10.0.160/api_jsonrpc.php}"
ZABBIX_USER="${ZABBIX_USER:-Admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-zabbix}"

mkdir -p "$RAW_D_DIR" "$PROCESSED_DIR" evidence/wazuh

ATTACK_FILE="$RAW_D_DIR/mitre_ics_attacks.csv"
WAZUH_FILE="$RAW_D_DIR/wazuh_security_events.csv"
ZABBIX_METRICS_FILE="$RAW_D_DIR/zabbix_correlation_metrics.csv"
ZABBIX_VALIDATION_FILE="$RAW_D_DIR/zabbix_history_validation.csv"
CORRELATION_FILE="$PROCESSED_DIR/correlation_dataset.csv"

phase "1/4" "Validar entradas de campaña D." "Validate Scenario D campaign inputs."

[[ -f "$ATTACK_FILE" ]] || fail \
  "No existe $ATTACK_FILE. Ejecutar script 15 primero." \
  "$ATTACK_FILE does not exist. Run script 15 first."

phase "2/4" "Exportar eventos Wazuh SCENARIO_D desde localfile/alerts." "Export Wazuh SCENARIO_D events from localfile/alerts."

MANAGER_POD="$($KUBECTL get pod -n security -l app=wazuh-manager,role=master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$MANAGER_POD" ]]; then
  MANAGER_POD="$($KUBECTL get pod -n security | awk '/wazuh-manager-master/ {print $1; exit}')"
fi
[[ -n "$MANAGER_POD" ]] || fail "No se encontró pod Wazuh Manager master." "Wazuh Manager master pod was not found."

# Export localfile content. It may contain historical runs; Python will filter by attack_uid.
$KUBECTL exec -n security "$MANAGER_POD" -- sh -c 'cat /var/ossec/logs/iiot-lab/scenario_d_attacks.json 2>/dev/null || true' \
  > evidence/wazuh/scenario_d_attacks_localfile_export.ndjson || true

phase "3/4" "Generar correlación con deltas por attack_uid." "Generate correlation with per-attack_uid deltas."

export ATTACK_FILE WAZUH_FILE ZABBIX_METRICS_FILE ZABBIX_VALIDATION_FILE CORRELATION_FILE
export CORRELATION_WINDOW_SECONDS ZABBIX_HISTORY_LOOKBACK_SECONDS ZABBIX_HISTORY_FORWARD_SECONDS
export ZABBIX_URL ZABBIX_USER ZABBIX_PASSWORD

python3 - <<'PY'
import csv, json, os, math
from pathlib import Path
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from collections import defaultdict

attack_file = Path(os.environ["ATTACK_FILE"])
wazuh_file = Path(os.environ["WAZUH_FILE"])
zabbix_metrics_file = Path(os.environ["ZABBIX_METRICS_FILE"])
zabbix_validation_file = Path(os.environ["ZABBIX_VALIDATION_FILE"])
correlation_file = Path(os.environ["CORRELATION_FILE"])
localfile_export = Path("evidence/wazuh/scenario_d_attacks_localfile_export.ndjson")

corr_window = float(os.environ.get("CORRELATION_WINDOW_SECONDS", "120"))
lookback = int(float(os.environ.get("ZABBIX_HISTORY_LOOKBACK_SECONDS", "120")))
forward = int(float(os.environ.get("ZABBIX_HISTORY_FORWARD_SECONDS", "120")))

ZABBIX_URL=os.environ["ZABBIX_URL"]
ZABBIX_USER=os.environ["ZABBIX_USER"]
ZABBIX_PASSWORD=os.environ["ZABBIX_PASSWORD"]

def parse_ts(ts):
    if not ts:
        return None
    ts = ts.strip()
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

def fmt_ts(dt):
    if not dt:
        return ""
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def write_csv(path, rows, fields):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w=csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

def get(row, *names, default=""):
    for n in names:
        if n in row and row[n] not in ("", None):
            return row[n]
    return default

def api(method, params=None, auth=None):
    payload={"jsonrpc":"2.0","method":method,"params":params or {},"id":1}
    if auth:
        payload["auth"]=auth
    req=Request(ZABBIX_URL, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json"})
    with urlopen(req, timeout=20) as r:
        data=json.loads(r.read().decode())
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]

# Attack campaign map
attacks = read_csv(attack_file)
attack_by_uid={}
for r in attacks:
    uid=get(r,"attack_uid","execution_id")
    if not uid:
        continue
    start=parse_ts(get(r,"start_utc","timestamp_utc"))
    end=parse_ts(get(r,"end_utc"))
    aid=get(r,"attack_id","mitre_ics")
    attack_by_uid[uid]={
        "attack_uid":uid,
        "scenario":get(r,"scenario","scenario_id",default="SCENARIO_D"),
        "iteration":get(r,"iteration"),
        "attack_id":aid,
        "mitre_ics":get(r,"mitre_ics","technique_id",default=aid),
        "technique":get(r,"technique","event_type",default=aid),
        "target_component":get(r,"target_component","target"),
        "start_utc":fmt_ts(start),
        "end_utc":fmt_ts(end) if end else "",
        "start_dt":start,
        "end_dt":end
    }

campaign_uids=set(attack_by_uid)

# Wazuh events from localfile export, filtered by attack_uid
wazuh_rows=[]
if localfile_export.exists():
    for line in localfile_export.read_text(encoding="utf-8", errors="ignore").splitlines():
        line=line.strip()
        if not line:
            continue
        try:
            obj=json.loads(line)
        except Exception:
            continue
        lab=obj.get("iiot_lab", obj)
        uid=lab.get("attack_uid") or obj.get("attack_uid")
        if uid not in campaign_uids:
            continue
        meta=attack_by_uid[uid]
        ts=lab.get("timestamp_utc") or obj.get("timestamp") or meta["start_utc"]
        wazuh_rows.append({
            "timestamp_utc":ts,
            "scenario":lab.get("scenario", "SCENARIO_D"),
            "attack_uid":uid,
            "iteration":meta["iteration"],
            "attack_id":lab.get("attack_id", meta["attack_id"]),
            "mitre_ics":lab.get("technique_id", meta["mitre_ics"]),
            "component":lab.get("target", lab.get("component", meta["target_component"])),
            "event_type":lab.get("event_type", meta["technique"]),
            "severity":str(lab.get("severity","security")),
            "source":"wazuh_localfile_json",
            "rule_id":str(lab.get("rule_id","")),
            "rule_description":lab.get("rule_description","")
        })

# If no localfile rows matched, fall back to existing file filtered.
if not wazuh_rows and wazuh_file.exists():
    for r in read_csv(wazuh_file):
        uid=get(r,"attack_uid","execution_id")
        if uid in campaign_uids:
            wazuh_rows.append(r)

wazuh_fields=["timestamp_utc","scenario","attack_uid","iteration","attack_id","mitre_ics","component","event_type","severity","source","rule_id","rule_description"]
write_csv(wazuh_file, wazuh_rows, wazuh_fields)

# Zabbix API item discovery
auth=api("user.login", {"username":ZABBIX_USER, "password":ZABBIX_PASSWORD})
items=api("item.get", {
    "output":["itemid","name","key_","value_type","lastvalue","lastclock"],
    "selectHosts":["host"],
    "search":{"key_":"net.tcp.service"},
    "sortfield":"name"
}, auth)

lab_hosts={"mqtt-broker","health-app","telemetry-api","vulnerable-app"}
items_by_host=defaultdict(list)
for item in items:
    hosts=item.get("hosts",[])
    if not hosts:
        continue
    host=hosts[0].get("host","")
    if host in lab_hosts:
        items_by_host[host].append(item)

# Target-specific mapping; include health-app as global operational reference.
target_related = {
    "mosquitto": ["mqtt-broker","health-app"],
    "mqtt-broker": ["mqtt-broker","health-app"],
    "telemetry-api": ["telemetry-api","health-app"],
    "vulnerable-app": ["vulnerable-app","health-app"],
    "health-app": ["health-app"]
}

metrics_rows=[]
validation_rows=[]
corr_rows=[]

# Wazuh nearest event map
wazuh_by_uid=defaultdict(list)
for w in wazuh_rows:
    uid=get(w,"attack_uid")
    dt=parse_ts(get(w,"timestamp_utc"))
    if uid and dt:
        wazuh_by_uid[uid].append((dt,w))

for uid,meta in sorted(attack_by_uid.items(), key=lambda kv: (kv[1]["attack_id"], int(kv[1]["iteration"] or 0))):
    start=meta["start_dt"]
    if not start:
        continue
    time_from=int(start.timestamp())-lookback
    time_till=int(start.timestamp())+forward
    target=meta["target_component"]
    hosts=target_related.get(target,[target,"health-app"])

    candidate_samples=[]
    for host in hosts:
        for item in items_by_host.get(host,[]):
            itemid=item["itemid"]
            value_type=int(item.get("value_type","0"))
            hist=api("history.get", {
                "output":"extend",
                "history": value_type,
                "itemids":[itemid],
                "time_from": time_from,
                "time_till": time_till,
                "sortfield":"clock",
                "sortorder":"ASC",
                "limit": 200
            }, auth)
            for h in hist:
                clock=int(h["clock"])
                sample_dt=datetime.fromtimestamp(clock, tz=timezone.utc)
                delta=abs((sample_dt-start).total_seconds())
                val=h.get("value","")
                row={
                    "timestamp_utc":fmt_ts(sample_dt),
                    "scenario":"SCENARIO_D",
                    "attack_uid":uid,
                    "iteration":meta["iteration"],
                    "attack_id":meta["attack_id"],
                    "mitre_ics":meta["mitre_ics"],
                    "target_component":target,
                    "host":host,
                    "item":item.get("name",""),
                    "key":item.get("key_",""),
                    "itemid":itemid,
                    "value_type":value_type,
                    "history_clock":clock,
                    "history_utc":fmt_ts(sample_dt),
                    "history_value":val,
                    "sample_delta_s":round(delta,6),
                    "correlation_window_seconds":corr_window
                }
                metrics_rows.append(row)
                candidate_samples.append(row)

    # Nearest Zabbix sample
    nearest=None
    if candidate_samples:
        nearest=min(candidate_samples, key=lambda r: float(r["sample_delta_s"]))

    # Nearest Wazuh event
    nearest_wazuh=None
    if wazuh_by_uid.get(uid):
        nearest_wazuh=min(wazuh_by_uid[uid], key=lambda pair: abs((pair[0]-start).total_seconds()))

    z_delta=float(nearest["sample_delta_s"]) if nearest else None
    w_delta=abs((nearest_wazuh[0]-start).total_seconds()) if nearest_wazuh else None

    valid_z = z_delta is not None and z_delta <= corr_window
    valid_w = w_delta is not None and w_delta <= corr_window
    strong = valid_z and valid_w

    validation_rows.append({
        "scenario":"SCENARIO_D",
        "attack_uid":uid,
        "iteration":meta["iteration"],
        "attack_id":meta["attack_id"],
        "mitre_ics":meta["mitre_ics"],
        "target_component":target,
        "attack_start_utc":meta["start_utc"],
        "nearest_zabbix_sample_utc":nearest["history_utc"] if nearest else "",
        "nearest_zabbix_sample_delta_s":"" if z_delta is None else round(z_delta,6),
        "nearest_zabbix_host":nearest["host"] if nearest else "",
        "nearest_zabbix_itemid":nearest["itemid"] if nearest else "",
        "nearest_zabbix_item":nearest["item"] if nearest else "",
        "nearest_zabbix_value":nearest["history_value"] if nearest else "",
        "wazuh_event_utc":fmt_ts(nearest_wazuh[0]) if nearest_wazuh else "",
        "wazuh_event_delta_s":"" if w_delta is None else round(w_delta,6),
        "correlation_window_seconds":corr_window,
        "has_wazuh_event":"YES" if nearest_wazuh else "NO",
        "has_zabbix_sample":"YES" if nearest else "NO",
        "valid_temporal_correlation":"YES" if strong else "NO",
        "correlation_strength":"strong" if strong else ("partial" if (valid_z or valid_w) else "failed")
    })

    corr_rows.append({
        "scenario":"SCENARIO_D",
        "attack_uid":uid,
        "iteration":meta["iteration"],
        "attack_id":meta["attack_id"],
        "mitre_ics":meta["mitre_ics"],
        "technique":meta["technique"],
        "target_component":target,
        "start_utc":meta["start_utc"],
        "end_utc":meta["end_utc"],
        "wazuh_detected":"YES" if nearest_wazuh else "NO",
        "wazuh_event_utc":fmt_ts(nearest_wazuh[0]) if nearest_wazuh else "",
        "wazuh_event_delta_s":"" if w_delta is None else round(w_delta,6),
        "zabbix_real_sampled":"YES" if nearest else "NO",
        "nearest_zabbix_sample_utc":nearest["history_utc"] if nearest else "",
        "nearest_zabbix_sample_delta_s":"" if z_delta is None else round(z_delta,6),
        "nearest_zabbix_host":nearest["host"] if nearest else "",
        "nearest_zabbix_item":nearest["item"] if nearest else "",
        "nearest_zabbix_value":nearest["history_value"] if nearest else "",
        "correlation_window_seconds":corr_window,
        "strong_temporal_correlation":"YES" if strong else "NO",
        "correlation_strength":"strong" if strong else ("partial" if (valid_z or valid_w) else "failed")
    })

metric_fields=["timestamp_utc","scenario","attack_uid","iteration","attack_id","mitre_ics","target_component","host","item","key","itemid","value_type","history_clock","history_utc","history_value","sample_delta_s","correlation_window_seconds"]
validation_fields=["scenario","attack_uid","iteration","attack_id","mitre_ics","target_component","attack_start_utc","nearest_zabbix_sample_utc","nearest_zabbix_sample_delta_s","nearest_zabbix_host","nearest_zabbix_itemid","nearest_zabbix_item","nearest_zabbix_value","wazuh_event_utc","wazuh_event_delta_s","correlation_window_seconds","has_wazuh_event","has_zabbix_sample","valid_temporal_correlation","correlation_strength"]
corr_fields=["scenario","attack_uid","iteration","attack_id","mitre_ics","technique","target_component","start_utc","end_utc","wazuh_detected","wazuh_event_utc","wazuh_event_delta_s","zabbix_real_sampled","nearest_zabbix_sample_utc","nearest_zabbix_sample_delta_s","nearest_zabbix_host","nearest_zabbix_item","nearest_zabbix_value","correlation_window_seconds","strong_temporal_correlation","correlation_strength"]

write_csv(zabbix_metrics_file, metrics_rows, metric_fields)
write_csv(zabbix_validation_file, validation_rows, validation_fields)
write_csv(correlation_file, corr_rows, corr_fields)

# Ensure no missing per-UID deltas for final campaign
missing=[r["attack_uid"] for r in validation_rows if r["nearest_zabbix_sample_delta_s"]==""]
if missing:
    raise RuntimeError(f"Missing nearest_zabbix_sample_delta_s for attack_uids: {missing[:10]}")

print(json.dumps({
    "attacks":len(attacks),
    "wazuh_events_filtered":len(wazuh_rows),
    "zabbix_metric_samples":len(metrics_rows),
    "validation_rows":len(validation_rows),
    "correlation_rows":len(corr_rows),
    "correlation_file":str(correlation_file),
    "zabbix_validation_file":str(zabbix_validation_file)
}, indent=2))
PY

phase "4/4" "Validar salidas con deltas por ejecución." "Validate outputs with per-execution deltas."

for f in "$WAZUH_FILE" "$ZABBIX_METRICS_FILE" "$ZABBIX_VALIDATION_FILE" "$CORRELATION_FILE"; do
  [[ -s "$f" ]] || fail "Archivo ausente o vacío: $f" "Missing or empty file: $f"
  ok "Generado: $f" "Generated: $f"
done

python3 - <<'PY'
import csv
from pathlib import Path
p=Path("results/raw/scenario_d/zabbix_history_validation.csv")
rows=list(csv.DictReader(p.open(encoding="utf-8")))
missing=[r for r in rows if not r.get("nearest_zabbix_sample_delta_s")]
if missing:
    raise SystemExit("Missing nearest_zabbix_sample_delta_s in validation file")
print(f"[OK] Per-execution Zabbix deltas available: {len(rows)}")
PY

line
echo "[SUMMARY] Scenario D Correlation Experiment v1.1"
line
ok "Correlation dataset regenerated with per-attack_uid temporal deltas" "Correlation dataset regenerated with per-attack_uid temporal deltas"
ok "zabbix_history_validation.csv now includes nearest_zabbix_sample_delta_s" "zabbix_history_validation.csv now includes nearest_zabbix_sample_delta_s"
