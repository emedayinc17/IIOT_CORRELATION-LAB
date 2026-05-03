#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

TZ_NAME="${TZ_NAME:-America/Lima}"

now_local() { TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %z (%Z)'; }
now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

line() { printf '%s\n' '============================================================'; }

phase() {
  printf '\n------------------------------------------------------------\n'
  printf '[PHASE %s] ES: %s\n' "$1" "$2"
  printf '[PHASE %s] EN: %s\n' "$1" "$3"
  printf '%s\n\n' '------------------------------------------------------------'
}

info() {
  printf '[INFO] ES: %s\n' "$1"
  printf '[INFO] EN: %s\n\n' "$2"
}

ok() {
  printf '[OK] ES: %s\n' "$1"
  printf '[OK] EN: %s\n' "$2"
}

warn() {
  printf '[WARN] ES: %s\n' "$1"
  printf '[WARN] EN: %s\n' "$2"
}

fail() {
  printf '\n[ERROR] ES: %s\n' "$1" >&2
  printf '[ERROR] EN: %s\n' "$2" >&2
  exit 1
}

script_start() {
  line
  printf '[SCRIPT START] %s\n' "$1"
  printf 'Hora de inicio / Start time: %s\n' "$(now_local)"
  printf 'ES: %s\n' "$2"
  printf 'EN: %s\n' "$3"
  line
  printf '\n'
}

execution_window() {
  local es="$1" en="$2" seconds="$3"
  local start_epoch finish
  start_epoch="$(date +%s)"
  finish="$(TZ="$TZ_NAME" date -d "@$((start_epoch + seconds))" '+%Y-%m-%d %H:%M:%S %z (%Z)' 2>/dev/null || true)"
  line
  printf '[EXECUTION WINDOW]\n'
  printf 'ES: %s\n' "$es"
  printf 'EN: %s\n' "$en"
  printf 'Hora de inicio / Start time: %s\n' "$(now_local)"
  printf 'Duración estimada / Estimated duration: %02dh:%02dm:%02ds\n' $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
  [[ -n "$finish" ]] && printf 'Fin estimado / Estimated finish: %s\n' "$finish"
  line
  printf '\n'
}

script_end() {
  local code="$?"
  line
  printf '[EXECUTION END]\n'
  printf 'Script: %s\n' "$(basename "$0")"
  printf 'Hora de fin / End time: %s\n' "$(now_local)"
  printf 'Exit code: %s\n' "$code"
  if [[ "$code" == "0" ]]; then
    printf 'ES: Ejecución finalizada correctamente.\n'
    printf 'EN: Execution completed successfully.\n'
  else
    printf 'ES: Ejecución finalizada con error; revisar el último mensaje y evidencia generada.\n'
    printf 'EN: Execution finished with an error; review the latest message and generated evidence.\n'
  fi
  line
}
trap script_end EXIT

script_start "23-run-operational-noise-control.sh" \
  "Ejecutar Escenario E: ruido operacional legítimo resiliente y endpoints HTTP saludables." \
  "Run Scenario E: resilient legitimate operational noise with healthy HTTP endpoints."

KUBECTL="${KUBECTL:-microk8s kubectl}"
RAW_E_DIR="${RAW_E_DIR:-results/raw/scenario_e}"
EVIDENCE_WAZUH_DIR="${EVIDENCE_WAZUH_DIR:-evidence/wazuh/scenario_e}"
mkdir -p "$RAW_E_DIR" "$EVIDENCE_WAZUH_DIR"

NOISE_PROFILES="${NOISE_PROFILES:-LOW,MEDIUM,HIGH}"
ITERATIONS_PER_PROFILE="${ITERATIONS_PER_PROFILE:-20}"
NOISE_DURATION_SECONDS="${NOISE_DURATION_SECONDS:-30}"
INTER_NOISE_COOLDOWN_SECONDS="${INTER_NOISE_COOLDOWN_SECONDS:-10}"
HTTP_PROBE_INTERVAL_SECONDS="${HTTP_PROBE_INTERVAL_SECONDS:-2}"

MQTT_HOST="${MQTT_HOST:-10.10.0.151}"
MQTT_PORT="${MQTT_PORT:-1883}"

HEALTH_URL="${HEALTH_URL:-http://10.10.0.152:8080/health}"
TELEMETRY_HEALTH_URL="${TELEMETRY_HEALTH_URL:-http://10.10.0.153:8080/health}"
TELEMETRY_METRICS_URL="${TELEMETRY_METRICS_URL:-http://10.10.0.153:8080/metrics}"
TELEMETRY_DATA_URL="${TELEMETRY_DATA_URL:-http://10.10.0.153:8080/telemetry}"
VULNERABLE_HEALTH_URL="${VULNERABLE_HEALTH_URL:-http://10.10.0.154:8080/health}"
HTTP_URLS="${HTTP_URLS:-${HEALTH_URL},${TELEMETRY_HEALTH_URL},${TELEMETRY_METRICS_URL},${TELEMETRY_DATA_URL},${VULNERABLE_HEALTH_URL}}"

LOW_HTTP_CONCURRENCY="${LOW_HTTP_CONCURRENCY:-5}"
MEDIUM_HTTP_CONCURRENCY="${MEDIUM_HTTP_CONCURRENCY:-10}"
HIGH_HTTP_CONCURRENCY="${HIGH_HTTP_CONCURRENCY:-20}"
LOW_MQTT_MESSAGES="${LOW_MQTT_MESSAGES:-20}"
MEDIUM_MQTT_MESSAGES="${MEDIUM_MQTT_MESSAGES:-40}"
HIGH_MQTT_MESSAGES="${HIGH_MQTT_MESSAGES:-80}"

NOISE_EVENTS="$RAW_E_DIR/noise_events.csv"
HTTP_OBS="$RAW_E_DIR/noise_http_observations.csv"
MQTT_OBS="$RAW_E_DIR/noise_mqtt_observations.csv"
WAZUH_NOISE="$RAW_E_DIR/wazuh_noise_events.csv"
META_JSON="$RAW_E_DIR/scenario_e_metadata.json"
LOCAL_NDJSON="$EVIDENCE_WAZUH_DIR/scenario_e_noise_local_events.ndjson"

IFS=',' read -ra PROFILE_ARRAY <<< "$NOISE_PROFILES"
ESTIMATED_SECONDS=$(( ${#PROFILE_ARRAY[@]} * ITERATIONS_PER_PROFILE * (NOISE_DURATION_SECONDS + INTER_NOISE_COOLDOWN_SECONDS) + 120 ))

execution_window \
  "Escenario E resiliente con endpoints HTTP saludables, perfiles ${NOISE_PROFILES}, ${ITERATIONS_PER_PROFILE} iteraciones por perfil y medición FPR." \
  "Resilient Scenario E with healthy HTTP endpoints, profiles ${NOISE_PROFILES}, ${ITERATIONS_PER_PROFILE} iterations per profile, and FPR measurement." \
  "$ESTIMATED_SECONDS"

phase "1/6" "Validar laboratorio, Wazuh y endpoints HTTP legítimos." "Validate laboratory, Wazuh, and legitimate HTTP endpoints."

MANAGER_POD="$($KUBECTL get pod -n security -l app=wazuh-manager,role=master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$MANAGER_POD" ]]; then
  MANAGER_POD="$($KUBECTL get pod -n security | awk '/wazuh-manager-master/ {print $1; exit}')"
fi
[[ -n "$MANAGER_POD" ]] || fail "No se encontró Wazuh Manager." "Wazuh Manager was not found."

$KUBECTL get ns iiot-poc >/dev/null
$KUBECTL get ns monitoring >/dev/null
$KUBECTL get ns security >/dev/null

# Validate Wazuh exec only once at the start. No per-iteration kubectl exec is used.
if ! $KUBECTL exec -n security "$MANAGER_POD" -- sh -c 'test -d /var/ossec/logs/iiot-lab || mkdir -p /var/ossec/logs/iiot-lab' >/dev/null 2>&1; then
  fail "No se pudo validar el directorio localfile en Wazuh Manager." \
       "Could not validate localfile directory in Wazuh Manager."
fi

IFS=',' read -ra URL_ARRAY <<< "$HTTP_URLS"
for url in "${URL_ARRAY[@]}"; do
  url="$(echo "$url" | xargs)"
  code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || true)"
  if [[ "$code" != "200" ]]; then
    fail "Endpoint HTTP no saludable para Escenario E: $url respondió $code. Corrige HTTP_URLS antes de ejecutar." \
         "Unhealthy HTTP endpoint for Scenario E: $url returned $code. Fix HTTP_URLS before running."
  fi
  ok "Endpoint saludable: $url -> $code" "Healthy endpoint: $url -> $code"
done

phase "2/6" "Inicializar datasets del Escenario E." "Initialize Scenario E datasets."

cat > "$NOISE_EVENTS" <<'EOF'
timestamp_utc,noise_uid,scenario,profile,iteration,noise_type,intensity,duration_seconds,frequency,target_services,expected_impact,start_utc,end_utc,http_urls
EOF

cat > "$HTTP_OBS" <<'EOF'
timestamp_utc,noise_uid,profile,iteration,target_url,http_code,latency_seconds,legitimate_request
EOF

cat > "$MQTT_OBS" <<'EOF'
timestamp_utc,noise_uid,profile,iteration,mqtt_host,mqtt_port,topic,messages_attempted,messages_success,messages_failed,legitimate_publish
EOF

cat > "$WAZUH_NOISE" <<'EOF'
timestamp_utc,noise_uid,scenario,profile,iteration,event_type,severity,expected_impact,target_services,source
EOF

: > "$LOCAL_NDJSON"

phase "3/6" "Ejecutar perfiles de ruido operacional legítimo." "Run legitimate operational noise profiles."

profile_params() {
  local profile="$1"
  case "$profile" in
    LOW) echo "$LOW_HTTP_CONCURRENCY,$LOW_MQTT_MESSAGES,low" ;;
    MEDIUM) echo "$MEDIUM_HTTP_CONCURRENCY,$MEDIUM_MQTT_MESSAGES,medium" ;;
    HIGH) echo "$HIGH_HTTP_CONCURRENCY,$HIGH_MQTT_MESSAGES,high" ;;
    *) fail "Perfil no soportado: $profile" "Unsupported profile: $profile" ;;
  esac
}

for profile in "${PROFILE_ARRAY[@]}"; do
  profile="$(echo "$profile" | xargs)"
  IFS=',' read -r http_concurrency mqtt_messages intensity <<< "$(profile_params "$profile")"
  info "Perfil $profile: concurrencia HTTP=$http_concurrency, mensajes MQTT=$mqtt_messages, duración=${NOISE_DURATION_SECONDS}s." \
       "Profile $profile: HTTP concurrency=$http_concurrency, MQTT messages=$mqtt_messages, duration=${NOISE_DURATION_SECONDS}s."

  for iteration in $(seq 1 "$ITERATIONS_PER_PROFILE"); do
    noise_uid="E-${profile}-${iteration}"
    start_utc="$(now_utc)"
    start_epoch="$(date +%s)"
    end_epoch=$((start_epoch + NOISE_DURATION_SECONDS))
    end_utc="$(date -u -d "@$end_epoch" '+%Y-%m-%dT%H:%M:%SZ')"

    printf '%s,%s,SCENARIO_E,%s,%s,mixed_operational_noise,%s,%s,http_interval_%ss_mqtt_messages_%s,"health-app;telemetry-api;vulnerable-app;mqtt-broker",benign_no_attack,%s,%s,"%s"\n' \
      "$start_utc" "$noise_uid" "$profile" "$iteration" "$intensity" "$NOISE_DURATION_SECONDS" "$HTTP_PROBE_INTERVAL_SECONDS" "$mqtt_messages" "$start_utc" "$end_utc" "$HTTP_URLS" >> "$NOISE_EVENTS"

    # Write benign local event locally first; append to Wazuh once after the campaign.
    python3 - <<PY >> "$LOCAL_NDJSON"
import json
print(json.dumps({
  "timestamp_utc": "$start_utc",
  "iiot_lab": {
    "scenario": "SCENARIO_E",
    "noise_uid": "$noise_uid",
    "profile": "$profile",
    "iteration": int("$iteration"),
    "event_type": "legitimate_operational_noise",
    "severity": "benign",
    "expected_impact": "no_attack",
    "target_services": ["health-app","telemetry-api","vulnerable-app","mqtt-broker"],
    "noise_type": "mixed_operational_noise",
    "http_urls": "$HTTP_URLS".split(",")
  }
}))
PY

    printf '%s,%s,SCENARIO_E,%s,%s,legitimate_operational_noise,benign,benign_no_attack,"health-app;telemetry-api;vulnerable-app;mqtt-broker",local_ndjson_batch\n' \
      "$start_utc" "$noise_uid" "$profile" "$iteration" >> "$WAZUH_NOISE"

    export NOISE_UID="$noise_uid" PROFILE="$profile" ITERATION="$iteration" DURATION="$NOISE_DURATION_SECONDS"
    export INTERVAL="$HTTP_PROBE_INTERVAL_SECONDS" HTTP_CONCURRENCY="$http_concurrency" MQTT_MESSAGES="$mqtt_messages"
    export MQTT_HOST MQTT_PORT HTTP_URLS HTTP_OBS MQTT_OBS

    python3 - <<'PY'
import concurrent.futures, csv, json, os, socket, struct, time, urllib.request
from datetime import datetime, timezone
from pathlib import Path

noise_uid=os.environ["NOISE_UID"]
profile=os.environ["PROFILE"]
iteration=int(os.environ["ITERATION"])
duration=int(os.environ["DURATION"])
interval=float(os.environ["INTERVAL"])
http_concurrency=int(os.environ["HTTP_CONCURRENCY"])
mqtt_messages=int(os.environ["MQTT_MESSAGES"])
mqtt_host=os.environ["MQTT_HOST"]
mqtt_port=int(os.environ["MQTT_PORT"])
urls=[u.strip() for u in os.environ["HTTP_URLS"].split(",") if u.strip()]
http_file=Path(os.environ["HTTP_OBS"])
mqtt_file=Path(os.environ["MQTT_OBS"])

def ts():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def http_get(url):
    start=time.time()
    code="000"
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            code=str(r.getcode())
    except Exception:
        code="000"
    return [ts(), noise_uid, profile, iteration, url, code, round(time.time()-start, 6), "YES"]

def enc_str(s):
    b=s.encode()
    return struct.pack("!H", len(b)) + b

def mqtt_publish(topic, payload):
    client_id=f"scenario-e-{noise_uid}"
    try:
        sock=socket.create_connection((mqtt_host, mqtt_port), timeout=5)
        vh=enc_str("MQTT") + bytes([4,2,0,30]) + enc_str(client_id)
        sock.sendall(bytes([0x10]) + bytes([len(vh)]) + vh)
        sock.recv(4)
        data=enc_str(topic) + payload.encode()
        rem=len(data)
        enc=[]
        while True:
            d=rem%128
            rem//=128
            if rem>0: d|=128
            enc.append(d)
            if rem==0: break
        sock.sendall(bytes([0x30]) + bytes(enc) + data)
        sock.close()
        return True
    except Exception:
        return False

end=time.time()+duration
http_rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=http_concurrency) as ex:
    while time.time() < end:
        futs=[ex.submit(http_get, urls[i % len(urls)]) for i in range(http_concurrency)]
        for fut in concurrent.futures.as_completed(futs):
            http_rows.append(fut.result())
        time.sleep(interval)

if http_rows:
    with http_file.open("a", newline="", encoding="utf-8") as f:
        csv.writer(f).writerows(http_rows)

success=0
failed=0
topic=f"sensors/legitimate/{profile.lower()}"
for i in range(mqtt_messages):
    payload=json.dumps({"noise_uid":noise_uid,"profile":profile,"iteration":iteration,"seq":i,"value":20+(i%5),"status":"normal"})
    if mqtt_publish(topic, payload):
        success+=1
    else:
        failed+=1
    time.sleep(max(0.01, duration/max(mqtt_messages,1)/4))

with mqtt_file.open("a", newline="", encoding="utf-8") as f:
    csv.writer(f).writerow([ts(), noise_uid, profile, iteration, mqtt_host, mqtt_port, topic, mqtt_messages, success, failed, "YES"])
PY

    # Skip cooldown after the very last iteration/profile.
    if [[ "$iteration" -lt "$ITERATIONS_PER_PROFILE" || "$profile" != "${PROFILE_ARRAY[-1]}" ]]; then
      printf '[WAIT] ES: Cooldown ruido operacional. Restante: %ss\n' "$INTER_NOISE_COOLDOWN_SECONDS"
      printf '[WAIT] EN: Operational noise cooldown. Remaining: %ss\n' "$INTER_NOISE_COOLDOWN_SECONDS"
      sleep "$INTER_NOISE_COOLDOWN_SECONDS"
    fi
  done
done

phase "4/6" "Adjuntar evidencia benigna a Wazuh una sola vez y exportar SCENARIO_E." "Append benign evidence to Wazuh once and export SCENARIO_E."

# Batch append to Wazuh. This avoids fragile per-iteration kubectl exec calls.
for attempt in 1 2 3; do
  if cat "$LOCAL_NDJSON" | $KUBECTL exec -i -n security "$MANAGER_POD" -- sh -c 'cat >> /var/ossec/logs/iiot-lab/scenario_d_attacks.json' >/dev/null 2>&1; then
    ok "Eventos benignos SCENARIO_E adjuntados a Wazuh en intento $attempt" "SCENARIO_E benign events appended to Wazuh on attempt $attempt"
    break
  fi
  if [[ "$attempt" -eq 3 ]]; then
    fail "No se pudo adjuntar evidencia SCENARIO_E a Wazuh tras 3 intentos." \
         "Could not append SCENARIO_E evidence to Wazuh after 3 attempts."
  fi
  warn "Fallo transitorio adjuntando evidencia a Wazuh; reintentando..." "Transient failure appending evidence to Wazuh; retrying..."
  sleep 10
done

$KUBECTL exec -n security "$MANAGER_POD" -- sh -c 'grep "SCENARIO_E" /var/ossec/logs/iiot-lab/scenario_d_attacks.json 2>/dev/null || true' \
  > "$EVIDENCE_WAZUH_DIR/scenario_e_noise_localfile_export.ndjson" || true

cp "$EVIDENCE_WAZUH_DIR/scenario_e_noise_localfile_export.ndjson" "$RAW_E_DIR/scenario_e_noise_localfile_export.ndjson" || true

phase "5/6" "Validar que el ruido HTTP no contiene errores artificiales." "Validate that HTTP noise does not contain artificial errors."

python3 - <<PY
import csv, json
from pathlib import Path
p=Path("$HTTP_OBS")
rows=list(csv.DictReader(p.open(encoding="utf-8")))
total=len(rows)
errors=[]
by={}
for r in rows:
    key=(r["target_url"], r["http_code"])
    by[key]=by.get(key,0)+1
    try:
        c=int(r["http_code"])
    except Exception:
        c=0
    if c == 0 or c >= 400:
        errors.append(r)
summary={"http_observations":total,"http_error_count":len(errors),"http_error_rate_percent":round(len(errors)*100/total,2) if total else 0,"by_url_code":{f"{k[0]} {k[1]}":v for k,v in sorted(by.items())}}
Path("$RAW_E_DIR/http_endpoint_validation_summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf-8")
print(json.dumps(summary,indent=2,ensure_ascii=False))
if errors:
    raise SystemExit("HTTP noise has errors; Scenario E should use healthy legitimate endpoints only.")
PY

phase "6/6" "Validar completitud y generar metadata del Escenario E." "Validate completeness and generate Scenario E metadata."

python3 - <<PY
import csv, json, pathlib, hashlib
from datetime import datetime, timezone

expected = len("$NOISE_PROFILES".split(",")) * int("$ITERATIONS_PER_PROFILE")

def sha(p):
    path=pathlib.Path(p)
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None

def rows(p):
    path=pathlib.Path(p)
    return max(sum(1 for _ in path.open(encoding="utf-8"))-1,0) if path.exists() else 0

noise_rows = rows("$NOISE_EVENTS")
mqtt_rows = rows("$MQTT_OBS")
wazuh_rows = rows("$WAZUH_NOISE")

if noise_rows != expected:
    raise SystemExit(f"Expected {expected} noise events, got {noise_rows}")
if mqtt_rows != expected:
    raise SystemExit(f"Expected {expected} MQTT observations, got {mqtt_rows}")
if wazuh_rows != expected:
    raise SystemExit(f"Expected {expected} Wazuh benign records, got {wazuh_rows}")

meta={
  "metadata_version":"1.2",
  "scenario":"E",
  "scenario_name":"Operational Noise / False Positive Control",
  "generated_utc":datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "profiles":"$NOISE_PROFILES",
  "expected_noise_executions":expected,
  "iterations_per_profile":int("$ITERATIONS_PER_PROFILE"),
  "noise_duration_seconds":int("$NOISE_DURATION_SECONDS"),
  "inter_noise_cooldown_seconds":int("$INTER_NOISE_COOLDOWN_SECONDS"),
  "http_probe_interval_seconds":float("$HTTP_PROBE_INTERVAL_SECONDS"),
  "http_urls":"$HTTP_URLS".split(","),
  "profile_parameters":{
    "LOW":{"http_concurrency":int("$LOW_HTTP_CONCURRENCY"),"mqtt_messages":int("$LOW_MQTT_MESSAGES")},
    "MEDIUM":{"http_concurrency":int("$MEDIUM_HTTP_CONCURRENCY"),"mqtt_messages":int("$MEDIUM_MQTT_MESSAGES")},
    "HIGH":{"http_concurrency":int("$HIGH_HTTP_CONCURRENCY"),"mqtt_messages":int("$HIGH_MQTT_MESSAGES")}
  },
  "definition":"Legitimate operational noise without attacks; used to estimate false positive rate for MITRE ICS techniques T0809/T0814/T0860.",
  "resilience_note":"Benign Wazuh evidence is generated locally and appended once after the campaign to avoid fragile per-iteration kubectl exec calls.",
  "datasets":{
    "noise_events":{"path":"$NOISE_EVENTS","rows":noise_rows,"sha256":sha("$NOISE_EVENTS")},
    "noise_http_observations":{"path":"$HTTP_OBS","rows":rows("$HTTP_OBS"),"sha256":sha("$HTTP_OBS")},
    "noise_mqtt_observations":{"path":"$MQTT_OBS","rows":mqtt_rows,"sha256":sha("$MQTT_OBS")},
    "wazuh_noise_events":{"path":"$WAZUH_NOISE","rows":wazuh_rows,"sha256":sha("$WAZUH_NOISE")},
    "http_endpoint_validation_summary":{"path":"$RAW_E_DIR/http_endpoint_validation_summary.json","sha256":sha("$RAW_E_DIR/http_endpoint_validation_summary.json")},
    "local_ndjson_batch":{"path":"$LOCAL_NDJSON","sha256":sha("$LOCAL_NDJSON")}
  }
}
pathlib.Path("$META_JSON").write_text(json.dumps(meta,indent=2,ensure_ascii=False),encoding="utf-8")
print(json.dumps(meta,indent=2,ensure_ascii=False))
PY

line
echo "[SUMMARY] Scenario E Operational Noise Control v1.2"
line
ok "Dataset completo generado: $NOISE_EVENTS" "Complete dataset generated: $NOISE_EVENTS"
ok "Observaciones HTTP saludables generadas: $HTTP_OBS" "Healthy HTTP observations generated: $HTTP_OBS"
ok "Observaciones MQTT completas generadas: $MQTT_OBS" "Complete MQTT observations generated: $MQTT_OBS"
ok "Evidencia benigna SCENARIO_E adjuntada a Wazuh por lote" "SCENARIO_E benign evidence appended to Wazuh by batch"
ok "Escenario E listo para análisis FPR" "Scenario E ready for FPR analysis"
