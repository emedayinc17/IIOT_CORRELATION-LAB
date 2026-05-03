#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el escenario E agrupando ruido operacional, FPR, freeze y documentación | Runs scenario E by grouping operational noise, FPR, freeze, and documentation
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando escenario E - Operational Noise/FPR" "Starting scenario E - Operational Noise/FPR"
require_command kubectl

log_step "Parámetros E: perfiles=${NOISE_PROFILES}, corridas_por_perfil=${RUNS_PER_NOISE_PROFILE}" "E parameters: profiles=${NOISE_PROFILES}, runs_per_profile=${RUNS_PER_NOISE_PROFILE}"

run_existing_script "scripts/run/23-run-operational-noise-control.sh" "Ejecutando ruido operacional legítimo" "Running legitimate operational noise"
run_existing_script "scripts/run/24-analyze-false-positive-rate.sh" "Analizando FPR" "Analyzing FPR"
run_existing_script "scripts/run/25-freeze-noise-control-results.sh" "Congelando resultados de ruido" "Freezing noise results"
run_existing_script "scripts/run/26-apply-scenario-e-documentation-updates.sh" "Actualizando documentación del escenario E" "Updating scenario E documentation"

if [[ "${VALIDATE_AFTER_SCENARIO}" == "true" ]]; then
  run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness posterior a escenario E" "Validating readiness after scenario E"
fi

log_step "Escenario E finalizado" "Scenario E completed"
