#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

TZ_NAME="${TZ_NAME:-America/Lima}"
now_local() { TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %z (%Z)'; }
now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
line() { printf '%s\n' '============================================================'; }
phase() { printf '\n------------------------------------------------------------\n[PHASE %s] ES: %s\n[PHASE %s] EN: %s\n------------------------------------------------------------\n\n' "$1" "$2" "$1" "$3"; }
info() { printf '[INFO] ES: %s\n[INFO] EN: %s\n\n' "$1" "$2"; }
ok() { printf '[OK] ES: %s\n[OK] EN: %s\n' "$1" "$2"; }
warn() { printf '[WARN] ES: %s\n[WARN] EN: %s\n' "$1" "$2"; }
fail() { printf '\n[ERROR] ES: %s\n[ERROR] EN: %s\n' "$1" "$2" >&2; exit 1; }
script_start() { line; printf '[SCRIPT START] %s\nHora de inicio / Start time: %s\nES: %s\nEN: %s\n' "$1" "$(now_local)" "$2" "$3"; line; printf '\n'; }
execution_window() {
  local seconds="$3"; local start_epoch finish
  start_epoch="$(date +%s)"
  finish="$(TZ="$TZ_NAME" date -d "@$((start_epoch + seconds))" '+%Y-%m-%d %H:%M:%S %z (%Z)' 2>/dev/null || true)"
  line; printf '[EXECUTION WINDOW]\nES: %s\nEN: %s\nHora de inicio / Start time: %s\nDuración estimada / Estimated duration: %02dh:%02dm:%02ds\n' "$1" "$2" "$(now_local)" $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
  [[ -n "$finish" ]] && printf 'Fin estimado / Estimated finish: %s\n' "$finish"
  line; printf '\n'
}
script_end() {
  local code="$?"; line; printf '[EXECUTION END]\nScript: %s\nHora de fin / End time: %s\nExit code: %s\n' "$(basename "$0")" "$(now_local)" "$code"
  if [[ "$code" == "0" ]]; then printf 'ES: Ejecución finalizada correctamente.\nEN: Execution completed successfully.\n'; else printf 'ES: Ejecución finalizada con error; revisar el último mensaje y evidencia generada.\nEN: Execution finished with an error; review the latest message and generated evidence.\n'; fi
  line
}
trap script_end EXIT

script_start "24-analyze-false-positive-rate.sh" \
  "Analizar FPR del Escenario E bajo ruido operacional legítimo." \
  "Analyze Scenario E FPR under legitimate operational noise."

RAW_E_DIR="${RAW_E_DIR:-results/raw/scenario_e}"
PROCESSED_E_DIR="${PROCESSED_E_DIR:-results/processed/scenario_e}"
TABLES_DIR="${TABLES_DIR:-results/tables}"
FIGURES_DIR="${FIGURES_DIR:-results/figures}"
EVIDENCE_WAZUH_DIR="${EVIDENCE_WAZUH_DIR:-evidence/wazuh/scenario_e}"
KUBECTL="${KUBECTL:-microk8s kubectl}"
mkdir -p "$PROCESSED_E_DIR" "$TABLES_DIR" "$FIGURES_DIR" "$EVIDENCE_WAZUH_DIR"

phase "1/4" "Validar datasets de ruido." "Validate noise datasets."
for f in "$RAW_E_DIR/noise_events.csv" "$RAW_E_DIR/noise_http_observations.csv" "$RAW_E_DIR/noise_mqtt_observations.csv" "$RAW_E_DIR/wazuh_noise_events.csv"; do
  [[ -f "$f" ]] || fail "No existe $f. Ejecutar script 23." "$f does not exist. Run script 23."
done

phase "2/4" "Exportar alertas Wazuh relacionadas con SCENARIO_E." "Export Wazuh alerts related to SCENARIO_E."
MANAGER_POD="$($KUBECTL get pod -n security -l app=wazuh-manager,role=master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$MANAGER_POD" ]]; then MANAGER_POD="$($KUBECTL get pod -n security | awk '/wazuh-manager-master/ {print $1; exit}')"; fi
if [[ -n "$MANAGER_POD" ]]; then
  $KUBECTL exec -n security "$MANAGER_POD" -- sh -c 'grep "SCENARIO_E" /var/ossec/logs/alerts/alerts.json 2>/dev/null || true' > "$EVIDENCE_WAZUH_DIR/scenario_e_alerts_export.ndjson" || true
else
  : > "$EVIDENCE_WAZUH_DIR/scenario_e_alerts_export.ndjson"
fi

phase "3/4" "Calcular FPR, Wilson CI y resumen operacional." "Calculate FPR, Wilson CI, and operational summary."
python3 - <<'PY'
import csv, json, math, re
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone
raw=Path("results/raw/scenario_e"); processed=Path("results/processed/scenario_e"); tables=Path("results/tables"); figures=Path("results/figures"); alerts_path=Path("evidence/wazuh/scenario_e/scenario_e_alerts_export.ndjson")
processed.mkdir(parents=True,exist_ok=True); tables.mkdir(parents=True,exist_ok=True); figures.mkdir(parents=True,exist_ok=True)
def read_csv(path):
    with Path(path).open(newline="",encoding="utf-8") as f: return list(csv.DictReader(f))
def wilson(k,n,z=1.96):
    if n==0: return (0.0,0.0)
    phat=k/n; denom=1+z*z/n; center=(phat+z*z/(2*n))/denom; half=z*math.sqrt((phat*(1-phat)+z*z/(4*n))/n)/denom
    return max(0,center-half), min(1,center+half)
noise=read_csv(raw/"noise_events.csv"); http=read_csv(raw/"noise_http_observations.csv"); mqtt=read_csv(raw/"noise_mqtt_observations.csv")
attack_tokens=["T0809","T0814","T0860","Unauthorized Command Message","Data Manipulation","Denial of Service","availability_degradation_http_flood","unauthorized_command_message","telemetry_manipulation"]
false_positive_uids=defaultdict(list); alert_lines=[]
if alerts_path.exists():
    for line in alerts_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip(): continue
        alert_lines.append(line); m=re.search(r'E-(?:LOW|MEDIUM|HIGH)-\d+', line); uid=m.group(0) if m else "UNKNOWN"
        if any(tok in line for tok in attack_tokens): false_positive_uids[uid].append(line)
noise_by_uid={r["noise_uid"]:r for r in noise}; profiles=sorted(set(r["profile"] for r in noise))
fpr_dataset=[]
for uid,row in noise_by_uid.items():
    fp=len(false_positive_uids.get(uid,[]))
    fpr_dataset.append({"timestamp_utc":row["timestamp_utc"],"scenario":"SCENARIO_E","noise_uid":uid,"profile":row["profile"],"iteration":row["iteration"],"noise_type":row["noise_type"],"intensity":row["intensity"],"duration_seconds":row["duration_seconds"],"target_services":row["target_services"],"expected_impact":row["expected_impact"],"false_positive_count":fp,"false_positive_detected":"YES" if fp>0 else "NO"})
fpr_rows=[]
for profile in profiles:
    rows=[r for r in fpr_dataset if r["profile"]==profile]; n=len(rows); k=sum(1 for r in rows if r["false_positive_detected"]=="YES"); lo,hi=wilson(k,n)
    fpr_rows.append({"scenario":"SCENARIO_E","profile":profile,"noise_executions":n,"false_positive_executions":k,"false_positive_rate_percent":round(k*100/n,2) if n else 0,"wilson_ci95_low_percent":round(lo*100,2),"wilson_ci95_high_percent":round(hi*100,2)})
n=len(fpr_dataset); k=sum(1 for r in fpr_dataset if r["false_positive_detected"]=="YES"); lo,hi=wilson(k,n)
fpr_rows.append({"scenario":"SCENARIO_E","profile":"ALL","noise_executions":n,"false_positive_executions":k,"false_positive_rate_percent":round(k*100/n,2) if n else 0,"wilson_ci95_low_percent":round(lo*100,2),"wilson_ci95_high_percent":round(hi*100,2)})
with (processed/"noise_fpr_dataset.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(fpr_dataset[0].keys())); w.writeheader(); w.writerows(fpr_dataset)
for name in ["table_noise_fpr_summary.csv","table_noise_wilson_ci.csv"]:
    with (tables/name).open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=list(fpr_rows[0].keys())); w.writeheader(); w.writerows(fpr_rows)
http_by_uid=defaultdict(list); mqtt_by_uid=defaultdict(list)
for r in http: http_by_uid[r.get("noise_uid","")].append(r)
for r in mqtt: mqtt_by_uid[r.get("noise_uid","")].append(r)
profile_rows=[]
for profile in profiles:
    uids=[r["noise_uid"] for r in noise if r["profile"]==profile]
    hrs=[h for uid in uids for h in http_by_uid.get(uid,[])]; mrs=[m for uid in uids for m in mqtt_by_uid.get(uid,[])]
    http_total=len(hrs); http_errors=0; lat=[]
    for h in hrs:
        try: code=int(h.get("http_code","0"))
        except: code=0
        if code==0 or code>=400: http_errors+=1
        try: lat.append(float(h.get("latency_seconds","0")))
        except: pass
    attempts=sum(int(m.get("messages_attempted","0")) for m in mrs); success=sum(int(m.get("messages_success","0")) for m in mrs); failed=sum(int(m.get("messages_failed","0")) for m in mrs)
    profile_rows.append({"scenario":"SCENARIO_E","profile":profile,"noise_executions":len(uids),"http_observations":http_total,"http_error_count":http_errors,"http_error_rate_percent":round(http_errors*100/http_total,2) if http_total else 0,"avg_http_latency_seconds":round(sum(lat)/len(lat),6) if lat else "","mqtt_messages_attempted":attempts,"mqtt_messages_success":success,"mqtt_messages_failed":failed,"mqtt_success_rate_percent":round(success*100/attempts,2) if attempts else 0})
with (tables/"table_noise_profile_summary.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(profile_rows[0].keys())); w.writeheader(); w.writerows(profile_rows)
zq=[{"scenario":"SCENARIO_E","profile":p,"noise_executions":len([r for r in noise if r["profile"]==p]),"zabbix_observability_note":"Scenario E validates FPR under legitimate traffic; Zabbix observability remains evidenced by prior Scenario B/D history and operational HTTP/MQTT observations."} for p in profiles]
with (tables/"table_noise_zabbix_quality.csv").open("w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(zq[0].keys())); w.writeheader(); w.writerows(zq)
with (processed/"wazuh_noise_false_positive_alerts.ndjson").open("w",encoding="utf-8") as f:
    for lines in false_positive_uids.values():
        for line in lines: f.write(line+"\n")
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="900" height="420">','<rect width="100%" height="100%" fill="white"/>','<text x="40" y="35" font-family="Arial" font-size="20">Scenario E false positive rate by noise profile</text>']
vals=[float(r["false_positive_rate_percent"]) for r in fpr_rows if r["profile"]!="ALL"]; labels=[r["profile"] for r in fpr_rows if r["profile"]!="ALL"]; maxv=max(vals+[1])
for i,(lab,val) in enumerate(zip(labels,vals)):
    x=60+i*180; bh=260*(val/maxv) if maxv else 0; y=350-bh
    svg.append(f'<rect x="{x}" y="{y}" width="90" height="{bh}" fill="#777"/>'); svg.append(f'<text x="{x}" y="380" font-family="Arial" font-size="14">{lab}</text>'); svg.append(f'<text x="{x}" y="{y-8}" font-family="Arial" font-size="12">{val:.2f}%</text>')
svg.append('</svg>'); (figures/"figure_noise_fpr_by_profile.svg").write_text("\n".join(svg),encoding="utf-8")
summary={"generated_utc":datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),"noise_executions":n,"false_positive_executions":k,"false_positive_rate_percent":round(k*100/n,2) if n else 0,"wilson_ci95_low_percent":round(lo*100,2),"wilson_ci95_high_percent":round(hi*100,2),"alerts_lines_with_scenario_e":len(alert_lines)}
(processed/"noise_fpr_summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf-8")
print(json.dumps(summary,indent=2,ensure_ascii=False))
PY

phase "4/4" "Validar salidas FPR." "Validate FPR outputs."
for f in "$PROCESSED_E_DIR/noise_fpr_dataset.csv" "$TABLES_DIR/table_noise_fpr_summary.csv" "$TABLES_DIR/table_noise_wilson_ci.csv" "$TABLES_DIR/table_noise_profile_summary.csv" "$TABLES_DIR/table_noise_zabbix_quality.csv" "$FIGURES_DIR/figure_noise_fpr_by_profile.svg" "$PROCESSED_E_DIR/noise_fpr_summary.json"; do
  [[ -s "$f" ]] || fail "Archivo ausente o vacío: $f" "Missing or empty file: $f"
  ok "Generado: $f" "Generated: $f"
done
line; echo "[SUMMARY] Scenario E False Positive Analysis"; line
ok "FPR calculado por perfil y total" "FPR calculated by profile and total"
ok "Wilson CI generado para FPR" "Wilson CI generated for FPR"
