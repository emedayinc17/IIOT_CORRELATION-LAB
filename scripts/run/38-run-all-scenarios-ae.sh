#!/usr/bin/env bash
set -euo pipefail

# Ejecuta todos los escenarios A-E mediante wrappers entendibles | Runs all A-E scenarios using understandable wrappers
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando ejecución completa A-E" "Starting full A-E execution"
require_command kubectl

run_existing_script "scripts/run/33-run-scenario-a-foundation.sh" "Ejecutando escenario A" "Running scenario A"
run_existing_script "scripts/run/34-run-scenario-b-zabbix.sh" "Ejecutando escenario B" "Running scenario B"
run_existing_script "scripts/run/35-run-scenario-c-wazuh.sh" "Ejecutando escenario C" "Running scenario C"
run_existing_script "scripts/run/36-run-scenario-d-correlation.sh" "Ejecutando escenario D" "Running scenario D"
run_existing_script "scripts/run/37-run-scenario-e-noise-fpr.sh" "Ejecutando escenario E" "Running scenario E"

if [[ "${AUTO_FREEZE_AFTER_RUN}" == "true" ]]; then
  run_existing_script "scripts/run/27-freeze-methodology-package.sh" "Generando freeze metodológico final A-E" "Generating final A-E methodology freeze"
fi

run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness final A-E" "Validating final A-E readiness"
run_optional_script "scripts/run/32-verify-final-freeze.sh" "Verificando SHA256 del freeze final" "Verifying SHA256 of final freeze"
run_optional_script "scripts/run/31-show-paper-results.sh" "Mostrando resultados finales" "Showing final results"

log_step "Ejecución completa A-E finalizada" "Full A-E execution completed"
