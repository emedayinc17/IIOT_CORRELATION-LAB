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

script_start "19-normalize-experimental-datasets.sh" \
  "Normalizar datasets experimentales con filtrado por campaña final." \
  "Normalize experimental datasets with final campaign filtering."

OUT_DIR="${OUT_DIR:-results/processed/normalized}"
RAW_D_DIR="${RAW_D_DIR:-results/raw/scenario_d}"
PROCESSED_DIR="${PROCESSED_DIR:-results/processed}"
mkdir -p "$OUT_DIR"

phase "1/4" "Validar entradas de campaña final." "Validate final campaign inputs."

[[ -f "$RAW_D_DIR/mitre_ics_attacks.csv" ]] || fail \
  "No existe $RAW_D_DIR/mitre_ics_attacks.csv." \
  "$RAW_D_DIR/mitre_ics_attacks.csv does not exist."

[[ -f "$RAW_D_DIR/wazuh_security_events.csv" ]] || fail \
  "No existe $RAW_D_DIR/wazuh_security_events.csv." \
  "$RAW_D_DIR/wazuh_security_events.csv does not exist."

[[ -f "$RAW_D_DIR/zabbix_correlation_metrics.csv" ]] || fail \
  "No existe $RAW_D_DIR/zabbix_correlation_metrics.csv." \
  "$RAW_D_DIR/zabbix_correlation_metrics.csv does not exist."

[[ -f "$PROCESSED_DIR/correlation_dataset.csv" ]] || fail \
  "No existe $PROCESSED_DIR/correlation_dataset.csv." \
  "$PROCESSED_DIR/correlation_dataset.csv does not exist."

phase "2/4" "Normalizar datasets con attack_uid como llave de campaña." "Normalize datasets using attack_uid as campaign key."

python3 - <<'PY'
import csv, json, hashlib, os, re
from pathlib import Path
from datetime import datetime, timezone

out_dir = Path(os.environ.get("OUT_DIR", "results/processed/normalized"))
raw_d = Path(os.environ.get("RAW_D_DIR", "results/raw/scenario_d"))
processed = Path(os.environ.get("PROCESSED_DIR", "results/processed"))
out_dir.mkdir(parents=True, exist_ok=True)

schema_fields = [
    "timestamp_utc",
    "scenario_id",
    "execution_id",
    "iteration",
    "attack_id",
    "technique_id",
    "source",
    "target",
    "event_type",
    "severity",
    "metric_name",
    "metric_value",
    "unit",
    "zabbix_itemid",
    "zabbix_event_id",
    "wazuh_alert_id",
    "correlation_window_seconds",
    "dataset_source",
    "raw_file",
    "raw_row_hash"
]

required = ["timestamp_utc","scenario_id","attack_id","technique_id","source","target","severity","metric_name","metric_value"]

schema = {
    "schema_name": "iiot_correlation_normalized_schema",
    "schema_version": "1.1",
    "generated_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "required_fields": required,
    "fields": schema_fields,
    "campaign_filter": "Only rows with attack_uid present in mitre_ics_attacks.csv are included for Scenario D final campaign.",
    "methodological_note": "Correlation is event-based temporal correlation within a predefined window, not Pearson/Spearman statistical correlation."
}
(out_dir / "dataset_schema.json").write_text(json.dumps(schema, indent=2, ensure_ascii=False), encoding="utf-8")

def read_csv(path):
    with Path(path).open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def h(row):
    return hashlib.sha256(json.dumps(row, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]

def get(row,*names,default=""):
    for n in names:
        if n in row and row[n] not in ("", None):
            return row[n]
    return default

def first_nonempty(*vals):
    for v in vals:
        if v not in ("", None):
            return v
    return ""

def parse_iteration(uid):
    m = re.search(r'-(\d+)$', uid or "")
    return m.group(1) if m else ""

attacks = read_csv(raw_d / "mitre_ics_attacks.csv")
attack_by_uid = {}
for r in attacks:
    uid = get(r, "attack_uid", "execution_id")
    if not uid:
        continue
    attack_by_uid[uid] = {
        "scenario": get(r, "scenario", "scenario_id", default="SCENARIO_D"),
        "iteration": get(r, "iteration", default=parse_iteration(uid)),
        "attack_id": get(r, "attack_id", "mitre_ics"),
        "technique_id": get(r, "mitre_ics", "technique_id", "attack_id"),
        "target": get(r, "target_component", "target"),
        "start_utc": get(r, "start_utc", "timestamp_utc"),
        "end_utc": get(r, "end_utc"),
        "technique": get(r, "technique", "event_type")
    }

campaign_uids = set(attack_by_uid.keys())

events = []
metrics = []
corrs = []
excluded_wazuh = 0

# Attack execution events
for row in attacks:
    uid = get(row, "attack_uid", "execution_id")
    meta = attack_by_uid.get(uid, {})
    aid = meta.get("attack_id", get(row, "attack_id", "mitre_ics"))
    events.append({
        "timestamp_utc": meta.get("start_utc", get(row, "timestamp_utc")),
        "scenario_id": meta.get("scenario","SCENARIO_D"),
        "execution_id": uid,
        "iteration": meta.get("iteration", ""),
        "attack_id": aid,
        "technique_id": meta.get("technique_id", aid),
        "source": "attack_script",
        "target": meta.get("target", get(row,"target")),
        "event_type": "attack_execution",
        "severity": "controlled",
        "metric_name": "attack_execution",
        "metric_value": "1",
        "unit": "event",
        "correlation_window_seconds": get(row, "correlation_window_seconds"),
        "dataset_source": "mitre_ics_attacks",
        "raw_file": str(raw_d / "mitre_ics_attacks.csv"),
        "raw_row_hash": h(row)
    })

# Wazuh events filtered by final campaign attack_uid
for row in read_csv(raw_d / "wazuh_security_events.csv"):
    uid = get(row, "attack_uid", "execution_id")
    if uid not in campaign_uids:
        excluded_wazuh += 1
        continue
    meta = attack_by_uid[uid]
    aid = meta["attack_id"]
    events.append({
        "timestamp_utc": get(row, "timestamp_utc", "timestamp", default=meta["start_utc"]),
        "scenario_id": get(row, "scenario", "scenario_id", default=meta["scenario"]),
        "execution_id": uid,
        "iteration": meta["iteration"],
        "attack_id": aid,
        "technique_id": get(row, "mitre_ics", "technique_id", default=meta["technique_id"]),
        "source": get(row, "source", default="wazuh_localfile_json"),
        "target": get(row, "component", "target", default=meta["target"]),
        "event_type": get(row, "event_type", default="security_event"),
        "severity": get(row, "severity", default="security"),
        "metric_name": "wazuh_detection_event",
        "metric_value": "1",
        "unit": "event",
        "wazuh_alert_id": get(row, "wazuh_alert_id", "rule_id"),
        "correlation_window_seconds": get(row, "correlation_window_seconds"),
        "dataset_source": "wazuh_security_events",
        "raw_file": str(raw_d / "wazuh_security_events.csv"),
        "raw_row_hash": h(row)
    })

# Optional: zabbix validation map for timestamps if available
validation_by_uid = {}
val_path = raw_d / "zabbix_history_validation.csv"
if val_path.exists():
    for r in read_csv(val_path):
        uid = get(r, "attack_uid", "execution_id")
        if uid:
            validation_by_uid.setdefault(uid, r)

# Zabbix metrics filtered/enriched by attack_uid
for row in read_csv(raw_d / "zabbix_correlation_metrics.csv"):
    uid = get(row, "attack_uid", "execution_id")
    if uid not in campaign_uids:
        continue
    meta = attack_by_uid[uid]
    val = validation_by_uid.get(uid, {})
    ts = first_nonempty(
        get(row, "history_utc", "timestamp_utc", "last_clock_utc"),
        get(val, "nearest_zabbix_sample_utc", "history_utc", "timestamp_utc"),
        meta["start_utc"]
    )
    metric_value = first_nonempty(
        get(row, "avg_value", "history_value", "last_value", "metric_value", "value"),
        "0"
    )
    metric_name = get(row, "item", "key", "metric_name", default="zabbix_metric")
    metrics.append({
        "timestamp_utc": ts,
        "scenario_id": get(row, "scenario", "scenario_id", default=meta["scenario"]),
        "execution_id": uid,
        "iteration": meta["iteration"],
        "attack_id": meta["attack_id"],
        "technique_id": meta["technique_id"],
        "source": "zabbix_history_get",
        "target": get(row, "host", "target", default=meta["target"]),
        "event_type": "operational_metric",
        "severity": "operational",
        "metric_name": metric_name,
        "metric_value": metric_value,
        "unit": get(row, "unit"),
        "zabbix_itemid": get(row, "itemid"),
        "correlation_window_seconds": get(row, "correlation_window_seconds"),
        "dataset_source": "zabbix_correlation_metrics",
        "raw_file": str(raw_d / "zabbix_correlation_metrics.csv"),
        "raw_row_hash": h(row)
    })

# Correlation rows
for row in read_csv(processed / "correlation_dataset.csv"):
    uid = get(row, "attack_uid", "execution_id")
    if uid not in campaign_uids:
        continue
    meta = attack_by_uid[uid]
    delta = first_nonempty(
        get(row, "nearest_zabbix_sample_delta_s", "zabbix_sample_delta_s", "temporal_delta_seconds"),
        get(row, "avg_nearest_zabbix_sample_delta_s"),
        get(row, "http_latency_delta_s")
    )
    corrs.append({
        "timestamp_utc": get(row, "start_utc", "timestamp_utc", default=meta["start_utc"]),
        "scenario_id": get(row, "scenario", "scenario_id", default=meta["scenario"]),
        "execution_id": uid,
        "iteration": meta["iteration"],
        "attack_id": meta["attack_id"],
        "technique_id": meta["technique_id"],
        "source": "correlation_pipeline",
        "target": get(row, "target_component", "target", default=meta["target"]),
        "event_type": get(row, "correlation_strength", default="temporal_correlation"),
        "severity": get(row, "correlation_strength", default="not_classified"),
        "metric_name": "temporal_delta_seconds",
        "metric_value": delta,
        "unit": "seconds",
        "correlation_window_seconds": get(row, "correlation_window_seconds", default="120"),
        "dataset_source": "correlation_dataset",
        "raw_file": str(processed / "correlation_dataset.csv"),
        "raw_row_hash": h(row)
    })

def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=schema_fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in schema_fields})

write_csv(out_dir / "events_normalized.csv", events)
write_csv(out_dir / "metrics_normalized.csv", metrics)
write_csv(out_dir / "correlation_normalized.csv", corrs)

def missing_required(rows):
    bad = 0
    for r in rows:
        if any(str(r.get(k,"")).strip()=="" for k in required):
            bad += 1
    return bad

summary = {
    "generated_utc": schema["generated_utc"],
    "campaign_attack_uids": len(campaign_uids),
    "events_normalized_rows": len(events),
    "metrics_normalized_rows": len(metrics),
    "correlation_normalized_rows": len(corrs),
    "excluded_wazuh_events_not_in_final_campaign": excluded_wazuh,
    "events_missing_required_fields": missing_required(events),
    "metrics_missing_required_fields": missing_required(metrics),
    "correlation_missing_required_fields": missing_required(corrs),
    "schema_file": str(out_dir / "dataset_schema.json")
}
(out_dir / "normalization_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))

if summary["metrics_missing_required_fields"] > 0:
    raise SystemExit("metrics_normalized still has missing required fields")
if summary["correlation_missing_required_fields"] > 0:
    raise SystemExit("correlation_normalized still has missing required fields")
PY

phase "3/4" "Validar datasets normalizados." "Validate normalized datasets."

for f in \
  "$OUT_DIR/events_normalized.csv" \
  "$OUT_DIR/metrics_normalized.csv" \
  "$OUT_DIR/correlation_normalized.csv" \
  "$OUT_DIR/dataset_schema.json" \
  "$OUT_DIR/normalization_summary.json"
do
  [[ -s "$f" ]] || fail "Archivo vacío o ausente: $f" "Empty or missing file: $f"
  ok "Generado: $f" "Generated: $f"
done

phase "4/4" "Resumen." "Summary."

line
echo "[SUMMARY] Dataset Normalization v1.1"
line
ok "Datasets normalizados filtrados por campaña final" "Normalized datasets filtered by final campaign"
ok "Eventos Wazuh fuera de la campaña excluidos y registrados en normalization_summary.json" "Out-of-campaign Wazuh events excluded and recorded in normalization_summary.json"
ok "Campos requeridos completados para métricas y correlaciones" "Required fields completed for metrics and correlations"
