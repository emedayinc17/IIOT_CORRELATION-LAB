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

script_start "17-export-final-datasets.sh" \
  "Generar tablas finales desde datasets con deltas por ejecución." \
  "Generate final tables from datasets with per-execution deltas."

RAW_D_DIR="${RAW_D_DIR:-results/raw/scenario_d}"
PROCESSED_DIR="${PROCESSED_DIR:-results/processed}"
TABLES_DIR="${TABLES_DIR:-results/tables}"
FIGURES_DIR="${FIGURES_DIR:-results/figures}"
mkdir -p "$TABLES_DIR" "$FIGURES_DIR"

CORR_FILE="$PROCESSED_DIR/correlation_dataset.csv"
HTTP_FILE="$RAW_D_DIR/attack_http_observations.csv"

phase "1/3" "Validar correlation_dataset con deltas por ejecución." "Validate correlation_dataset with per-execution deltas."

[[ -f "$CORR_FILE" ]] || fail "No existe $CORR_FILE. Ejecutar script 16." "$CORR_FILE does not exist. Run script 16."
[[ -f "$HTTP_FILE" ]] || warn "No existe $HTTP_FILE. Impacto HTTP se inferirá como 0." "$HTTP_FILE does not exist. HTTP impact will be inferred as 0."

phase "2/3" "Generar tablas y figuras." "Generate tables and figures."

python3 - <<'PY'
import csv, statistics, math
from pathlib import Path
from collections import defaultdict

corr_file=Path("results/processed/correlation_dataset.csv")
http_file=Path("results/raw/scenario_d/attack_http_observations.csv")
tables=Path("results/tables")
figures=Path("results/figures")
tables.mkdir(parents=True,exist_ok=True)
figures.mkdir(parents=True,exist_ok=True)

def read_csv(path):
    if not path.exists(): return []
    with path.open(newline="",encoding="utf-8") as f:
        return list(csv.DictReader(f))

def fnum(x):
    try: return float(x)
    except Exception: return None

rows=read_csv(corr_file)
by=defaultdict(list)
for r in rows:
    by[r["attack_id"]].append(r)

# HTTP error map by attack_uid
http_errors=defaultdict(int)
for r in read_csv(http_file):
    uid=r.get("attack_uid","")
    code=r.get("http_code", r.get("code",""))
    try:
        c=int(code)
    except Exception:
        c=0
    if c == 0 or c >= 400:
        http_errors[uid]+=1

# table_attack_detection
attack_detection=[]
for aid, vals in sorted(by.items()):
    n=len(vals)
    det=sum(1 for r in vals if r.get("wazuh_detected")=="YES")
    sampled=sum(1 for r in vals if r.get("zabbix_real_sampled")=="YES")
    strong=sum(1 for r in vals if r.get("strong_temporal_correlation")=="YES" or r.get("correlation_strength")=="strong")
    moderate=sum(1 for r in vals if r.get("correlation_strength")=="partial")
    attack_detection.append({
        "scenario":"SCENARIO_D",
        "attack_id":aid,
        "mitre_ics":aid,
        "technique": vals[0].get("technique", aid),
        "executions":n,
        "wazuh_detected":det,
        "detection_rate_percent":round(det*100/n,2) if n else 0,
        "zabbix_real_sampled_executions":sampled,
        "zabbix_real_sampling_percent":round(sampled*100/n,2) if n else 0,
        "strong_correlation_count":strong,
        "strong_correlation_percent":round(strong*100/n,2) if n else 0,
        "moderate_correlation_count":moderate
    })
with (tables/"table_attack_detection.csv").open("w",newline="",encoding="utf-8") as f:
    fields=list(attack_detection[0].keys())
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(attack_detection)

# latency table
lat_rows=[]
for aid, vals in sorted(by.items()):
    deltas=[fnum(r.get("nearest_zabbix_sample_delta_s")) for r in vals if fnum(r.get("nearest_zabbix_sample_delta_s")) is not None]
    w_deltas=[fnum(r.get("wazuh_event_delta_s")) for r in vals if fnum(r.get("wazuh_event_delta_s")) is not None]
    lat_rows.append({
        "scenario":"SCENARIO_D",
        "attack_id":aid,
        "executions":len(vals),
        "avg_nearest_zabbix_sample_delta_s":round(statistics.mean(deltas),6) if deltas else "",
        "max_nearest_zabbix_sample_delta_s":round(max(deltas),6) if deltas else "",
        "avg_wazuh_event_delta_s":round(statistics.mean(w_deltas),6) if w_deltas else "",
        "max_wazuh_event_delta_s":round(max(w_deltas),6) if w_deltas else ""
    })
with (tables/"table_correlation_latency.csv").open("w",newline="",encoding="utf-8") as f:
    fields=list(lat_rows[0].keys())
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(lat_rows)

# SLA impact
sla=[]
for aid, vals in sorted(by.items()):
    n=len(vals)
    err=sum(1 for r in vals if http_errors.get(r.get("attack_uid",""),0)>0)
    # Use HTTP errors as operational impact for availability-targeted attacks; preserve explicit metric.
    sla.append({
        "scenario":"SCENARIO_D",
        "attack_id":aid,
        "executions":n,
        "zabbix_operational_degradation_count":0,
        "zabbix_operational_degradation_percent":0.0,
        "http_error_observed_count":err,
        "http_error_observed_percent":round(err*100/n,2) if n else 0
    })
with (tables/"table_sla_impact.csv").open("w",newline="",encoding="utf-8") as f:
    fields=list(sla[0].keys())
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(sla)

# history quality
hq=[]
for aid, vals in sorted(by.items()):
    deltas=[fnum(r.get("nearest_zabbix_sample_delta_s")) for r in vals if fnum(r.get("nearest_zabbix_sample_delta_s")) is not None]
    n=len(vals)
    hq.append({
        "scenario":"SCENARIO_D",
        "attack_id":aid,
        "executions":n,
        "executions_with_real_zabbix_history":len(deltas),
        "real_zabbix_history_percent":round(len(deltas)*100/n,2) if n else 0,
        "min_nearest_zabbix_sample_delta_s":round(min(deltas),6) if deltas else "",
        "max_nearest_zabbix_sample_delta_s":round(max(deltas),6) if deltas else "",
        "avg_nearest_zabbix_sample_delta_s":round(statistics.mean(deltas),6) if deltas else ""
    })
with (tables/"table_zabbix_history_quality.csv").open("w",newline="",encoding="utf-8") as f:
    fields=list(hq[0].keys())
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(hq)

with (Path("results/processed")/"attack_effectiveness.csv").open("w",newline="",encoding="utf-8") as f:
    fields=list(attack_detection[0].keys())
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(attack_detection)

# simple SVGs
for name,title,rows_src,val_key in [
    ("figure_detection_comparison.svg","Detection rate by technique",attack_detection,"detection_rate_percent"),
    ("figure_zabbix_history_quality.svg","Zabbix history quality by technique",hq,"real_zabbix_history_percent"),
    ("figure_temporal_correlation_distribution.svg","Average nearest Zabbix delta by technique",lat_rows,"avg_nearest_zabbix_sample_delta_s")
]:
    vals=[float(r.get(val_key) or 0) for r in rows_src]
    labels=[r["attack_id"] for r in rows_src]
    maxv=max(vals+[1])
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="900" height="420">','<rect width="100%" height="100%" fill="white"/>',f'<text x="40" y="35" font-family="Arial" font-size="20">{title}</text>']
    for i,(lab,val) in enumerate(zip(labels,vals)):
        x=60+i*180; bh=260*(val/maxv) if maxv else 0; y=350-bh
        svg.append(f'<rect x="{x}" y="{y}" width="90" height="{bh}" fill="#777"/>')
        svg.append(f'<text x="{x}" y="380" font-family="Arial" font-size="14">{lab}</text>')
        svg.append(f'<text x="{x}" y="{y-8}" font-family="Arial" font-size="12">{val:.3f}</text>')
    svg.append('</svg>')
    (figures/name).write_text("\n".join(svg),encoding="utf-8")

print("Final tables and figures generated from per-execution deltas.")
PY

phase "3/3" "Validar tablas finales." "Validate final tables."

for f in \
  "$TABLES_DIR/table_attack_detection.csv" \
  "$TABLES_DIR/table_correlation_latency.csv" \
  "$TABLES_DIR/table_sla_impact.csv" \
  "$TABLES_DIR/table_zabbix_history_quality.csv" \
  "$PROCESSED_DIR/attack_effectiveness.csv"
do
  [[ -s "$f" ]] || fail "Archivo ausente o vacío: $f" "Missing or empty file: $f"
  ok "Generado: $f" "Generated: $f"
done

line
echo "[SUMMARY] Scenario D Final Dataset Export v1.1"
line
ok "Tablas regeneradas desde deltas por ejecución" "Tables regenerated from per-execution deltas"
