#!/usr/bin/env bash
set -euo pipefail

# Carga la configuración central del laboratorio | Loads the central laboratory configuration
load_experiment_config() {
  local config_file="${1:-config/experiment.conf}"
  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: No se encontró $config_file | ERROR: $config_file was not found"
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$config_file"
}

# Imprime mensajes compactos bilingües en una línea | Prints compact bilingual messages in one line
log_step() {
  local es="$1"
  local en="$2"
  echo "INFO: ${es} | ${en}"
}

# Imprime advertencias compactas bilingües en una línea | Prints compact bilingual warnings in one line
log_warn() {
  local es="$1"
  local en="$2"
  echo "WARN: ${es} | ${en}"
}

# Imprime errores compactos bilingües en una línea | Prints compact bilingual errors in one line
log_error() {
  local es="$1"
  local en="$2"
  echo "ERROR: ${es} | ${en}" >&2
}

# Ejecuta un script existente validando que exista | Executes an existing script after checking it exists
run_existing_script() {
  local script_path="$1"
  local es="$2"
  local en="$3"
  if [[ ! -x "$script_path" ]]; then
    log_error "No existe o no es ejecutable: $script_path" "Missing or not executable: $script_path"
    exit 1
  fi
  log_step "$es" "$en"
  "$script_path"
}

# Ejecuta un script opcional si existe | Executes an optional script if it exists
run_optional_script() {
  local script_path="$1"
  local es="$2"
  local en="$3"
  if [[ -x "$script_path" ]]; then
    log_step "$es" "$en"
    "$script_path"
  else
    log_warn "Script opcional no encontrado: $script_path" "Optional script not found: $script_path"
  fi
}

# Verifica comandos requeridos para la ejecución | Checks required commands for execution
require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Comando requerido no disponible: $cmd" "Required command not available: $cmd"
    exit 1
  fi
}

# Obtiene el último directorio de freeze final disponible | Gets the latest available final freeze directory
latest_final_freeze_dir() {
  find "${BASELINE_DIR:-baseline}" -maxdepth 1 -type d -name "final_methodology_package_*" 2>/dev/null | sort | tail -1
}

# Obtiene el último archivo tar.gz de freeze final disponible | Gets the latest available final freeze tar.gz
latest_final_freeze_tar() {
  find "${BASELINE_DIR:-baseline}" -maxdepth 1 -type f -name "final_methodology_package_*.tar.gz" 2>/dev/null | sort | tail -1
}
