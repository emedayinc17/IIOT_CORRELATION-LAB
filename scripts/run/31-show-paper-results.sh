#!/usr/bin/env bash
set -euo pipefail

# Muestra resultados principales sin ejecutar ataques ni ruido | Shows main results without running attacks or noise
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

log_step "Mostrando resultados principales del laboratorio" "Showing main laboratory results"

for file in "$SCENARIO_READINESS_TABLE" "$ATTACK_DETECTION_TABLE" "$TEMPORAL_CORRELATION_TABLE" "$MTTD_TABLE" "$BOOTSTRAP_CI_TABLE" "$NOISE_FPR_TABLE" "$NOISE_WILSON_TABLE"; do
  if [[ -f "$file" ]]; then
    log_step "Vista rápida de $file" "Quick view of $file"
    sed -n '1,12p' "$file"
  else
    log_warn "Archivo no encontrado: $file" "File not found: $file"
  fi
done

if [[ -d "results/figures" ]]; then
  log_step "Figuras disponibles" "Available figures"
  ls -1 results/figures
fi

latest_dir="$(latest_final_freeze_dir || true)"
latest_tar="$(latest_final_freeze_tar || true)"

if [[ -n "${latest_dir:-}" ]]; then
  echo "FREEZE: Directorio final | FREEZE: Final directory -> ${latest_dir}"
fi

if [[ -n "${latest_tar:-}" ]]; then
  echo "FREEZE: Archivo comprimido final | FREEZE: Final archive -> ${latest_tar}"
fi

log_step "Visualización de resultados finalizada" "Results view completed"
