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

script_start "26-apply-scenario-e-documentation-updates.sh" \
  "Aplicar actualizaciones documentales idempotentes del Escenario E." \
  "Apply idempotent Scenario E documentation updates."

phase "1/2" "Actualizar documentos existentes sin sobrescribir contenido previo." "Update existing documents without overwriting prior content."

append_block() {
  local file="$1"; local marker="$2"; local content="$3"
  touch "$file"
  if grep -q "$marker" "$file"; then ok "Bloque ya existe en $file" "Block already exists in $file"; else { printf '\n\n%s\n' "$marker"; printf '%s\n' "$content"; } >> "$file"; ok "Bloque agregado en $file" "Block added to $file"; fi
}

append_block "README.md" "<!-- SCENARIO_E_NOISE_FPR_V1 -->" '
## Escenario E — Operational Noise / False Positive Control

El Escenario E ejecuta ruido operacional legítimo y controlado para medir falsos positivos frente a las técnicas MITRE ATT&CK for ICS evaluadas en el Escenario D. No introduce ataques, sabotaje, chaos engineering ni infraestructura adicional.

```bash
ITERATIONS_PER_PROFILE=20 NOISE_DURATION_SECONDS=30 INTER_NOISE_COOLDOWN_SECONDS=10 ./scripts/run/23-run-operational-noise-control.sh
./scripts/run/24-analyze-false-positive-rate.sh
./scripts/run/25-freeze-noise-control-results.sh
```
'

append_block "README.en.md" "<!-- SCENARIO_E_NOISE_FPR_V1 -->" '
## Scenario E — Operational Noise / False Positive Control

Scenario E runs legitimate and controlled operational noise to measure false positives against the MITRE ATT&CK for ICS techniques evaluated in Scenario D. It does not introduce attacks, sabotage, chaos engineering, or additional infrastructure.
'

append_block "docs/08-experiments.md" "<!-- SCENARIO_E_NOISE_FPR_V1 -->" '
## Scenario E — Operational Noise / False Positive Control

Scenario E is a non-attack control campaign. It generates legitimate MQTT and HTTP activity under LOW, MEDIUM, and HIGH operational noise profiles to estimate false positives under normal operational variability.
'

append_block "docs/09-results.md" "<!-- SCENARIO_E_NOISE_FPR_V1 -->" '
## Scenario E results

Scenario E produces `table_noise_fpr_summary.csv`, `table_noise_wilson_ci.csv`, `table_noise_profile_summary.csv`, and `table_noise_zabbix_quality.csv`. FPR must be reported with Wilson confidence intervals.
'

append_block "docs/10-reproducibility.md" "<!-- SCENARIO_E_NOISE_FPR_V1 -->" '
## Scenario E reproducibility

Scenario E is reproduced with scripts 23–25. The freeze includes raw noise datasets, processed FPR datasets, tables, evidence, Kubernetes snapshots, scripts, and SHA256SUMS.
'

append_block "docs/11-experimental-design.md" "<!-- SCENARIO_E_NOISE_FPR_V1 -->" '
## Methodological justification for Scenario E

Scenario E separates legitimate operational variability from attack behavior. It supports false-positive analysis and robustness evaluation without changing the main hypothesis or converting the study into a performance benchmark.
'

append_block "docs/13-reviewer-traceability.md" "<!-- SCENARIO_E_NOISE_FPR_V1 -->" '
## Reviewer traceability — Scenario E

| Reviewer concern | Scenario E evidence |
|---|---|
| False positives | `table_noise_fpr_summary.csv` |
| Operational variability | LOW/MEDIUM/HIGH noise profiles |
| Statistical confidence | Wilson CI for FPR |
| Reproducibility | `baseline/scenario_e_noise_fpr_*.tar.gz` |
| Separation between attacks and noise | `noise_uid` and `scenario=SCENARIO_E` |
'

phase "2/2" "Resumen." "Summary."
line; echo "[SUMMARY] Scenario E Documentation Updates"; line
ok "Actualizaciones documentales aplicadas de forma idempotente" "Documentation updates applied idempotently"
