#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el escenario D agrupando ataques MITRE, correlación, exportación y estadística | Runs scenario D by grouping MITRE attacks, correlation, export, and statistics
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando escenario D - MITRE ICS Correlation" "Starting scenario D - MITRE ICS Correlation"
require_command kubectl

log_step "Parámetros D: técnicas=${MITRE_TECHNIQUES}, corridas_por_técnica=${RUNS_PER_TECHNIQUE}, ventana_correlación=${CORRELATION_WINDOW_SECONDS}s" "D parameters: techniques=${MITRE_TECHNIQUES}, runs_per_technique=${RUNS_PER_TECHNIQUE}, correlation_window=${CORRELATION_WINDOW_SECONDS}s"

run_existing_script "scripts/run/15-run-mitre-ics-attacks.sh" "Ejecutando ataques MITRE ICS" "Running MITRE ICS attacks"
run_existing_script "scripts/run/16-run-correlation-experiment.sh" "Ejecutando experimento de correlación" "Running correlation experiment"
run_existing_script "scripts/run/17-export-final-datasets.sh" "Exportando datasets finales" "Exporting final datasets"
run_existing_script "scripts/run/18-freeze-correlation-results.sh" "Congelando resultados de correlación" "Freezing correlation results"
run_existing_script "scripts/run/19-normalize-experimental-datasets.sh" "Normalizando datasets experimentales" "Normalizing experimental datasets"
run_existing_script "scripts/run/20-generate-experimental-metadata.sh" "Generando metadata experimental" "Generating experimental metadata"
run_existing_script "scripts/run/21-analyze-temporal-correlation.sh" "Analizando correlación temporal" "Analyzing temporal correlation"
run_existing_script "scripts/run/22-run-statistical-analysis.sh" "Ejecutando análisis estadístico" "Running statistical analysis"

if [[ "${VALIDATE_AFTER_SCENARIO}" == "true" ]]; then
  run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness posterior a escenario D" "Validating readiness after scenario D"
fi

log_step "Escenario D finalizado" "Scenario D completed"
