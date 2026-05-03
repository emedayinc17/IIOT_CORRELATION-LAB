#!/usr/bin/env bash
set -euo pipefail

# Valida readiness del laboratorio sin ejecutar campañas destructivas | Validates laboratory readiness without running destructive campaigns
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Iniciando validación paper-readiness" "Starting paper-readiness validation"
require_command kubectl

log_step "Validando nodo Kubernetes" "Validating Kubernetes node"
kubectl get nodes -o wide

log_step "Validando namespaces principales" "Validating main namespaces"
kubectl get ns "$IIOT_NAMESPACE" "$MONITORING_NAMESPACE" "$SECURITY_NAMESPACE" "$EXPERIMENTS_NAMESPACE" 2>/dev/null || true

log_step "Validando servicios IIoT" "Validating IIoT services"
kubectl -n "$IIOT_NAMESPACE" get all -o wide

log_step "Validando monitoreo Zabbix" "Validating Zabbix monitoring"
kubectl -n "$MONITORING_NAMESPACE" get all -o wide

log_step "Validando seguridad Wazuh" "Validating Wazuh security"
kubectl -n "$SECURITY_NAMESPACE" get all -o wide

run_optional_script "scripts/run/28-validate-scenario-readiness.sh" "Ejecutando validador A-E existente" "Running existing A-E validator"

for file in "$ATTACK_DETECTION_TABLE" "$TEMPORAL_CORRELATION_TABLE" "$MTTD_TABLE" "$BOOTSTRAP_CI_TABLE" "$NOISE_FPR_TABLE" "$NOISE_WILSON_TABLE" "$SCENARIO_READINESS_TABLE"; do
  if [[ -f "$file" ]]; then
    log_step "Tabla encontrada: $file" "Table found: $file"
  else
    log_warn "Tabla pendiente o no encontrada: $file" "Table pending or not found: $file"
  fi
done

if [[ -d "results/figures" ]]; then
  log_step "Directorio de figuras encontrado" "Figures directory found"
  ls -1 results/figures || true
else
  log_warn "Directorio de figuras no encontrado" "Figures directory not found"
fi

run_optional_script "scripts/run/32-verify-final-freeze.sh" "Verificando freeze final si existe" "Verifying final freeze if available"
log_step "Validación paper-readiness finalizada" "Paper-readiness validation completed"
