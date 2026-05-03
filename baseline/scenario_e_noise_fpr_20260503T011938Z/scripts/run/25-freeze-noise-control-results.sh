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

script_start "25-freeze-noise-control-results.sh" \
  "Congelar resultados reproducibles del Escenario E." \
  "Freeze reproducible Scenario E results."

KUBECTL="${KUBECTL:-microk8s kubectl}"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
FREEZE_DIR="${FREEZE_DIR:-baseline/scenario_e_noise_fpr_${STAMP}}"
ARCHIVE="${FREEZE_DIR}.tar.gz"

phase "1/3" "Crear directorio de freeze Escenario E." "Create Scenario E freeze directory."
mkdir -p "$FREEZE_DIR"/{results/raw,results/processed,results/tables,results/figures,evidence/wazuh,kubernetes,scripts/run}

phase "2/3" "Copiar datasets, evidencia, scripts y snapshots." "Copy datasets, evidence, scripts, and snapshots."
[[ -d results/raw/scenario_e ]] && mkdir -p "$FREEZE_DIR/results/raw" && cp -a results/raw/scenario_e "$FREEZE_DIR/results/raw/"
[[ -d results/processed/scenario_e ]] && mkdir -p "$FREEZE_DIR/results/processed" && cp -a results/processed/scenario_e "$FREEZE_DIR/results/processed/"
for f in results/tables/table_noise_fpr_summary.csv results/tables/table_noise_wilson_ci.csv results/tables/table_noise_profile_summary.csv results/tables/table_noise_zabbix_quality.csv; do [[ -f "$f" ]] && cp "$f" "$FREEZE_DIR/results/tables/"; done
[[ -f results/figures/figure_noise_fpr_by_profile.svg ]] && cp results/figures/figure_noise_fpr_by_profile.svg "$FREEZE_DIR/results/figures/"
[[ -d evidence/wazuh/scenario_e ]] && cp -a evidence/wazuh/scenario_e "$FREEZE_DIR/evidence/wazuh/"
for s in scripts/run/23-run-operational-noise-control.sh scripts/run/24-analyze-false-positive-rate.sh scripts/run/25-freeze-noise-control-results.sh; do [[ -f "$s" ]] && cp "$s" "$FREEZE_DIR/scripts/run/"; done
for d in iiot-poc monitoring security; do
  $KUBECTL get all -n "$d" -o wide > "$FREEZE_DIR/kubernetes/${d}_all.txt" 2>/dev/null || true
  $KUBECTL get svc -n "$d" -o yaml > "$FREEZE_DIR/kubernetes/${d}_services.yaml" 2>/dev/null || true
done
$KUBECTL get nodes -o wide > "$FREEZE_DIR/kubernetes/nodes.txt" 2>/dev/null || true
$KUBECTL get storageclass -o wide > "$FREEZE_DIR/kubernetes/storageclasses.txt" 2>/dev/null || true
cat > "$FREEZE_DIR/README_SCENARIO_E_FREEZE.md" <<EOF
# Scenario E Noise / FPR Freeze

Generated UTC: ${STAMP}

This freeze contains raw/processed Scenario E datasets, FPR tables, evidence, scripts, and Kubernetes snapshots.

Scenario E is a legitimate operational noise control run designed to estimate false positives for MITRE ICS techniques T0809, T0814, and T0860.
EOF

phase "3/3" "Generar SHA256SUMS y archivo comprimido." "Generate SHA256SUMS and compressed archive."
(cd "$FREEZE_DIR" && find . -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar -czf "$ARCHIVE" -C "$(dirname "$FREEZE_DIR")" "$(basename "$FREEZE_DIR")"
line; echo "[SUMMARY] Scenario E Noise/FPR Freeze"; line
ok "Freeze generado: $FREEZE_DIR" "Freeze generated: $FREEZE_DIR"
ok "Archivo comprimido generado: $ARCHIVE" "Compressed archive generated: $ARCHIVE"
ok "SHA256SUMS generado" "SHA256SUMS generated"
