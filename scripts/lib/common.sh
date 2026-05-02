#!/usr/bin/env bash
set -euo pipefail

log(){ echo -e "\n\033[1;34m[INFO]\033[0m $1"; }
warn(){ echo -e "\n\033[1;33m[WARN]\033[0m $1"; }
fail(){ echo -e "\n\033[1;31m[ERROR]\033[0m $1"; exit 1; }

summary_header(){
  echo
  echo "============================================================"
  echo "[SUMMARY] $1"
  echo "============================================================"
}

summary_ok(){
  echo "[OK] $1"
}

summary_warn(){
  echo "[WARN] $1"
}

detect_kubectl(){
  if command -v kubectl >/dev/null 2>&1; then
    echo kubectl
  elif command -v microk8s >/dev/null 2>&1; then
    echo "microk8s kubectl"
  else
    fail "No se encontró kubectl ni microk8s kubectl."
  fi
}

ensure_mqtt_client(){
  if command -v mosquitto_sub >/dev/null 2>&1 && command -v mosquitto_pub >/dev/null 2>&1; then
    log "Clientes MQTT detectados."
  else
    warn "Instalando mosquitto-clients..."
    sudo apt-get update
    sudo apt-get install -y mosquitto-clients
  fi
}

wait_http(){
  local name="$1"
  local url="$2"
  local attempts="${3:-30}"
  local sleep_s="${4:-5}"

  log "Validando ${name}: ${url}"

  for i in $(seq 1 "$attempts"); do
    if curl -fsS --max-time 5 "$url" >/tmp/${name}.out 2>/tmp/${name}.err; then
      echo "[OK] ${name} respondió correctamente."
      cat /tmp/${name}.out
      echo
      return 0
    fi
    echo "[WAIT] ${name} aún no responde. Intento ${i}/${attempts}"
    sleep "$sleep_s"
  done

  fail "${name} no respondió en ${url}"
}

wait_mqtt(){
  local host="$1"
  local attempts="${2:-30}"
  local sleep_s="${3:-5}"

  ensure_mqtt_client

  log "Validando MQTT en ${host}:1883"

  for i in $(seq 1 "$attempts"); do
    if timeout 8 mosquitto_sub -h "$host" -t 'sensors/#' -C 1 >/tmp/mqtt_validation.out 2>/tmp/mqtt_validation.err; then
      echo "[OK] MQTT respondió correctamente."
      cat /tmp/mqtt_validation.out
      return 0
    fi
    echo "[WAIT] MQTT aún no entrega mensajes. Intento ${i}/${attempts}"
    sleep "$sleep_s"
  done

  fail "MQTT no respondió en ${host}:1883"
}

csv_has_data(){
  local file="$1"
  [[ -s "$file" ]] || fail "Archivo no existe o está vacío: $file"

  local lines
  lines=$(wc -l < "$file")

  [[ "$lines" -gt 1 ]] || fail "Archivo sin datos suficientes: $file"
  echo "[OK] $file tiene $lines líneas."
}
