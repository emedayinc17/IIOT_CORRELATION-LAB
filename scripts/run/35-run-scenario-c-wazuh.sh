#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el escenario C agrupando despliegue, validación, baseline y freeze Wazuh | Runs scenario C by grouping Wazuh deployment, validation, baseline, and freeze
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando escenario C - Wazuh Security" "Starting scenario C - Wazuh Security"
require_command kubectl

run_existing_script "scripts/run/11-deploy-wazuh-security.sh" "Desplegando Wazuh Security" "Deploying Wazuh Security"
run_existing_script "scripts/run/12-validate-wazuh-security.sh" "Validando Wazuh Security" "Validating Wazuh Security"
run_existing_script "scripts/run/13-run-wazuh-security-baseline.sh" "Ejecutando baseline de seguridad Wazuh" "Running Wazuh security baseline"
run_existing_script "scripts/run/14-freeze-wazuh-security-baseline.sh" "Congelando baseline Wazuh" "Freezing Wazuh baseline"

if [[ "${VALIDATE_AFTER_SCENARIO}" == "true" ]]; then
  run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness posterior a escenario C" "Validating readiness after scenario C"
fi

log_step "Escenario C finalizado" "Scenario C completed"
