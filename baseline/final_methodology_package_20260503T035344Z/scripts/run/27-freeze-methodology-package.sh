#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

KUBECTL="${KUBECTL:-microk8s kubectl}"
TZ_NAME="${TZ_NAME:-America/Lima}"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
FREEZE_DIR="${FREEZE_DIR:-baseline/final_methodology_package_${STAMP}}"
ARCHIVE="${FREEZE_DIR}.tar.gz"
EXPECTED_D_EXECUTIONS="${EXPECTED_D_EXECUTIONS:-60}"
EXPECTED_E_EXECUTIONS="${EXPECTED_E_EXECUTIONS:-60}"

now_local() { TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %z (%Z)'; }
now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
line() { printf '%s\n' '============================================================'; }
phase() {
  printf '\n------------------------------------------------------------\n'
  printf '[PHASE %s] ES: %s\n' "$1" "$2"
  printf '[PHASE %s] EN: %s\n' "$1" "$3"
  printf '%s\n\n' '------------------------------------------------------------'
}
ok() { printf '[OK] ES: %s\n[OK] EN: %s\n' "$1" "$2"; }
fail() { printf '\n[ERROR] ES: %s\n[ERROR] EN: %s\n' "$1" "$2" >&2; exit 1; }
finish() {
  local code="$?"
  line
  echo "[EXECUTION END]"
  echo "Script: $(basename "$0")"
  echo "Hora de fin / End time: $(now_local)"
  echo "Exit code: $code"
  if [[ "$code" == "0" ]]; then
    echo "ES: Ejecución finalizada correctamente."
    echo "EN: Execution completed successfully."
  else
    echo "ES: Ejecución finalizada con error."
    echo "EN: Execution finished with an error."
  fi
  line
}
trap finish EXIT

line
echo "[SCRIPT START] 27-freeze-methodology-package.sh"
echo "Hora de inicio / Start time: $(now_local)"
echo "ES: Congelar paquete metodológico final D+E."
echo "EN: Freeze final D+E methodology package."
line

phase "1/6" "Validar completitud de Escenario D." "Validate Scenario D completeness."

[[ -f results/processed/correlation_dataset.csv ]] || fail "Falta results/processed/correlation_dataset.csv" "Missing results/processed/correlation_dataset.csv"
[[ -f results/raw/scenario_d/zabbix_history_validation.csv ]] || fail "Falta zabbix_history_validation.csv" "Missing zabbix_history_validation.csv"
[[ -f results/tables/table_temporal_correlation_summary.csv ]] || fail "Falta table_temporal_correlation_summary.csv" "Missing table_temporal_correlation_summary.csv"
[[ -f results/tables/table_bootstrap_ci.csv ]] || fail "Falta table_bootstrap_ci.csv" "Missing table_bootstrap_ci.csv"

d_rows="$(python3 - <<'PY'
from pathlib import Path
p=Path("results/processed/correlation_dataset.csv")
print(max(sum(1 for _ in p.open(encoding="utf-8"))-1,0))
PY
)"
[[ "$d_rows" -eq "$EXPECTED_D_EXECUTIONS" ]] || fail "Escenario D incompleto: esperado $EXPECTED_D_EXECUTIONS, encontrado $d_rows." "Incomplete Scenario D: expected $EXPECTED_D_EXECUTIONS, found $d_rows."
ok "Escenario D completo: $d_rows ejecuciones." "Scenario D complete: $d_rows executions."

phase "2/6" "Validar completitud de Escenario E." "Validate Scenario E completeness."

[[ -f results/raw/scenario_e/noise_events.csv ]] || fail "Falta noise_events.csv" "Missing noise_events.csv"
[[ -f results/raw/scenario_e/http_endpoint_validation_summary.json ]] || fail "Falta http_endpoint_validation_summary.json" "Missing http_endpoint_validation_summary.json"
[[ -f results/processed/scenario_e/noise_fpr_summary.json ]] || fail "Falta noise_fpr_summary.json" "Missing noise_fpr_summary.json"
[[ -f results/tables/table_noise_fpr_summary.csv ]] || fail "Falta table_noise_fpr_summary.csv" "Missing table_noise_fpr_summary.csv"

e_rows="$(python3 - <<'PY'
from pathlib import Path
p=Path("results/raw/scenario_e/noise_events.csv")
print(max(sum(1 for _ in p.open(encoding="utf-8"))-1,0))
PY
)"
[[ "$e_rows" -eq "$EXPECTED_E_EXECUTIONS" ]] || fail "Escenario E incompleto: esperado $EXPECTED_E_EXECUTIONS, encontrado $e_rows." "Incomplete Scenario E: expected $EXPECTED_E_EXECUTIONS, found $e_rows."

http_errors="$(python3 - <<'PY'
import json
from pathlib import Path
data=json.loads(Path("results/raw/scenario_e/http_endpoint_validation_summary.json").read_text(encoding="utf-8"))
print(data.get("http_error_count","MISSING"))
PY
)"
[[ "$http_errors" == "0" ]] || fail "Escenario E contiene errores HTTP: $http_errors." "Scenario E contains HTTP errors: $http_errors."
ok "Escenario E completo: $e_rows ejecuciones y 0 errores HTTP." "Scenario E complete: $e_rows executions and 0 HTTP errors."

phase "3/6" "Crear estructura de freeze final." "Create final freeze structure."

mkdir -p "$FREEZE_DIR"/{docs,scripts,kubernetes,results/raw,results/processed,results/tables,results/figures,evidence,baseline_refs}

phase "4/6" "Copiar documentación, scripts, resultados y evidencia." "Copy documentation, scripts, results, and evidence."

[[ -f README.md ]] && cp README.md "$FREEZE_DIR/"
[[ -f README.en.md ]] && cp README.en.md "$FREEZE_DIR/"
[[ -f CHANGELOG.md ]] && cp CHANGELOG.md "$FREEZE_DIR/" || true
[[ -d docs ]] && cp -a docs "$FREEZE_DIR/"
[[ -d scripts/run ]] && mkdir -p "$FREEZE_DIR/scripts" && cp -a scripts/run "$FREEZE_DIR/scripts/"
[[ -d scripts/collectors ]] && cp -a scripts/collectors "$FREEZE_DIR/scripts/" || true
[[ -d scripts/lib ]] && cp -a scripts/lib "$FREEZE_DIR/scripts/" || true
[[ -d kubernetes ]] && cp -a kubernetes "$FREEZE_DIR/"

[[ -d results/raw/scenario_d ]] && cp -a results/raw/scenario_d "$FREEZE_DIR/results/raw/"
[[ -d results/raw/scenario_e ]] && cp -a results/raw/scenario_e "$FREEZE_DIR/results/raw/"
[[ -d results/processed ]] && cp -a results/processed "$FREEZE_DIR/results/"
[[ -d results/tables ]] && cp -a results/tables "$FREEZE_DIR/results/"
[[ -d results/figures ]] && cp -a results/figures "$FREEZE_DIR/results/"
[[ -d evidence ]] && cp -a evidence "$FREEZE_DIR/"

find baseline -maxdepth 1 -type f \( -name 'scenario_d_correlation_*.tar.gz' -o -name 'scenario_e_noise_fpr_*.tar.gz' \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
  cp "$f" "$FREEZE_DIR/baseline_refs/"
done

phase "5/6" "Exportar snapshots Kubernetes e inventario final." "Export final Kubernetes snapshots and inventory."

cat > "$FREEZE_DIR/FINAL_PACKAGE_METADATA.json" <<EOF
{
  "generated_utc": "$(now_utc)",
  "generated_local": "$(now_local)",
  "expected_scenario_d_executions": $EXPECTED_D_EXECUTIONS,
  "actual_scenario_d_executions": $d_rows,
  "expected_scenario_e_executions": $EXPECTED_E_EXECUTIONS,
  "actual_scenario_e_executions": $e_rows,
  "scenario_e_http_errors": $http_errors,
  "scope": "IIoT + Zabbix + Wazuh + event-based temporal correlation + false positive control",
  "methodological_status": "paper_final_candidate"
}
EOF

for ns in iiot-poc monitoring security; do
  $KUBECTL get all -n "$ns" -o wide > "$FREEZE_DIR/kubernetes/${ns}_all.txt" 2>/dev/null || true
  $KUBECTL get all -n "$ns" -o yaml > "$FREEZE_DIR/kubernetes/${ns}_all.yaml" 2>/dev/null || true
  $KUBECTL get pvc -n "$ns" -o wide > "$FREEZE_DIR/kubernetes/${ns}_pvc.txt" 2>/dev/null || true
  $KUBECTL get svc -n "$ns" -o wide > "$FREEZE_DIR/kubernetes/${ns}_services.txt" 2>/dev/null || true
done
$KUBECTL get nodes -o wide > "$FREEZE_DIR/kubernetes/nodes.txt" 2>/dev/null || true
$KUBECTL get storageclass -o wide > "$FREEZE_DIR/kubernetes/storageclasses.txt" 2>/dev/null || true

cat > "$FREEZE_DIR/README_FINAL_FREEZE.md" <<'EOF'
# Final Methodology Package

This package consolidates Scenario D attack/correlation evidence and Scenario E operational-noise/FPR evidence.

It includes raw datasets, processed datasets, normalized datasets, statistical tables, figures, evidence logs, Kubernetes snapshots, scripts, documentation, freeze references, and SHA256SUMS.
EOF

phase "6/6" "Generar SHA256SUMS y comprimir paquete final." "Generate SHA256SUMS and compress final package."

(
  cd "$FREEZE_DIR"
  find . -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

tar -czf "$ARCHIVE" -C "$(dirname "$FREEZE_DIR")" "$(basename "$FREEZE_DIR")"

line
echo "[SUMMARY] Final Methodology Package Freeze"
line
ok "Freeze generado: $FREEZE_DIR" "Freeze generated: $FREEZE_DIR"
ok "Archivo comprimido generado: $ARCHIVE" "Compressed archive generated: $ARCHIVE"
ok "Escenario D validado con $d_rows ejecuciones" "Scenario D validated with $d_rows executions"
ok "Escenario E validado con $e_rows ejecuciones y 0 errores HTTP" "Scenario E validated with $e_rows executions and 0 HTTP errors"
ok "SHA256SUMS generado" "SHA256SUMS generated"
