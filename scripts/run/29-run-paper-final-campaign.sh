#!/usr/bin/env bash
set -euo pipefail

# Ejecuta solo las campañas cuantitativas paper-ready D-E | Runs only the paper-ready quantitative campaigns D-E
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando campaña final paper-ready D-E" "Starting paper-ready final campaign D-E"
require_command kubectl

run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness inicial A-E" "Validating initial A-E readiness"
run_existing_script "scripts/run/36-run-scenario-d-correlation.sh" "Ejecutando campaña cuantitativa D" "Running quantitative campaign D"
run_existing_script "scripts/run/37-run-scenario-e-noise-fpr.sh" "Ejecutando campaña cuantitativa E" "Running quantitative campaign E"

if [[ "${AUTO_FREEZE_AFTER_RUN}" == "true" ]]; then
  run_existing_script "scripts/run/27-freeze-methodology-package.sh" "Generando freeze metodológico final" "Generating final methodology freeze"
fi

run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness final A-E" "Validating final A-E readiness"
run_optional_script "scripts/run/32-verify-final-freeze.sh" "Verificando integridad SHA256 del último freeze" "Verifying SHA256 integrity of the latest freeze"

if [[ "${SHOW_FINAL_SUMMARY}" == "true" ]]; then
  run_optional_script "scripts/run/31-show-paper-results.sh" "Mostrando resultados finales para revisión" "Showing final results for review"
fi

log_step "Campaña final paper-ready D-E completada" "Paper-ready final campaign D-E completed"
