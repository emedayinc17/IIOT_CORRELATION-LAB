#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

TZ_NAME="${TZ_NAME:-America/Lima}"
now_local() { TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %z (%Z)'; }
now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
line() { printf '%s\n' '============================================================'; }
phase() { printf '\n------------------------------------------------------------\n[PHASE %s] ES: %s\n[PHASE %s] EN: %s\n------------------------------------------------------------\n\n' "$1" "$2" "$1" "$3"; }
info() { printf '[INFO] ES: %s\n[INFO] EN: %s\n\n' "$1" "$2"; }
ok() { printf '[OK] ES: %s\n[OK] EN: %s\n' "$1" "$2"; }
warn() { printf '[WARN] ES: %s\n[WARN] EN: %s\n' "$1" "$2"; }
fail() { printf '\n[ERROR] ES: %s\n[ERROR] EN: %s\n' "$1" "$2" >&2; exit 1; }
script_start() { line; printf '[SCRIPT START] %s\nHora de inicio / Start time: %s\nES: %s\nEN: %s\n' "$1" "$(now_local)" "$2" "$3"; line; printf '\n'; }
execution_window() {
  local seconds="$3"; local start_epoch finish
  start_epoch="$(date +%s)"
  finish="$(TZ="$TZ_NAME" date -d "@$((start_epoch + seconds))" '+%Y-%m-%d %H:%M:%S %z (%Z)' 2>/dev/null || true)"
  line; printf '[EXECUTION WINDOW]\nES: %s\nEN: %s\nHora de inicio / Start time: %s\nDuración estimada / Estimated duration: %02dh:%02dm:%02ds\n' "$1" "$2" "$(now_local)" $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
  [[ -n "$finish" ]] && printf 'Fin estimado / Estimated finish: %s\n' "$finish"
  line; printf '\n'
}
script_end() {
  local code="$?"; line; printf '[EXECUTION END]\nScript: %s\nHora de fin / End time: %s\nExit code: %s\n' "$(basename "$0")" "$(now_local)" "$code"
  if [[ "$code" == "0" ]]; then printf 'ES: Ejecución finalizada correctamente.\nEN: Execution completed successfully.\n'; else printf 'ES: Ejecución finalizada con error; revisar el último mensaje y evidencia generada.\nEN: Execution finished with an error; review the latest message and generated evidence.\n'; fi
  line
}
trap script_end EXIT

script_start "23-run-operational-noise-control.sh" \
  "Ejecutar Escenario E: ruido operacional legítimo para control de falsos positivos." \
  "Run Scenario E: legitimate operational noise for false positive control."

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
TELEMETRY_URL="${TELEMETRY_URL:-http://10.10.0.153:8080/}"
VULNERABLE_URL="${VULNERABLE_URL:-http://10.10.0.154:8080/}"

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

IFS=',' read -ra PROFILE_ARRAY <<< "$NOISE_PROFILES"
ESTIMATED_SECONDS=$(( ${#PROFILE_ARRAY[@]} * ITERATIONS_PER_PROFILE * (NOISE_DURATION_SECONDS + INTER_NOISE_COOLDOWN_SECONDS) + 120 ))
execution_window \
  "Escenario E con perfiles ${NOISE_PROFILES}, ${ITERATIONS_PER_PROFILE} iteraciones por perfil, ruido legítimo y medición FPR." \
  "Scenario E with profiles ${NOISE_PROFILES}, ${ITERATIONS_PER_PROFILE} iterations per profile, legitimate noise, and FPR measurement." \
  "$ESTIMATED_SECONDS"

phase "1/5" "Validar laboratorio y Wazuh localfile existente." "Validate laboratory and existing Wazuh localfile."
MANAGER_POD="$($KUBECTL get pod -n security -l app=wazuh-manager,role=master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$MANAGER_POD" ]]; then MANAGER_POD="$($KUBECTL get pod -n security | awk '/wazuh-manager-master/ {print $1; exit}')"; fi
[[ -n "$MANAGER_POD" ]] || fail "No se encontró Wazuh Manager." "Wazuh Manager was not found."
$KUBECTL get ns iiot-poc >/dev/null
$KUBECTL get ns monitoring >/dev/null
$KUBECTL get ns security >/dev/null
if ! $KUBECTL exec -n security "$MANAGER_POD" -- sh -c 'test -f /var/ossec/logs/iiot-lab/scenario_d_attacks.json' >/dev/null 2>&1; then
  fail "No existe localfile Wazuh base. Ejecutar/validar Escenario D antes de E." "Base Wazuh localfile does not exist. Run/validate Scenario D before E."
fi

phase "2/5" "Inicializar datasets del Escenario E." "Initialize Scenario E datasets."
cat > "$NOISE_EVENTS" <<'EOF'
timestamp_utc,noise_uid,scenario,profile,iteration,noise_type,intensity,duration_seconds,frequency,target_services,expected_impact,start_utc,end_utc
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

phase "3/5" "Ejecutar perfiles de ruido operacional legítimo." "Run legitimate operational noise profiles."
profile_params() {
  case "$1" in
    LOW) echo "$LOW_HTTP_CONCURRENCY,$LOW_MQTT_MESSAGES,low" ;;
    MEDIUM) echo "$MEDIUM_HTTP_CONCURRENCY,$MEDIUM_MQTT_MESSAGES,medium" ;;
    HIGH) echo "$HIGH_HTTP_CONCURRENCY,$HIGH_MQTT_MESSAGES,high" ;;
    *) fail "Perfil no soportado: $1" "Unsupported profile: $1" ;;
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

    printf '%s,%s,SCENARIO_E,%s,%s,mixed_operational_noise,%s,%s,http_interval_%ss_mqtt_messages_%s,"health-app;telemetry-api;vulnerable-app;mqtt-broker",benign_no_attack,%s,%s\n' \
      "$start_utc" "$noise_uid" "$profile" "$iteration" "$intensity" "$NOISE_DURATION_SECONDS" "$HTTP_PROBE_INTERVAL_SECONDS" "$mqtt_messages" "$start_utc" "$end_utc" >> "$NOISE_EVENTS"

    benign_json="$(python3 - <<PY
import json
print(json.dumps({"timestamp_utc":"$start_utc","iiot_lab":{"scenario":"SCENARIO_E","noise_uid":"$noise_uid","profile":"$profile","iteration":int("$iteration"),"event_type":"legitimate_operational_noise","severity":"benign","expected_impact":"no_attack","target_services":["health-app","telemetry-api","vulnerable-app","mqtt-broker"],"noise_type":"mixed_operational_noise"}}))
PY
)"
    printf '%s\n' "$benign_json" | $KUBECTL exec -i -n security "$MANAGER_POD" -- sh -c 'cat >> /var/ossec/logs/iiot-lab/scenario_d_attacks.json' >/dev/null
    printf '%s,%s,SCENARIO_E,%s,%s,legitimate_operational_noise,benign,benign_no_attack,"health-app;telemetry-api;vulnerable-app;mqtt-broker",wazuh_localfile_json\n' "$start_utc" "$noise_uid" "$profile" "$iteration" >> "$WAZUH_NOISE"

    export noise_uid profile iteration NOISE_DURATION_SECONDS HTTP_PROBE_INTERVAL_SECONDS http_concurrency mqtt_messages MQTT_HOST MQTT_PORT HEALTH_URL TELEMETRY_URL VULNERABLE_URL HTTP_OBS MQTT_OBS
    python3 - <<'PY'
import concurrent.futures, csv, json, socket, struct, time, urllib.request, os
from datetime import datetime, timezone
from pathlib import Path
noise_uid=os.environ["noise_uid"]; profile=os.environ["profile"]; iteration=int(os.environ["iteration"])
duration=int(os.environ["NOISE_DURATION_SECONDS"]); interval=float(os.environ["HTTP_PROBE_INTERVAL_SECONDS"])
http_concurrency=int(os.environ["http_concurrency"]); mqtt_messages=int(os.environ["mqtt_messages"])
mqtt_host=os.environ["MQTT_HOST"]; mqtt_port=int(os.environ["MQTT_PORT"])
urls=[os.environ["HEALTH_URL"], os.environ["TELEMETRY_URL"], os.environ["VULNERABLE_URL"]]
http_file=Path(os.environ["HTTP_OBS"]); mqtt_file=Path(os.environ["MQTT_OBS"])
def ts(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
def http_get(url):
    start=time.time(); code="000"
    try:
        with urllib.request.urlopen(url, timeout=5) as r: code=str(r.getcode())
    except Exception: code="000"
    return [ts(), noise_uid, profile, iteration, url, code, round(time.time()-start, 6), "YES"]
def enc_str(s):
    b=s.encode(); return struct.pack("!H", len(b)) + b
def mqtt_publish(topic, payload):
    client_id=f"scenario-e-{noise_uid}"
    try:
        sock=socket.create_connection((mqtt_host, mqtt_port), timeout=5)
        vh=enc_str("MQTT") + bytes([4,2,0,30]) + enc_str(client_id)
        sock.sendall(bytes([0x10, len(vh)]) + vh); sock.recv(4)
        data=enc_str(topic) + payload.encode(); rem=len(data); enc=[]
        while True:
            d=rem%128; rem//=128
            if rem>0: d|=128
            enc.append(d)
            if rem==0: break
        sock.sendall(bytes([0x30]) + bytes(enc) + data); sock.close(); return True
    except Exception: return False
end=time.time()+duration; http_rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=http_concurrency) as ex:
    while time.time() < end:
        futs=[ex.submit(http_get, urls[i % len(urls)]) for i in range(http_concurrency)]
        for fut in concurrent.futures.as_completed(futs): http_rows.append(fut.result())
        time.sleep(interval)
if http_rows:
    with http_file.open("a", newline="", encoding="utf-8") as f: csv.writer(f).writerows(http_rows)
success=0; failed=0; topic=f"sensors/legitimate/{profile.lower()}"
for i in range(mqtt_messages):
    payload=json.dumps({"noise_uid":noise_uid,"profile":profile,"iteration":iteration,"seq":i,"value":20+(i%5),"status":"normal"})
    if mqtt_publish(topic, payload): success+=1
    else: failed+=1
    time.sleep(max(0.01, duration/max(mqtt_messages,1)/4))
with mqtt_file.open("a", newline="", encoding="utf-8") as f:
    csv.writer(f).writerow([ts(), noise_uid, profile, iteration, mqtt_host, mqtt_port, topic, mqtt_messages, success, failed, "YES"])
PY

    remaining="$INTER_NOISE_COOLDOWN_SECONDS"
    while [[ "$remaining" -gt 0 ]]; do
      printf '[WAIT] ES: Cooldown ruido operacional. Restante: %ss\n[WAIT] EN: Operational noise cooldown. Remaining: %ss\n' "$remaining" "$remaining"
      sleep 10
      remaining=$((remaining-10))
    done
  done
done

phase "4/5" "Exportar evidencia Wazuh SCENARIO_E." "Export Wazuh SCENARIO_E evidence."
$KUBECTL exec -n security "$MANAGER_POD" -- sh -c 'grep "SCENARIO_E" /var/ossec/logs/iiot-lab/scenario_d_attacks.json 2>/dev/null || true' > "$EVIDENCE_WAZUH_DIR/scenario_e_noise_localfile_export.ndjson" || true
cp "$EVIDENCE_WAZUH_DIR/scenario_e_noise_localfile_export.ndjson" "$RAW_E_DIR/scenario_e_noise_localfile_export.ndjson" || true

phase "5/5" "Generar metadata del Escenario E." "Generate Scenario E metadata."
python3 - <<PY
import json, pathlib, hashlib
from datetime import datetime, timezone
def sha(p):
    path=pathlib.Path(p); return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
def rows(p):
    path=pathlib.Path(p); return max(sum(1 for _ in path.open(encoding="utf-8"))-1,0) if path.exists() else 0
meta={"metadata_version":"1.0","scenario":"E","scenario_name":"Operational Noise / False Positive Control","generated_utc":datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),"profiles":"$NOISE_PROFILES","iterations_per_profile":int("$ITERATIONS_PER_PROFILE"),"noise_duration_seconds":int("$NOISE_DURATION_SECONDS"),"inter_noise_cooldown_seconds":int("$INTER_NOISE_COOLDOWN_SECONDS"),"http_probe_interval_seconds":float("$HTTP_PROBE_INTERVAL_SECONDS"),"profile_parameters":{"LOW":{"http_concurrency":int("$LOW_HTTP_CONCURRENCY"),"mqtt_messages":int("$LOW_MQTT_MESSAGES")},"MEDIUM":{"http_concurrency":int("$MEDIUM_HTTP_CONCURRENCY"),"mqtt_messages":int("$MEDIUM_MQTT_MESSAGES")},"HIGH":{"http_concurrency":int("$HIGH_HTTP_CONCURRENCY"),"mqtt_messages":int("$HIGH_MQTT_MESSAGES")}},"definition":"Legitimate operational noise without attacks; used to estimate false positive rate for MITRE ICS techniques T0809/T0814/T0860.","datasets":{"noise_events":{"path":"$NOISE_EVENTS","rows":rows("$NOISE_EVENTS"),"sha256":sha("$NOISE_EVENTS")},"noise_http_observations":{"path":"$HTTP_OBS","rows":rows("$HTTP_OBS"),"sha256":sha("$HTTP_OBS")},"noise_mqtt_observations":{"path":"$MQTT_OBS","rows":rows("$MQTT_OBS"),"sha256":sha("$MQTT_OBS")},"wazuh_noise_events":{"path":"$WAZUH_NOISE","rows":rows("$WAZUH_NOISE"),"sha256":sha("$WAZUH_NOISE")}}}
pathlib.Path("$META_JSON").write_text(json.dumps(meta,indent=2,ensure_ascii=False),encoding="utf-8")
print(json.dumps(meta,indent=2,ensure_ascii=False))
PY

line; echo "[SUMMARY] Scenario E Operational Noise Control"; line
ok "Dataset generado: $NOISE_EVENTS" "Dataset generated: $NOISE_EVENTS"
ok "Observaciones HTTP generadas: $HTTP_OBS" "HTTP observations generated: $HTTP_OBS"
ok "Observaciones MQTT generadas: $MQTT_OBS" "MQTT observations generated: $MQTT_OBS"
ok "Escenario E listo para análisis FPR" "Scenario E ready for FPR analysis"
