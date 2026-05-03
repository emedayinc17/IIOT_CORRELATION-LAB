#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el escenario A agrupando foundation, baseline y freeze operacional | Runs scenario A by grouping foundation, baseline, and operational freeze
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando escenario A - Foundation IIoT" "Starting scenario A - Foundation IIoT"
require_command kubectl

if [[ "${RESET_BEFORE_SCENARIO_A}" == "true" ]]; then
  run_existing_script "scripts/run/00-reset-lab.sh" "Reiniciando laboratorio antes de escenario A" "Resetting laboratory before scenario A"
else
  log_warn "Reset omitido por configuración RESET_BEFORE_SCENARIO_A=false" "Reset skipped by configuration RESET_BEFORE_SCENARIO_A=false"
fi

run_existing_script "scripts/run/01-deploy-foundation.sh" "Desplegando foundation IIoT" "Deploying IIoT foundation"
run_existing_script "scripts/run/02-run-operational-baseline.sh" "Ejecutando baseline operacional" "Running operational baseline"
run_existing_script "scripts/run/03-freeze-operational-baseline.sh" "Congelando baseline operacional" "Freezing operational baseline"

if [[ "${VALIDATE_AFTER_SCENARIO}" == "true" ]]; then
  run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness posterior a escenario A" "Validating readiness after scenario A"
fi

log_step "Escenario A finalizado" "Scenario A completed"
