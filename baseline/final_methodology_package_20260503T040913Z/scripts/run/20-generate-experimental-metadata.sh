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

script_start "20-generate-experimental-metadata.sh" \
  "Generar metadata experimental final con resumen de filtrado." \
  "Generate final experimental metadata with filtering summary."

OUT_DIR="${OUT_DIR:-results/processed}"
META_JSON="$OUT_DIR/experimental_metadata_final.json"
META_MD="$OUT_DIR/experimental_metadata_final.md"
NORM_SUMMARY="${NORM_SUMMARY:-results/processed/normalized/normalization_summary.json}"
mkdir -p "$OUT_DIR"

phase "1/3" "Recolectar parámetros, entorno y resumen normalizado." "Collect parameters, environment, and normalization summary."

python3 - <<'PY'
import csv, json, os, subprocess, hashlib
from pathlib import Path
from datetime import datetime, timezone

out_dir = Path(os.environ.get("OUT_DIR", "results/processed"))
norm_summary_path = Path(os.environ.get("NORM_SUMMARY", "results/processed/normalized/normalization_summary.json"))

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "not_available"

def sha(path):
    p=Path(path)
    if not p.exists(): return None
    return hashlib.sha256(p.read_bytes()).hexdigest()

def count_rows(path):
    p=Path(path)
    if not p.exists(): return 0
    return max(sum(1 for _ in p.open(encoding="utf-8"))-1,0)

def read_csv(path):
    p=Path(path)
    if not p.exists(): return []
    with p.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))

attack_path=Path("results/raw/scenario_d/mitre_ics_attacks.csv")
wazuh_path=Path("results/raw/scenario_d/wazuh_security_events.csv")
zabbix_path=Path("results/raw/scenario_d/zabbix_correlation_metrics.csv")
corr_path=Path("results/processed/correlation_dataset.csv")
norm_files={
    "events_normalized": Path("results/processed/normalized/events_normalized.csv"),
    "metrics_normalized": Path("results/processed/normalized/metrics_normalized.csv"),
    "correlation_normalized": Path("results/processed/normalized/correlation_normalized.csv"),
    "dataset_schema": Path("results/processed/normalized/dataset_schema.json")
}

iterations={}
for r in read_csv(attack_path):
    aid=r.get("attack_id") or r.get("mitre_ics") or "unknown"
    iterations[aid]=iterations.get(aid,0)+1

norm_summary={}
if norm_summary_path.exists():
    norm_summary=json.loads(norm_summary_path.read_text(encoding="utf-8"))

metadata={
    "metadata_version":"1.1",
    "generated_utc":datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "experiment_id":"scenario_d_final",
    "dataset_version":"1.1",
    "laboratory_scope":"IIoT + Zabbix + Wazuh + event-based temporal correlation",
    "scenario":"D",
    "techniques":sorted(iterations.keys()),
    "iterations_by_attack":iterations,
    "total_attack_executions":sum(iterations.values()),
    "configured_parameters":{
        "iterations_recommended":20,
        "baseline_warmup_seconds":60,
        "inter_attack_cooldown_seconds":10,
        "dos_requests":500,
        "dos_concurrency":30,
        "attack_duration_seconds":30,
        "http_probe_interval_seconds":2,
        "zabbix_polling_seconds":5,
        "correlation_window_seconds":120,
        "zabbix_history_lookback_seconds":120,
        "zabbix_history_forward_seconds":120
    },
    "environment":{
        "node":run("microk8s kubectl get nodes -o wide --no-headers 2>/dev/null"),
        "kubernetes_version":run("microk8s kubectl version --client 2>/dev/null | head -5"),
        "storageclasses":run("microk8s kubectl get storageclass --no-headers 2>/dev/null"),
        "os_release":run("cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2- | tr -d '\"'"),
        "python_version":run("python3 --version")
    },
    "tool_versions":{
        "wazuh_images":run("microk8s kubectl get pods -n security -o jsonpath='{range .items[*]}{.spec.containers[*].image}{\"\\n\"}{end}' | sort -u"),
        "zabbix_images":run("microk8s kubectl get pods -n monitoring -o jsonpath='{range .items[*]}{.spec.containers[*].image}{\"\\n\"}{end}' | sort -u"),
        "iiot_images":run("microk8s kubectl get pods -n iiot-poc -o jsonpath='{range .items[*]}{.spec.containers[*].image}{\"\\n\"}{end}' | sort -u")
    },
    "raw_datasets":{
        "mitre_ics_attacks":{"path":str(attack_path),"rows":count_rows(attack_path),"sha256":sha(attack_path)},
        "wazuh_security_events":{"path":str(wazuh_path),"rows":count_rows(wazuh_path),"sha256":sha(wazuh_path)},
        "zabbix_correlation_metrics":{"path":str(zabbix_path),"rows":count_rows(zabbix_path),"sha256":sha(zabbix_path)},
        "correlation_dataset":{"path":str(corr_path),"rows":count_rows(corr_path),"sha256":sha(corr_path)}
    },
    "normalized_datasets":{
        k: {"path":str(v),"rows":count_rows(v) if v.suffix==".csv" else None,"sha256":sha(v)}
        for k,v in norm_files.items()
    },
    "normalization_summary":norm_summary,
    "methodological_note":"Correlation is event-based temporal correlation within a predefined window, not Pearson/Spearman statistical correlation."
}

json_path=out_dir/"experimental_metadata_final.json"
md_path=out_dir/"experimental_metadata_final.md"
json_path.write_text(json.dumps(metadata,indent=2,ensure_ascii=False),encoding="utf-8")

md=[]
md.append("# Experimental Metadata Final")
md.append("")
md.append(f"- Metadata version: `{metadata['metadata_version']}`")
md.append(f"- Generated UTC: `{metadata['generated_utc']}`")
md.append(f"- Experiment ID: `{metadata['experiment_id']}`")
md.append(f"- Dataset version: `{metadata['dataset_version']}`")
md.append("")
md.append("## Campaign parameters")
for k,v in metadata["configured_parameters"].items():
    md.append(f"- `{k}`: `{v}`")
md.append("")
md.append("## Normalization summary")
for k,v in norm_summary.items():
    md.append(f"- `{k}`: `{v}`")
md.append("")
md.append("## Methodological note")
md.append(metadata["methodological_note"])
md_path.write_text("\n".join(md)+"\n",encoding="utf-8")

print(json.dumps({"metadata_json":str(json_path),"metadata_md":str(md_path)},indent=2))
PY

phase "2/3" "Validar metadata." "Validate metadata."

[[ -s "$META_JSON" ]] || fail "No se generó $META_JSON" "$META_JSON was not generated"
[[ -s "$META_MD" ]] || fail "No se generó $META_MD" "$META_MD was not generated"

phase "3/3" "Resumen." "Summary."

line
echo "[SUMMARY] Experimental Metadata v1.1"
line
ok "Metadata JSON final: $META_JSON" "Final metadata JSON: $META_JSON"
ok "Incluye resumen de filtrado y datasets normalizados" "Includes filtering summary and normalized datasets"
