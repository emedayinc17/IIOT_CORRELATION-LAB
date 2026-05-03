#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el escenario B agrupando despliegue, validación, configuración y freeze de Zabbix | Runs scenario B by grouping Zabbix deployment, validation, configuration, and freeze
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando escenario B - Zabbix Monitoring" "Starting scenario B - Zabbix Monitoring"
require_command kubectl

run_existing_script "scripts/run/04-deploy-zabbix.sh" "Desplegando Zabbix" "Deploying Zabbix"
run_existing_script "scripts/run/05-validate-zabbix.sh" "Validando Zabbix" "Validating Zabbix"
run_existing_script "scripts/run/06-configure-zabbix-monitoring.sh" "Configurando monitoreo Zabbix" "Configuring Zabbix monitoring"
run_existing_script "scripts/run/07-run-zabbix-operational-baseline.sh" "Ejecutando baseline operacional con Zabbix" "Running Zabbix operational baseline"
run_existing_script "scripts/run/08-freeze-zabbix-operational-baseline.sh" "Congelando baseline Zabbix" "Freezing Zabbix baseline"
run_existing_script "scripts/run/09-export-lab-inventory.sh" "Exportando inventario del laboratorio" "Exporting laboratory inventory"
run_existing_script "scripts/run/10-export-zabbix-configuration.sh" "Exportando configuración Zabbix" "Exporting Zabbix configuration"

if [[ "${VALIDATE_AFTER_SCENARIO}" == "true" ]]; then
  run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Validando readiness posterior a escenario B" "Validating readiness after scenario B"
fi

log_step "Escenario B finalizado" "Scenario B completed"
