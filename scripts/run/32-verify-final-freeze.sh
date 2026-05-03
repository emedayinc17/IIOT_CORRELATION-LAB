#!/usr/bin/env bash
set -euo pipefail

# Verifica el último paquete metodológico congelado usando SHA256SUMS | Verifies the latest frozen methodology package using SHA256SUMS
source scripts/lib/experiment-config.sh
load_experiment_config "config/experiment.conf"

latest_dir="$(latest_final_freeze_dir || true)"

if [[ -z "${latest_dir:-}" ]]; then
  log_warn "No se encontró directorio final_methodology_package_*" "No final_methodology_package_* directory found"
  exit 0
fi

if [[ ! -f "$latest_dir/SHA256SUMS" ]]; then
  log_warn "No se encontró SHA256SUMS en $latest_dir" "SHA256SUMS not found in $latest_dir"
  exit 0
fi

log_step "Verificando checksums en $latest_dir" "Verifying checksums in $latest_dir"
(
  cd "$latest_dir"
  sha256sum -c SHA256SUMS
)

log_step "Verificación SHA256 completada correctamente" "SHA256 verification completed successfully"
