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

script_start "21-analyze-temporal-correlation.sh" \
  "Analizar correlación temporal usando deltas reales disponibles." \
  "Analyze temporal correlation using available real deltas."

CORR_FILE="${CORR_FILE:-results/processed/correlation_dataset.csv}"
ATTACK_FILE="${ATTACK_FILE:-results/raw/scenario_d/mitre_ics_attacks.csv}"
ZABBIX_VALIDATION_FILE="${ZABBIX_VALIDATION_FILE:-results/raw/scenario_d/zabbix_history_validation.csv}"
AGG_LATENCY_FILE="${AGG_LATENCY_FILE:-results/tables/table_correlation_latency.csv}"
OUT_TABLE="${OUT_TABLE:-results/tables/table_temporal_correlation_summary.csv}"
OUT_DETAIL="${OUT_DETAIL:-results/processed/temporal_correlation_analysis.csv}"
OUT_FIG="${OUT_FIG:-results/figures/figure_temporal_correlation_distribution.svg}"
mkdir -p "$(dirname "$OUT_TABLE")" "$(dirname "$OUT_DETAIL")" "$(dirname "$OUT_FIG")"

phase "1/3" "Validar datasets." "Validate datasets."

[[ -f "$CORR_FILE" ]] || fail "No existe $CORR_FILE." "$CORR_FILE does not exist."
[[ -f "$ATTACK_FILE" ]] || fail "No existe $ATTACK_FILE." "$ATTACK_FILE does not exist."

phase "2/3" "Calcular deltas temporales desde fuentes disponibles." "Calculate temporal deltas from available sources."

python3 - <<'PY'
import csv, statistics, math, os, json
from pathlib import Path
from collections import defaultdict

corr_file=Path(os.environ.get("CORR_FILE","results/processed/correlation_dataset.csv"))
attack_file=Path(os.environ.get("ATTACK_FILE","results/raw/scenario_d/mitre_ics_attacks.csv"))
validation_file=Path(os.environ.get("ZABBIX_VALIDATION_FILE","results/raw/scenario_d/zabbix_history_validation.csv"))
agg_latency_file=Path(os.environ.get("AGG_LATENCY_FILE","results/tables/table_correlation_latency.csv"))
out_table=Path(os.environ.get("OUT_TABLE","results/tables/table_temporal_correlation_summary.csv"))
out_detail=Path(os.environ.get("OUT_DETAIL","results/processed/temporal_correlation_analysis.csv"))
out_fig=Path(os.environ.get("OUT_FIG","results/figures/figure_temporal_correlation_distribution.svg"))
diag_file=Path("results/processed/temporal_correlation_diagnostics.json")

def read_csv(path):
    if not Path(path).exists():
        return []
    with Path(path).open(newline="",encoding="utf-8") as f:
        return list(csv.DictReader(f))

def get(row,*names,default=""):
    for n in names:
        if n in row and row[n] not in ("",None):
            return row[n]
    return default

def fnum(v):
    try:
        if v in ("", None): return None
        return float(v)
    except Exception:
        return None

def pct(vals,p):
    vals=sorted(vals)
    if not vals: return ""
    k=(len(vals)-1)*p/100
    lo=math.floor(k); hi=math.ceil(k)
    if lo==hi: return vals[int(k)]
    return vals[lo]*(hi-k)+vals[hi]*(k-lo)

attacks=read_csv(attack_file)
campaign={}
for r in attacks:
    uid=get(r,"attack_uid","execution_id")
    if uid:
        campaign[uid]={
            "scenario":get(r,"scenario","scenario_id",default="SCENARIO_D"),
            "iteration":get(r,"iteration"),
            "attack_id":get(r,"attack_id","mitre_ics"),
            "technique_id":get(r,"mitre_ics","technique_id","attack_id"),
            "target":get(r,"target_component","target"),
            "start_utc":get(r,"start_utc","timestamp_utc")
        }

# Per-UID delta map from zabbix_history_validation when available.
delta_by_uid={}
source_by_uid={}
for r in read_csv(validation_file):
    uid=get(r,"attack_uid","execution_id")
    if not uid: 
        continue
    # Try common field names first.
    delta = None
    for field in [
        "nearest_zabbix_sample_delta_s",
        "zabbix_sample_delta_s",
        "temporal_delta_seconds",
        "nearest_sample_delta_s",
        "delta_seconds",
        "avg_nearest_zabbix_sample_delta_s"
    ]:
        delta=fnum(get(r,field))
        if delta is not None:
            break
    if delta is not None:
        delta_by_uid[uid]=abs(delta)
        source_by_uid[uid]="zabbix_history_validation"

# Per-UID delta from correlation_dataset.
corr_rows=read_csv(corr_file)
for r in corr_rows:
    uid=get(r,"attack_uid","execution_id")
    if not uid or uid in delta_by_uid:
        continue
    delta=None
    for field in [
        "nearest_zabbix_sample_delta_s",
        "zabbix_sample_delta_s",
        "temporal_delta_seconds",
        "avg_nearest_zabbix_sample_delta_s"
    ]:
        delta=fnum(get(r,field))
        if delta is not None:
            break
    if delta is not None:
        delta_by_uid[uid]=abs(delta)
        source_by_uid[uid]="correlation_dataset"

# Aggregate fallback by attack_id if per-UID deltas are unavailable.
agg_by_attack={}
for r in read_csv(agg_latency_file):
    aid=get(r,"attack_id")
    val=fnum(get(r,"avg_nearest_zabbix_sample_delta_s"))
    if aid and val is not None:
        agg_by_attack[aid]=abs(val)

details=[]
by_attack=defaultdict(list)
source_counts=defaultdict(int)
window_default=120.0

for uid,meta in campaign.items():
    aid=meta["attack_id"]
    window=window_default
    delta=delta_by_uid.get(uid)
    source=source_by_uid.get(uid)
    if delta is None and aid in agg_by_attack:
        delta=agg_by_attack[aid]
        source="table_correlation_latency_aggregate"
    valid=delta is not None and abs(delta) <= window
    if delta is not None:
        by_attack[aid].append(abs(delta))
        source_counts[source]+=1
    details.append({
        "scenario":meta["scenario"],
        "attack_uid":uid,
        "attack_id":aid,
        "technique_id":meta["technique_id"],
        "temporal_delta_seconds": "" if delta is None else delta,
        "delta_source": source or "not_available",
        "correlation_window_seconds": window,
        "valid_temporal_correlation":"YES" if valid else "NO",
        "correlation_strength":"strong" if valid else "failed"
    })

detail_fields=["scenario","attack_uid","attack_id","technique_id","temporal_delta_seconds","delta_source","correlation_window_seconds","valid_temporal_correlation","correlation_strength"]
with out_detail.open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=detail_fields); w.writeheader(); w.writerows(details)

summary=[]
for aid in sorted(set(m["attack_id"] for m in campaign.values())):
    vals=by_attack.get(aid,[])
    n=len(vals)
    valid=sum(1 for v in vals if v<=window_default)
    summary.append({
        "scenario":"SCENARIO_D",
        "attack_id":aid,
        "executions_with_delta":n,
        "valid_temporal_correlations":valid,
        "failed_temporal_correlations":len([m for m in campaign.values() if m["attack_id"]==aid])-valid,
        "valid_temporal_correlation_percent":round(valid*100/len([m for m in campaign.values() if m["attack_id"]==aid]),2),
        "avg_delta_seconds":round(statistics.mean(vals),6) if vals else "",
        "median_delta_seconds":round(statistics.median(vals),6) if vals else "",
        "max_delta_seconds":round(max(vals),6) if vals else "",
        "p95_delta_seconds":round(pct(vals,95),6) if vals else "",
        "p99_delta_seconds":round(pct(vals,99),6) if vals else ""
    })

with out_table.open("w",newline="",encoding="utf-8") as f:
    fields=["scenario","attack_id","executions_with_delta","valid_temporal_correlations","failed_temporal_correlations","valid_temporal_correlation_percent","avg_delta_seconds","median_delta_seconds","max_delta_seconds","p95_delta_seconds","p99_delta_seconds"]
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(summary)

# Diagnostics
diag={
    "campaign_uids":len(campaign),
    "per_uid_deltas_found":len(delta_by_uid),
    "aggregate_delta_fallbacks_available":len(agg_by_attack),
    "delta_source_counts":dict(source_counts),
    "warning": "Aggregate fallback was used when per-execution delta fields were not available." if any(d["delta_source"]=="table_correlation_latency_aggregate" for d in details) else ""
}
diag_file.write_text(json.dumps(diag,indent=2,ensure_ascii=False),encoding="utf-8")

# SVG figure
width,height=900,420
svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">','<rect width="100%" height="100%" fill="white"/>']
svg.append('<text x="40" y="35" font-family="Arial" font-size="20">Temporal delta distribution by MITRE ICS technique</text>')
vals=[float(s["avg_delta_seconds"] or 0) for s in summary]
maxv=max(vals+[1])
for i,s in enumerate(summary):
    x=60+i*180; val=float(s["avg_delta_seconds"] or 0); bh=(height-130)*(val/maxv) if maxv else 0; y=height-70-bh
    svg.append(f'<rect x="{x}" y="{y}" width="90" height="{bh}" fill="#777"/>')
    svg.append(f'<text x="{x}" y="{height-45}" font-family="Arial" font-size="14">{s["attack_id"]}</text>')
    svg.append(f'<text x="{x}" y="{y-8}" font-family="Arial" font-size="12">{val:.3f}s</text>')
svg.append('</svg>')
out_fig.write_text("\n".join(svg),encoding="utf-8")
print(f"Temporal correlation analysis generated: {out_table}")
print(json.dumps(diag,indent=2,ensure_ascii=False))
PY

phase "3/3" "Resumen." "Summary."

line
echo "[SUMMARY] Temporal Correlation Analysis v1.2"
line
ok "Tabla generada: $OUT_TABLE" "Generated table: $OUT_TABLE"
ok "Detalle generado: $OUT_DETAIL" "Generated detail: $OUT_DETAIL"
ok "Diagnóstico generado: results/processed/temporal_correlation_diagnostics.json" "Diagnostics generated: results/processed/temporal_correlation_diagnostics.json"
