#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

TZ_NAME="${TZ_NAME:-America/Lima}"

now_local() { TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %z (%Z)'; }
now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

line() { printf '%s\n' '============================================================'; }

phase() {
  printf '\n------------------------------------------------------------\n'
  printf '[PHASE %s] ES: %s\n' "$1" "$2"
  printf '[PHASE %s] EN: %s\n' "$1" "$3"
  printf '%s\n\n' '------------------------------------------------------------'
}

info() {
  printf '[INFO] ES: %s\n' "$1"
  printf '[INFO] EN: %s\n\n' "$2"
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

execution_window() {
  local es="$1" en="$2" seconds="$3"
  local start_epoch finish
  start_epoch="$(date +%s)"
  finish="$(TZ="$TZ_NAME" date -d "@$((start_epoch + seconds))" '+%Y-%m-%d %H:%M:%S %z (%Z)' 2>/dev/null || true)"
  line
  printf '[EXECUTION WINDOW]\n'
  printf 'ES: %s\n' "$es"
  printf 'EN: %s\n' "$en"
  printf 'Hora de inicio / Start time: %s\n' "$(now_local)"
  printf 'Duración estimada / Estimated duration: %02dh:%02dm:%02ds\n' $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
  [[ -n "$finish" ]] && printf 'Fin estimado / Estimated finish: %s\n' "$finish"
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

script_start "25-freeze-noise-control-results.sh" \
  "Congelar resultados reproducibles completos del Escenario E." \
  "Freeze complete reproducible Scenario E results."

KUBECTL="${KUBECTL:-microk8s kubectl}"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
FREEZE_DIR="${FREEZE_DIR:-baseline/scenario_e_noise_fpr_${STAMP}}"
ARCHIVE="${FREEZE_DIR}.tar.gz"

EXPECTED_PROFILES="${EXPECTED_PROFILES:-3}"
EXPECTED_ITERATIONS_PER_PROFILE="${EXPECTED_ITERATIONS_PER_PROFILE:-20}"
EXPECTED_TOTAL="${EXPECTED_TOTAL:-$((EXPECTED_PROFILES * EXPECTED_ITERATIONS_PER_PROFILE))}"

phase "1/4" "Validar que Escenario E está completo antes del freeze." "Validate Scenario E completeness before freeze."

[[ -f results/raw/scenario_e/noise_events.csv ]] || fail "Falta noise_events.csv" "Missing noise_events.csv"
[[ -f results/processed/scenario_e/noise_fpr_summary.json ]] || fail "Falta noise_fpr_summary.json" "Missing noise_fpr_summary.json"

actual="$(python3 - <<'PY'
import csv
from pathlib import Path
p=Path("results/raw/scenario_e/noise_events.csv")
print(max(sum(1 for _ in p.open(encoding="utf-8"))-1,0))
PY
)"
if [[ "$actual" -ne "$EXPECTED_TOTAL" ]]; then
  fail "Escenario E incompleto: se esperaban $EXPECTED_TOTAL ejecuciones y existen $actual. No se congela." \
       "Incomplete Scenario E: expected $EXPECTED_TOTAL executions and found $actual. Freeze is aborted."
fi

http_errors="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path("results/raw/scenario_e/http_endpoint_validation_summary.json")
if not p.exists():
    print("MISSING")
else:
    data=json.loads(p.read_text())
    print(data.get("http_error_count","MISSING"))
PY
)"
if [[ "$http_errors" != "0" ]]; then
  fail "Escenario E con errores HTTP ($http_errors). No se congela como paper-final." \
       "Scenario E has HTTP errors ($http_errors). It will not be frozen as paper-final."
fi

phase "2/4" "Crear directorio de freeze Escenario E." "Create Scenario E freeze directory."

mkdir -p "$FREEZE_DIR"/{results/raw,results/processed,results/tables,results/figures,evidence/wazuh,kubernetes,docs,scripts/run}

phase "3/4" "Copiar datasets, evidencia, scripts y snapshots." "Copy datasets, evidence, scripts, and snapshots."

cp -a results/raw/scenario_e "$FREEZE_DIR/results/raw/"
cp -a results/processed/scenario_e "$FREEZE_DIR/results/processed/"

for f in \
  results/tables/table_noise_fpr_summary.csv \
  results/tables/table_noise_wilson_ci.csv \
  results/tables/table_noise_profile_summary.csv \
  results/tables/table_noise_zabbix_quality.csv
do
  [[ -f "$f" ]] && cp "$f" "$FREEZE_DIR/results/tables/"
done

[[ -f results/figures/figure_noise_fpr_by_profile.svg ]] && cp results/figures/figure_noise_fpr_by_profile.svg "$FREEZE_DIR/results/figures/"
[[ -d evidence/wazuh/scenario_e ]] && cp -a evidence/wazuh/scenario_e "$FREEZE_DIR/evidence/wazuh/"

for s in 23-run-operational-noise-control.sh 24-analyze-false-positive-rate.sh 25-freeze-noise-control-results.sh; do
  cp "scripts/run/$s" "$FREEZE_DIR/scripts/run/" 2>/dev/null || true
done

for d in iiot-poc monitoring security; do
  $KUBECTL get all -n "$d" -o wide > "$FREEZE_DIR/kubernetes/${d}_all.txt" 2>/dev/null || true
  $KUBECTL get configmap -n "$d" -o yaml > "$FREEZE_DIR/kubernetes/${d}_configmaps.yaml" 2>/dev/null || true
  $KUBECTL get svc -n "$d" -o yaml > "$FREEZE_DIR/kubernetes/${d}_services.yaml" 2>/dev/null || true
done
$KUBECTL get nodes -o wide > "$FREEZE_DIR/kubernetes/nodes.txt" 2>/dev/null || true
$KUBECTL get storageclass -o wide > "$FREEZE_DIR/kubernetes/storageclasses.txt" 2>/dev/null || true

cat > "$FREEZE_DIR/README_SCENARIO_E_FREEZE.md" <<EOF
# Scenario E Noise / FPR Freeze

Generated UTC: ${STAMP}

This freeze contains the complete Scenario E paper-final run.

Expected executions: ${EXPECTED_TOTAL}
HTTP endpoint validation: 0 errors required
Scenario: legitimate operational noise / false positive control
EOF

phase "4/4" "Generar SHA256SUMS y archivo comprimido." "Generate SHA256SUMS and compressed archive."

(
  cd "$FREEZE_DIR"
  find . -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

tar -czf "$ARCHIVE" -C "$(dirname "$FREEZE_DIR")" "$(basename "$FREEZE_DIR")"

line
echo "[SUMMARY] Scenario E Noise/FPR Freeze v1.2"
line
ok "Freeze generado: $FREEZE_DIR" "Freeze generated: $FREEZE_DIR"
ok "Archivo comprimido generado: $ARCHIVE" "Compressed archive generated: $ARCHIVE"
ok "Completitud validada antes del freeze" "Completeness validated before freeze"
ok "SHA256SUMS generado" "SHA256SUMS generated"
