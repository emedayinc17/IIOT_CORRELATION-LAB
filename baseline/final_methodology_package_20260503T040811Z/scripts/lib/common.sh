#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for IIoT Correlation Lab scripts.
# Ayudantes compartidos para los scripts del laboratorio IIoT.

LAB_TZ="${LAB_TZ:-America/Lima}"
_SCRIPT_START_EPOCH="${_SCRIPT_START_EPOCH:-$(date +%s)}"
_SCRIPT_NAME="${_SCRIPT_NAME:-$(basename "$0")}" 

_local_time(){ TZ="$LAB_TZ" date '+%Y-%m-%d %H:%M:%S %z'; }
_local_time_from_epoch(){ TZ="$LAB_TZ" date -d "@$1" '+%Y-%m-%d %H:%M:%S %z'; }
_duration_hms(){ local s="${1:-0}"; printf '%02dh:%02dm:%02ds' $((s/3600)) $(((s%3600)/60)) $((s%60)); }

# Legacy single-line helpers kept for older scripts.
log(){ echo -e "\n\033[1;34m[INFO]\033[0m $1"; }
warn(){ echo -e "\n\033[1;33m[WARN]\033[0m $1"; }
fail(){ local es="$1" en="${2:-$1}"; echo -e "\n\033[1;31m[ERROR]\033[0m ES: $es"; echo -e "\033[1;31m[ERROR]\033[0m EN: $en"; exit 1; }

# Bilingual concise helpers.
info(){ echo -e "\n\033[1;34m[INFO]\033[0m ES: $1"; echo -e "\033[1;34m[INFO]\033[0m EN: $2"; }
step(){ echo -e "\n[STEP] ES: $1"; echo "[STEP] EN: $2"; }
warn_bi(){ echo -e "\n\033[1;33m[WARN]\033[0m ES: $1"; echo -e "\033[1;33m[WARN]\033[0m EN: $2"; }
error_bi(){ fail "$1" "$2"; }

phase(){
  local label="$1" es="$2" en="$3"
  echo
  echo "------------------------------------------------------------"
  echo "[PHASE ${label}] ES: ${es}"
  echo "[PHASE ${label}] EN: ${en}"
  echo "------------------------------------------------------------"
}

execution_window(){
  local estimated_seconds="$1" es="$2" en="$3"
  local start_epoch
  local finish_epoch
  start_epoch="${_SCRIPT_START_EPOCH:-$(date +%s)}"
  finish_epoch=$((start_epoch + estimated_seconds))
  echo
  echo "============================================================"
  echo "[EXECUTION WINDOW]"
  echo "ES: ${es}"
  echo "EN: ${en}"
  echo "Hora de inicio / Start time: $(_local_time_from_epoch "$start_epoch") (${LAB_TZ})"
  echo "Duración estimada / Estimated duration: $(_duration_hms "$estimated_seconds")"
  echo "Fin estimado / Estimated finish: $(_local_time_from_epoch "$finish_epoch") (${LAB_TZ})"
  echo "============================================================"
}

_script_objective_es(){
  case "$1" in
    00-reset-lab.sh) echo "Reiniciar el laboratorio y limpiar resultados transitorios.";;
    01-deploy-foundation.sh) echo "Desplegar servicios IIoT base.";;
    02-run-operational-baseline.sh) echo "Capturar baseline operacional del Escenario A.";;
    03-freeze-operational-baseline.sh) echo "Congelar el Escenario A.";;
    04-deploy-zabbix.sh) echo "Desplegar Zabbix persistente.";;
    04-reset-zabbix.sh) echo "Eliminar despliegue Zabbix.";;
    05-validate-zabbix.sh) echo "Validar despliegue Zabbix.";;
    06-configure-zabbix-monitoring.sh) echo "Configurar Zabbix con métricas IIoT reales.";;
    07-run-zabbix-operational-baseline.sh) echo "Capturar baseline operacional con Zabbix.";;
    08-freeze-zabbix-operational-baseline.sh) echo "Congelar el Escenario B.";;
    09-export-lab-inventory.sh) echo "Exportar inventario del laboratorio.";;
    10-export-zabbix-configuration.sh) echo "Exportar configuración Zabbix.";;
    11-deploy-wazuh-security.sh) echo "Desplegar o reconciliar Wazuh single-node.";;
    12-validate-wazuh-security.sh) echo "Validar Wazuh, Dashboard, API y reglas.";;
    13-run-wazuh-security-baseline.sh) echo "Generar baseline de seguridad Wazuh.";;
    14-freeze-wazuh-security-baseline.sh) echo "Congelar el Escenario C.";;
    15-run-mitre-ics-attacks.sh) echo "Ejecutar ataques MITRE ICS controlados.";;
    16-run-correlation-experiment.sh) echo "Correlacionar Wazuh con métricas reales Zabbix.";;
    17-export-final-datasets.sh) echo "Generar datasets, tablas y figuras finales.";;
    18-freeze-correlation-results.sh) echo "Congelar resultados finales del Escenario D.";;
    *) echo "Ejecutar tarea del laboratorio reproducible.";;
  esac
}
_script_objective_en(){
  case "$1" in
    00-reset-lab.sh) echo "Reset the lab and clear transient results.";;
    01-deploy-foundation.sh) echo "Deploy base IIoT services.";;
    02-run-operational-baseline.sh) echo "Capture Scenario A operational baseline.";;
    03-freeze-operational-baseline.sh) echo "Freeze Scenario A.";;
    04-deploy-zabbix.sh) echo "Deploy persistent Zabbix.";;
    04-reset-zabbix.sh) echo "Remove Zabbix deployment.";;
    05-validate-zabbix.sh) echo "Validate Zabbix deployment.";;
    06-configure-zabbix-monitoring.sh) echo "Configure Zabbix with real IIoT metrics.";;
    07-run-zabbix-operational-baseline.sh) echo "Capture operational baseline with Zabbix.";;
    08-freeze-zabbix-operational-baseline.sh) echo "Freeze Scenario B.";;
    09-export-lab-inventory.sh) echo "Export lab inventory.";;
    10-export-zabbix-configuration.sh) echo "Export Zabbix configuration.";;
    11-deploy-wazuh-security.sh) echo "Deploy or reconcile single-node Wazuh.";;
    12-validate-wazuh-security.sh) echo "Validate Wazuh, Dashboard, API, and rules.";;
    13-run-wazuh-security-baseline.sh) echo "Generate Wazuh security baseline.";;
    14-freeze-wazuh-security-baseline.sh) echo "Freeze Scenario C.";;
    15-run-mitre-ics-attacks.sh) echo "Run controlled MITRE ICS attacks.";;
    16-run-correlation-experiment.sh) echo "Correlate Wazuh with real Zabbix metrics.";;
    17-export-final-datasets.sh) echo "Generate final datasets, tables, and figures.";;
    18-freeze-correlation-results.sh) echo "Freeze final Scenario D results.";;
    *) echo "Run a reproducible lab task.";;
  esac
}

script_end(){
  local rc="$?" end_epoch elapsed
  end_epoch="$(date +%s)"; elapsed=$((end_epoch - _SCRIPT_START_EPOCH))
  echo
  echo "============================================================"
  echo "[EXECUTION END]"
  echo "Script: ${_SCRIPT_NAME}"
  echo "Hora de fin / End time: $(_local_time_from_epoch "$end_epoch") (${LAB_TZ})"
  echo "Duración real / Actual duration: $(_duration_hms "$elapsed")"
  echo "Exit code: ${rc}"
  if [[ "$rc" -eq 0 ]]; then
    echo "ES: Ejecución finalizada correctamente."
    echo "EN: Execution completed successfully."
  else
    echo "ES: Ejecución finalizada con error; revisar el último mensaje y evidencia generada."
    echo "EN: Execution finished with an error; review the latest message and generated evidence."
  fi
  echo "============================================================"
  exit "$rc"
}

script_start(){
  _SCRIPT_NAME="${1:-$(basename "$0")}"; _SCRIPT_START_EPOCH="$(date +%s)"
  trap script_end EXIT
  echo
  echo "============================================================"
  echo "[SCRIPT START] ${_SCRIPT_NAME}"
  echo "Hora de inicio / Start time: $(_local_time_from_epoch "$_SCRIPT_START_EPOCH") (${LAB_TZ})"
  echo "ES: $(_script_objective_es "$_SCRIPT_NAME")"
  echo "EN: $(_script_objective_en "$_SCRIPT_NAME")"
  echo "============================================================"
}

wait_countdown(){
  local total="$1" interval="${2:-10}" es="$3" en="$4"
  local remaining="$total"
  info "$es" "$en"
  while [[ "$remaining" -gt 0 ]]; do
    echo "[WAIT] ES: faltan aproximadamente ${remaining}s"
    echo "[WAIT] EN: approximately ${remaining}s remaining"
    sleep "$interval"
    remaining=$((remaining - interval))
  done
}

summary_header(){ echo; echo "============================================================"; echo "[SUMMARY] $1"; echo "============================================================"; }
summary_ok(){ local es="$1" en="${2:-$1}"; echo "[OK] ES: $es"; echo "[OK] EN: $en"; }
summary_warn(){ local es="$1" en="${2:-$1}"; echo "[WARN] ES: $es"; echo "[WARN] EN: $en"; }

csv_has_data(){ local file="$1"; [[ -f "$file" ]] || fail "No existe $file" "File $file does not exist"; local lines; lines=$(wc -l < "$file"); [[ "$lines" -gt 1 ]] || fail "$file no contiene datos" "$file has no data"; summary_ok "$file tiene ${lines} líneas." "$file has ${lines} lines."; }

detect_kubectl(){
  if command -v kubectl >/dev/null 2>&1; then echo kubectl; elif command -v microk8s >/dev/null 2>&1; then echo "microk8s kubectl"; else fail "No se encontró kubectl ni microk8s kubectl." "Neither kubectl nor microk8s kubectl was found."; fi
}

ensure_mqtt_client(){
  if command -v mosquitto_sub >/dev/null 2>&1 && command -v mosquitto_pub >/dev/null 2>&1; then log "Clientes MQTT detectados."; else warn "Instalando mosquitto-clients..."; sudo apt-get update; sudo apt-get install -y mosquitto-clients; fi
}

wait_http(){
  local name="$1" url="$2" attempts="${3:-30}" sleep_s="${4:-5}"
  log "Validando ${name}: ${url}"
  for i in $(seq 1 "$attempts"); do
    if curl -fsS --max-time 5 "$url" >/tmp/${name}.out 2>/tmp/${name}.err; then echo "[OK] ${name} respondió correctamente."; cat /tmp/${name}.out; echo; return 0; fi
    echo "[WAIT] ${name} aún no responde. Intento ${i}/${attempts}"; sleep "$sleep_s"
  done
  cat /tmp/${name}.err 2>/dev/null || true
  fail "${name} no respondió: ${url}" "${name} did not respond: ${url}"
}
