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

script_start "22-run-statistical-analysis.sh" \
  "Ejecutar análisis estadístico robusto con deltas temporales disponibles." \
  "Run robust statistical analysis with available temporal deltas."

RESULTS_DIR="${RESULTS_DIR:-results}"
TABLES_DIR="$RESULTS_DIR/tables"
PROCESSED_DIR="$RESULTS_DIR/processed"
mkdir -p "$TABLES_DIR" "$PROCESSED_DIR"

phase "1/4" "Validar entradas estadísticas." "Validate statistical inputs."

[[ -f "$TABLES_DIR/table_attack_detection.csv" ]] || fail "No existe table_attack_detection.csv." "table_attack_detection.csv does not exist."
[[ -f "$TABLES_DIR/table_sla_impact.csv" ]] || fail "No existe table_sla_impact.csv." "table_sla_impact.csv does not exist."
[[ -f "$PROCESSED_DIR/temporal_correlation_analysis.csv" ]] || fail "No existe temporal_correlation_analysis.csv. Ejecutar script 21 primero." "temporal_correlation_analysis.csv does not exist. Run script 21 first."

phase "2/4" "Calcular Wilson, bootstrap, percentiles y delta temporal." "Calculate Wilson, bootstrap, percentiles, and temporal delta."

python3 - <<'PY'
import csv, math, random, statistics, os
from pathlib import Path
from collections import defaultdict

tables=Path(os.environ.get("TABLES_DIR","results/tables"))
processed=Path(os.environ.get("PROCESSED_DIR","results/processed"))

def read_csv(p):
    if not Path(p).exists():
        return []
    with Path(p).open(newline="",encoding="utf-8") as f:
        return list(csv.DictReader(f))

def fnum(x, default=0.0):
    try: return float(x)
    except Exception: return default

def wilson(k,n,z=1.96):
    if n==0: return (0.0,0.0)
    phat=k/n
    denom=1+z*z/n
    center=(phat+z*z/(2*n))/denom
    half=z*math.sqrt((phat*(1-phat)+z*z/(4*n))/n)/denom
    return max(0,center-half), min(1,center+half)

def pct(vals,p):
    vals=sorted(vals)
    if not vals: return ""
    k=(len(vals)-1)*p/100
    lo=math.floor(k); hi=math.ceil(k)
    if lo==hi: return vals[int(k)]
    return vals[lo]*(hi-k)+vals[hi]*(k-lo)

def boot(vals,reps=5000):
    vals=[float(v) for v in vals]
    if not vals: return ("","")
    if len(vals)==1: return (vals[0],vals[0])
    rng=random.Random(42)
    means=[statistics.mean([rng.choice(vals) for _ in vals]) for _ in range(reps)]
    return pct(means,2.5), pct(means,97.5)

# Detection Wilson
det=read_csv(tables/"table_attack_detection.csv")
det_out=[]
for r in det:
    n=int(fnum(r.get("executions"))); k=int(fnum(r.get("wazuh_detected")))
    lo,hi=wilson(k,n)
    det_out.append({"scenario":r.get("scenario","SCENARIO_D"),"attack_id":r.get("attack_id",""),"executions":n,"detections":k,"detection_rate_percent":round(k*100/n,2) if n else 0,"wilson_ci95_low_percent":round(lo*100,2),"wilson_ci95_high_percent":round(hi*100,2)})
with (tables/"table_detection_wilson_ci.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(det_out[0].keys())); w.writeheader(); w.writerows(det_out)

# SLA Wilson
sla=read_csv(tables/"table_sla_impact.csv")
sla_out=[]
for r in sla:
    n=int(fnum(r.get("executions")))
    k=int(fnum(r.get("http_error_observed_count", r.get("zabbix_operational_degradation_count",0))))
    lo,hi=wilson(k,n)
    sla_out.append({"scenario":r.get("scenario","SCENARIO_D"),"attack_id":r.get("attack_id",""),"executions":n,"http_or_operational_impact_count":k,"impact_rate_percent":round(k*100/n,2) if n else 0,"wilson_ci95_low_percent":round(lo*100,2),"wilson_ci95_high_percent":round(hi*100,2)})
with (tables/"table_sla_wilson_ci.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(sla_out[0].keys())); w.writeheader(); w.writerows(sla_out)

# Temporal delta distribution
by=defaultdict(list)
for r in read_csv(processed/"temporal_correlation_analysis.csv"):
    val=r.get("temporal_delta_seconds","")
    if val == "": 
        continue
    by[r.get("attack_id","unknown")].append(abs(float(val)))

lat=[]
for aid,vals in sorted(by.items()):
    lo,hi=boot(vals)
    lat.append({
        "scenario":"SCENARIO_D",
        "attack_id":aid,
        "samples":len(vals),
        "mean_seconds":round(statistics.mean(vals),6),
        "median_seconds":round(statistics.median(vals),6),
        "stddev_seconds":round(statistics.stdev(vals),6) if len(vals)>1 else 0,
        "p50_seconds":round(pct(vals,50),6),
        "p95_seconds":round(pct(vals,95),6),
        "p99_seconds":round(pct(vals,99),6),
        "bootstrap_ci95_mean_low_seconds":round(lo,6) if lo!="" else "",
        "bootstrap_ci95_mean_high_seconds":round(hi,6) if hi!="" else ""
    })

if not lat:
    # Create explicit no-data outputs instead of crashing.
    lat=[{
        "scenario":"SCENARIO_D",
        "attack_id":"NO_TEMPORAL_DELTA_AVAILABLE",
        "samples":0,
        "mean_seconds":"",
        "median_seconds":"",
        "stddev_seconds":"",
        "p50_seconds":"",
        "p95_seconds":"",
        "p99_seconds":"",
        "bootstrap_ci95_mean_low_seconds":"",
        "bootstrap_ci95_mean_high_seconds":""
    }]

with (tables/"table_latency_distribution.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(lat[0].keys())); w.writeheader(); w.writerows(lat)

bootrows=[]
for r in lat:
    bootrows.append({"scenario":r["scenario"],"attack_id":r["attack_id"],"metric":"temporal_delta_mean_seconds","samples":r["samples"],"mean":r["mean_seconds"],"bootstrap_ci95_low":r["bootstrap_ci95_mean_low_seconds"],"bootstrap_ci95_high":r["bootstrap_ci95_mean_high_seconds"]})
with (tables/"table_bootstrap_ci.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(bootrows[0].keys())); w.writeheader(); w.writerows(bootrows)

mttd=[]
for r in lat:
    mttd.append({"scenario":r["scenario"],"attack_id":r["attack_id"],"metric_name":"event_based_detection_registration_delta_seconds","note":"This is event-based temporal delta, not full production MTTD.","samples":r["samples"],"mean_seconds":r["mean_seconds"],"p95_seconds":r["p95_seconds"],"p99_seconds":r["p99_seconds"]})
with (tables/"table_mttd_estimation.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(mttd[0].keys())); w.writeheader(); w.writerows(mttd)

print("Statistical analysis complete.")
PY

phase "3/4" "Validar salidas estadísticas." "Validate statistical outputs."

for f in \
  "$TABLES_DIR/table_detection_wilson_ci.csv" \
  "$TABLES_DIR/table_sla_wilson_ci.csv" \
  "$TABLES_DIR/table_latency_distribution.csv" \
  "$TABLES_DIR/table_bootstrap_ci.csv" \
  "$TABLES_DIR/table_mttd_estimation.csv"
do
  [[ -s "$f" ]] || fail "Archivo estadístico ausente o vacío: $f" "Missing or empty statistical file: $f"
  ok "Generado: $f" "Generated: $f"
done

phase "4/4" "Resumen." "Summary."

line
echo "[SUMMARY] Statistical Analysis v1.2"
line
ok "Wilson intervals generados" "Wilson intervals generated"
ok "Bootstrap CI robusto generado" "Robust bootstrap CI generated"
ok "Percentiles p50/p95/p99 generados cuando existen deltas temporales" "p50/p95/p99 generated when temporal deltas exist"
