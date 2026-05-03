#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMMON_SH="$ROOT_DIR/scripts/lib/common.sh"
if [[ -f "$COMMON_SH" ]]; then
  # shellcheck source=/dev/null
  source "$COMMON_SH" || true
fi

SCRIPT_NAME="15-run-mitre-ics-attacks.sh"
TZ_NAME="${TZ_NAME:-America/Lima}"
export TZ="$TZ_NAME"
SCRIPT_START_EPOCH="$(date +%s)"

# -----------------------------
# Parameters
# -----------------------------
KUBE_CMD="${KUBE_CMD:-microk8s kubectl}"
SECURITY_NS="${SECURITY_NS:-security}"
IIOT_NS="${IIOT_NS:-iiot-poc}"
MANAGER_POD="${MANAGER_POD:-wazuh-manager-master-0}"
WAZUH_LOCALFILE_PATH="${WAZUH_LOCALFILE_PATH:-/var/ossec/logs/iiot-lab/scenario_d_attacks.json}"
WAZUH_OSSEC_CONF="${WAZUH_OSSEC_CONF:-/var/ossec/etc/ossec.conf}"
SKIP_WAZUH_RESTART="${SKIP_WAZUH_RESTART:-0}"
WAZUH_RECOVERY_TIMEOUT_SECONDS="${WAZUH_RECOVERY_TIMEOUT_SECONDS:-180}"

ITERATIONS="${ITERATIONS:-20}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"
BASELINE_WARMUP_SECONDS="${BASELINE_WARMUP_SECONDS:-60}"
INTER_ATTACK_COOLDOWN_SECONDS="${INTER_ATTACK_COOLDOWN_SECONDS:-10}"
DOS_REQUESTS="${DOS_REQUESTS:-500}"
DOS_CONCURRENCY="${DOS_CONCURRENCY:-30}"
ATTACK_DURATION_SECONDS="${ATTACK_DURATION_SECONDS:-30}"
HTTP_PROBE_INTERVAL_SECONDS="${HTTP_PROBE_INTERVAL_SECONDS:-2}"

MQTT_HOST="${MQTT_HOST:-10.10.0.151}"
MQTT_PORT="${MQTT_PORT:-1883}"
HEALTH_HOST="${HEALTH_HOST:-10.10.0.152}"
TELEMETRY_HOST="${TELEMETRY_HOST:-10.10.0.153}"
VULN_HOST="${VULN_HOST:-10.10.0.154}"
HTTP_PORT="${HTTP_PORT:-8080}"

RAW_DIR="$ROOT_DIR/results/raw/scenario_d"
EVIDENCE_DIR="$ROOT_DIR/evidence/wazuh"
mkdir -p "$RAW_DIR" "$EVIDENCE_DIR"
ATTACKS_CSV="$RAW_DIR/mitre_ics_attacks.csv"
HTTP_OBS_CSV="$RAW_DIR/attack_http_observations.csv"
RUN_TS="$(date +%Y%m%dT%H%M%S%z)"

# -----------------------------
# Output helpers, standalone-safe
# -----------------------------
now_local() { TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %z (%Z)'; }
now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
fmt_duration() { local s="${1:-0}"; printf '%02dh:%02dm:%02ds' $((s/3600)) $(((s%3600)/60)) $((s%60)); }
finish_time() { local add="${1:-0}"; TZ="$TZ_NAME" date -d "@$((SCRIPT_START_EPOCH + add))" '+%Y-%m-%d %H:%M:%S %z (%Z)'; }

say_info() { printf '\n[INFO] ES: %s\n[INFO] EN: %s\n' "$1" "$2"; }
say_step() { printf '\n[STEP] ES: %s\n[STEP] EN: %s\n' "$1" "$2"; }
say_ok() { printf '[OK] ES: %s\n[OK] EN: %s\n' "$1" "$2"; }
say_warn() { printf '\n[WARN] ES: %s\n[WARN] EN: %s\n' "$1" "$2"; }
say_error() { printf '\n[ERROR] ES: %s\n[ERROR] EN: %s\n' "$1" "$2" >&2; }
phase() { printf '\n------------------------------------------------------------\n[PHASE %s/5] ES: %s\n[PHASE %s/5] EN: %s\n------------------------------------------------------------\n' "$1" "$2" "$1" "$3"; }

script_end() {
  local ec=$?
  local end_epoch elapsed
  end_epoch="$(date +%s)"
  elapsed=$((end_epoch - SCRIPT_START_EPOCH))
  printf '\n============================================================\n'
  printf '[EXECUTION END]\nScript: %s\n' "$SCRIPT_NAME"
  printf 'Hora de fin / End time: %s\n' "$(now_local)"
  printf 'Duración real / Actual duration: %s\n' "$(fmt_duration "$elapsed")"
  printf 'Exit code: %s\n' "$ec"
  if [[ "$ec" -eq 0 ]]; then
    printf 'ES: Ejecución finalizada correctamente.\nEN: Execution completed successfully.\n'
  else
    printf 'ES: Ejecución finalizada con error; revisar el último mensaje y evidencia generada.\nEN: Execution finished with an error; review the latest message and generated evidence.\n'
  fi
  printf '============================================================\n'
}
trap script_end EXIT
on_error() {
  local ec="$?" line="${BASH_LINENO[0]:-unknown}" cmd="${BASH_COMMAND:-unknown}"
  printf '
[ERROR] ES: Fallo controlado en línea %s. Código=%s. Comando=%s
' "$line" "$ec" "$cmd" >&2
  printf '[ERROR] EN: Controlled failure at line %s. Code=%s. Command=%s
' "$line" "$ec" "$cmd" >&2
  printf '[HINT] ES: Revisar evidence/wazuh/ y results/raw/scenario_d/ para evidencia parcial.
' >&2
  printf '[HINT] EN: Check evidence/wazuh/ and results/raw/scenario_d/ for partial evidence.
' >&2
}
trap on_error ERR

estimated_seconds=$(( BASELINE_WARMUP_SECONDS + ITERATIONS * (ATTACK_DURATION_SECONDS + INTER_ATTACK_COOLDOWN_SECONDS + SLEEP_SECONDS + 35) + 120 ))

printf '\n============================================================\n'
printf '[SCRIPT START] %s\n' "$SCRIPT_NAME"
printf 'Hora de inicio / Start time: %s\n' "$(now_local)"
printf 'ES: Ejecutar ataques MITRE ICS controlados.\n'
printf 'EN: Run controlled MITRE ICS attacks.\n'
printf '============================================================\n'
printf '\n============================================================\n'
printf '[EXECUTION WINDOW]\n'
printf 'ES: Campaña D calibrada: warmup, iteraciones, ataques/cooldowns y exportación de evidencia.\n'
printf 'EN: Calibrated Scenario D campaign: warmup, iterations, attacks/cooldowns, and evidence export.\n'
printf 'Hora de inicio / Start time: %s\n' "$(now_local)"
printf 'Duración estimada / Estimated duration: %s\n' "$(fmt_duration "$estimated_seconds")"
printf 'Fin estimado / Estimated finish: %s\n' "$(finish_time "$estimated_seconds")"
printf '============================================================\n'

say_info "Parámetros: iteraciones=${ITERATIONS}, warmup=${BASELINE_WARMUP_SECONDS}s, cooldown=${INTER_ATTACK_COOLDOWN_SECONDS}s, DoS=${DOS_REQUESTS} requests/${DOS_CONCURRENCY} concurrencia/${ATTACK_DURATION_SECONDS}s." \
         "Parameters: iterations=${ITERATIONS}, warmup=${BASELINE_WARMUP_SECONDS}s, cooldown=${INTER_ATTACK_COOLDOWN_SECONDS}s, DoS=${DOS_REQUESTS} requests/${DOS_CONCURRENCY} concurrency/${ATTACK_DURATION_SECONDS}s."

# -----------------------------
# Low-level helpers
# -----------------------------
run_kubectl() { $KUBE_CMD "$@"; }
manager_exec() { run_kubectl exec -n "$SECURITY_NS" "$MANAGER_POD" -- "$@"; }

wait_countdown() {
  local seconds="$1" es="$2" en="$3" step="${4:-10}" remaining
  remaining="$seconds"
  while (( remaining > 0 )); do
    printf '[WAIT] ES: %s Restante: %ss\n[WAIT] EN: %s Remaining: %ss\n' "$es" "$remaining" "$en" "$remaining"
    sleep "$step"
    remaining=$((remaining - step))
    if (( remaining < 0 )); then remaining=0; fi
  done
}

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "$1"; }

write_wazuh_event() {
  local attack_uid="$1" attack_id="$2" technique="$3" component="$4" event_type="$5" severity="$6" detail="$7"
  local ts tmp_event err_file ec
  ts="$(now_utc)"
  tmp_event="$(mktemp)"
  err_file="$EVIDENCE_DIR/${RUN_TS}-${attack_uid}-wazuh-event-write.err"

  python3 - "$ts" "$attack_uid" "$attack_id" "$technique" "$component" "$event_type" "$severity" "$detail" > "$tmp_event" <<'PY_EVENT'
import json, sys
(ts, attack_uid, attack_id, technique, component, event_type, severity, detail) = sys.argv[1:]
event = {
    "timestamp": ts,
    "iiot_lab": {
        "scenario": "SCENARIO_D",
        "attack_uid": attack_uid,
        "attack_id": attack_id,
        "mitre_ics": attack_id,
        "technique": technique,
        "component": component,
        "event_type": event_type,
        "severity": severity,
        "detail": detail,
    },
}
print(json.dumps(event, separators=(",", ":"), ensure_ascii=False))
PY_EVENT

  # Use stdin instead of complex nested shell quoting. This avoids silent failures in kubectl exec.
  set +e
  $KUBE_CMD exec -i -n "$SECURITY_NS" "$MANAGER_POD" -- sh -c "mkdir -p /var/ossec/logs/iiot-lab && touch '$WAZUH_LOCALFILE_PATH' && (chown wazuh:wazuh '$WAZUH_LOCALFILE_PATH' 2>/dev/null || true) && cat >> '$WAZUH_LOCALFILE_PATH'" < "$tmp_event" 2>"$err_file"
  ec=$?
  set -e
  rm -f "$tmp_event"
  if [[ "$ec" -ne 0 ]]; then
    say_error "No se pudo escribir evento Wazuh $attack_uid. Evidencia: ${err_file#$ROOT_DIR/}"               "Could not write Wazuh event $attack_uid. Evidence: ${err_file#$ROOT_DIR/}"
    return "$ec"
  fi
}

http_probe() {
  local url="$1"
  curl -sS -o /dev/null -w '%{http_code},%{time_total}\n' --max-time 5 "$url" 2>/dev/null || printf '000,5.000000\n'
  return 0
}

read_http_probe() {
  local url="$1" out code latency
  out="$(http_probe "$url" 2>/dev/null || true)"
  if [[ -z "$out" ]]; then
    code="000"
    latency="5.000000"
  else
    IFS=, read -r code latency <<< "$out" || true
    code="${code:-000}"
    latency="${latency:-5.000000}"
  fi
  printf '%s,%s\n' "$code" "$latency"
  return 0
}

run_parallel_http_flood() {
  local url="$1" requests="$2" concurrency="$3" duration="$4"
  local end_epoch pids=() idx=0
  end_epoch=$(( $(date +%s) + duration ))
  while (( idx < concurrency )); do
    (
      local count=0
      while (( $(date +%s) < end_epoch )) && (( count < requests / concurrency + 1 )); do
        curl -sS -o /dev/null --max-time 2 "$url" >/dev/null 2>&1 || true
        count=$((count+1))
      done
    ) &
    pids+=("$!")
    idx=$((idx+1))
  done
  for p in "${pids[@]}"; do wait "$p" || true; done
}

ensure_wazuh_localfile() {
  phase 1 "Preparar Wazuh localfile para eventos SCENARIO_D." "Prepare Wazuh localfile for SCENARIO_D events."
  say_step "Verificando localfile en ossec.conf; si ya existe, se omite reinicio." \
           "Checking localfile in ossec.conf; if it already exists, restart is skipped."

  if timeout 20s $KUBE_CMD exec -n "$SECURITY_NS" "$MANAGER_POD" -- sh -c "grep -q '$WAZUH_LOCALFILE_PATH' '$WAZUH_OSSEC_CONF'" >/dev/null 2>"$EVIDENCE_DIR/${RUN_TS}-scenario-d-localfile-check.err"; then
    say_ok "El localfile SCENARIO_D ya existe; no se reinicia Wazuh." "SCENARIO_D localfile already exists; Wazuh restart is skipped."
    manager_exec sh -c "mkdir -p /var/ossec/logs/iiot-lab && touch '$WAZUH_LOCALFILE_PATH' && chown wazuh:wazuh '$WAZUH_LOCALFILE_PATH' 2>/dev/null || true"
    return 0
  fi

  say_step "Localfile no encontrado. Insertando configuración dentro de ossec.conf." \
           "Localfile not found. Inserting configuration inside ossec.conf."

  timeout 30s $KUBE_CMD exec -n "$SECURITY_NS" "$MANAGER_POD" -- sh -c "
    set -eu
    mkdir -p /var/ossec/logs/iiot-lab
    touch '$WAZUH_LOCALFILE_PATH'
    chown wazuh:wazuh '$WAZUH_LOCALFILE_PATH' 2>/dev/null || true
    cp '$WAZUH_OSSEC_CONF' '${WAZUH_OSSEC_CONF}.scenario_d.bak.$RUN_TS'
    if ! grep -q '$WAZUH_LOCALFILE_PATH' '$WAZUH_OSSEC_CONF'; then
      awk '
        /<\/ossec_config>/ && !done {
          print "  <localfile>";
          print "    <log_format>json</log_format>";
          print "    <location>$WAZUH_LOCALFILE_PATH</location>";
          print "  </localfile>";
          done=1
        }
        { print }
      ' '$WAZUH_OSSEC_CONF' > /tmp/ossec.conf.scenario_d
      cat /tmp/ossec.conf.scenario_d > '$WAZUH_OSSEC_CONF'
    fi
  "

  if [[ "$SKIP_WAZUH_RESTART" == "1" ]]; then
    say_warn "SKIP_WAZUH_RESTART=1 activo; no se reinicia Wazuh. Asegúrate de que el localfile ya esté cargado." \
             "SKIP_WAZUH_RESTART=1 is active; Wazuh will not be restarted. Ensure the localfile is already loaded."
    return 0
  fi

  say_step "Reiniciando Wazuh Manager en segundo plano; se validará salud real después del reinicio." \
           "Restarting Wazuh Manager in background; real health will be validated after restart."
  set +e
  timeout 20s $KUBE_CMD exec -n "$SECURITY_NS" "$MANAGER_POD" -- sh -c "nohup /var/ossec/bin/wazuh-control restart >/tmp/scenario_d_wazuh_restart.log 2>&1 &" >/dev/null 2>"$EVIDENCE_DIR/${RUN_TS}-scenario-d-wazuh-restart-dispatch.err"
  local dispatch_ec=$?
  set -e
  if [[ "$dispatch_ec" -ne 0 ]]; then
    say_warn "El despacho del restart devolvió código $dispatch_ec; se validará el estado real de Wazuh antes de fallar." \
             "Restart dispatch returned code $dispatch_ec; real Wazuh health will be validated before failing."
  fi

  local deadline=$(( $(date +%s) + WAZUH_RECOVERY_TIMEOUT_SECONDS ))
  local ok=0
  while (( $(date +%s) < deadline )); do
    if $KUBE_CMD exec -n "$SECURITY_NS" "$MANAGER_POD" -- sh -c "/var/ossec/bin/wazuh-control status 2>/dev/null | grep -Eq 'wazuh-analysisd.*running|wazuh-apid.*running|wazuh-logcollector.*running'" >/dev/null 2>&1; then
      ok=1
      break
    fi
    printf '[WAIT] ES: Esperando recuperación de Wazuh Manager.\n[WAIT] EN: Waiting for Wazuh Manager recovery.\n'
    sleep 10
  done
  if [[ "$ok" -ne 1 ]]; then
    $KUBE_CMD exec -n "$SECURITY_NS" "$MANAGER_POD" -- sh -c "/var/ossec/bin/wazuh-control status || true; tail -80 /tmp/scenario_d_wazuh_restart.log 2>/dev/null || true" > "$EVIDENCE_DIR/${RUN_TS}-scenario-d-wazuh-restart-status.txt" 2>&1 || true
    say_error "Wazuh Manager no quedó saludable luego del restart. Evidencia: evidence/wazuh/${RUN_TS}-scenario-d-wazuh-restart-status.txt" \
              "Wazuh Manager did not become healthy after restart. Evidence: evidence/wazuh/${RUN_TS}-scenario-d-wazuh-restart-status.txt"
    exit 1
  fi
  say_ok "Wazuh Manager recuperado y localfile SCENARIO_D configurado." "Wazuh Manager recovered and SCENARIO_D localfile configured."
}

# -----------------------------
# Main flow
# -----------------------------
ensure_wazuh_localfile

phase 2 "Warmup operacional para alinear polling Zabbix antes de ataques." "Operational warmup to align Zabbix polling before attacks."
wait_countdown "$BASELINE_WARMUP_SECONDS" "Warmup previo a ataques." "Pre-attack warmup." 10

printf 'scenario,attack_uid,iteration,attack_id,mitre_ics,technique,target_component,start_utc,end_utc,duration_s,parameters,status\n' > "$ATTACKS_CSV"
printf 'timestamp_utc,attack_uid,phase,target_url,http_code,latency_s\n' > "$HTTP_OBS_CSV"

phase 3 "Ejecución de ataques MITRE ICS controlados." "Run controlled MITRE ICS attacks."
for ((i=1; i<=ITERATIONS; i++)); do
  say_info "Iteración ${i}/${ITERATIONS}: ejecutando T0809, T0814 y T0860." "Iteration ${i}/${ITERATIONS}: running T0809, T0814, and T0860."

  # T0809
  say_step "Iteración ${i}/${ITERATIONS}: T0809 contra mosquitto." "Iteration ${i}/${ITERATIONS}: T0809 against mosquitto."
  uid="D-T0809-${i}"; start="$(now_utc)"
  write_wazuh_event "$uid" "T0809" "Unauthorized Command Message" "mosquitto" "unauthorized_command_message" "medium" "Controlled MQTT unauthorized command simulation against $MQTT_HOST:$MQTT_PORT"
  # operational touch: TCP probe using bash /dev/tcp if available
  timeout 3 bash -c "</dev/tcp/$MQTT_HOST/$MQTT_PORT" >/dev/null 2>&1 || true
  end="$(now_utc)"
  printf 'SCENARIO_D,%s,%s,T0809,T0809,Unauthorized Command Message,mosquitto,%s,%s,%s,%s,%s\n' "$uid" "$i" "$start" "$end" "$SLEEP_SECONDS" "tcp_probe_${MQTT_HOST}:${MQTT_PORT}" "executed" >> "$ATTACKS_CSV"
  sleep "$SLEEP_SECONDS"

  # T0814
  say_step "Iteración ${i}/${ITERATIONS}: T0814 contra telemetry-api." "Iteration ${i}/${ITERATIONS}: T0814 against telemetry-api."
  uid="D-T0814-${i}"; start="$(now_utc)"
  write_wazuh_event "$uid" "T0814" "Data Manipulation" "telemetry-api" "telemetry_manipulation" "medium" "Controlled telemetry manipulation request against $TELEMETRY_HOST:$HTTP_PORT"
  target="http://${TELEMETRY_HOST}:${HTTP_PORT}/"
  IFS=, read -r code latency < <(read_http_probe "$target") || true
  printf '%s,%s,T0814,%s,%s,%s\n' "$(now_utc)" "$uid" "$target" "$code" "$latency" >> "$HTTP_OBS_CSV"
  end="$(now_utc)"
  printf 'SCENARIO_D,%s,%s,T0814,T0814,Data Manipulation,telemetry-api,%s,%s,%s,%s,%s\n' "$uid" "$i" "$start" "$end" "$SLEEP_SECONDS" "http_probe_${target}" "executed" >> "$ATTACKS_CSV"
  sleep "$SLEEP_SECONDS"

  # T0860
  say_step "Iteración ${i}/${ITERATIONS}: T0860 DoS controlado contra vulnerable-app (${ATTACK_DURATION_SECONDS}s)." "Iteration ${i}/${ITERATIONS}: controlled T0860 DoS against vulnerable-app (${ATTACK_DURATION_SECONDS}s)."
  uid="D-T0860-${i}"; start="$(now_utc)"
  target="http://${VULN_HOST}:${HTTP_PORT}/"
  write_wazuh_event "$uid" "T0860" "Denial of Service" "vulnerable-app" "availability_degradation_http_flood" "high" "Controlled HTTP flood against $target requests=$DOS_REQUESTS concurrency=$DOS_CONCURRENCY duration=${ATTACK_DURATION_SECONDS}s"
  IFS=, read -r pre_code pre_latency < <(read_http_probe "$target") || true
  printf '%s,%s,pre,%s,%s,%s\n' "$(now_utc)" "$uid" "$target" "$pre_code" "$pre_latency" >> "$HTTP_OBS_CSV"
  run_parallel_http_flood "$target" "$DOS_REQUESTS" "$DOS_CONCURRENCY" "$ATTACK_DURATION_SECONDS"
  IFS=, read -r post_code post_latency < <(read_http_probe "$target") || true
  printf '%s,%s,post,%s,%s,%s\n' "$(now_utc)" "$uid" "$target" "$post_code" "$post_latency" >> "$HTTP_OBS_CSV"
  end="$(now_utc)"
  printf 'SCENARIO_D,%s,%s,T0860,T0860,Denial of Service,vulnerable-app,%s,%s,%s,%s,%s\n' "$uid" "$i" "$start" "$end" "$ATTACK_DURATION_SECONDS" "requests=${DOS_REQUESTS};concurrency=${DOS_CONCURRENCY}" "executed" >> "$ATTACKS_CSV"

  if (( i < ITERATIONS )); then
    wait_countdown "$INTER_ATTACK_COOLDOWN_SECONDS" "Cooldown entre iteraciones." "Cooldown between iterations." 10
  fi

done

phase 4 "Exportar evidencia Wazuh y observaciones HTTP." "Export Wazuh evidence and HTTP observations."
$KUBE_CMD exec -n "$SECURITY_NS" "$MANAGER_POD" -- sh -c "tail -1000 '$WAZUH_LOCALFILE_PATH' 2>/dev/null || true" > "$EVIDENCE_DIR/${RUN_TS}-scenario-d-attacks-localfile-tail.ndjson" 2>/dev/null || true
$KUBE_CMD logs -n "$SECURITY_NS" "$MANAGER_POD" --tail=200 > "$EVIDENCE_DIR/${RUN_TS}-scenario-d-manager-pod-logs.txt" 2>/dev/null || true

phase 5 "Validar datasets generados." "Validate generated datasets."
attack_lines=$(wc -l < "$ATTACKS_CSV" | tr -d ' ')
http_lines=$(wc -l < "$HTTP_OBS_CSV" | tr -d ' ')
if (( attack_lines < ITERATIONS * 3 + 1 )); then
  say_error "Dataset de ataques incompleto: $attack_lines líneas." "Attack dataset incomplete: $attack_lines lines."
  exit 1
fi
if (( http_lines < ITERATIONS * 2 + 1 )); then
  say_error "Dataset HTTP incompleto: $http_lines líneas." "HTTP dataset incomplete: $http_lines lines."
  exit 1
fi

printf '\n============================================================\n'
printf '[SUMMARY] Scenario D MITRE ICS Controlled Attacks\n'
printf '============================================================\n'
printf '[OK] Ataques controlados ejecutados: T0809, T0814, T0860\n'
printf '[OK] Controlled attacks executed: T0809, T0814, T0860\n'
printf '[OK] Dataset generado: results/raw/scenario_d/mitre_ics_attacks.csv (%s líneas)\n' "$attack_lines"
printf '[OK] Dataset generated: results/raw/scenario_d/mitre_ics_attacks.csv (%s lines)\n' "$attack_lines"
printf '[OK] Observaciones HTTP generadas: results/raw/scenario_d/attack_http_observations.csv (%s líneas)\n' "$http_lines"
printf '[OK] HTTP observations generated: results/raw/scenario_d/attack_http_observations.csv (%s lines)\n' "$http_lines"
printf '[OK] Eventos SCENARIO_D escritos en Wazuh Manager localfile\n'
printf '[OK] SCENARIO_D events written to Wazuh Manager localfile\n'
printf '[OK] Escenario D listo para correlación Zabbix/Wazuh\n'
printf '[OK] Scenario D ready for Zabbix/Wazuh correlation\n'
