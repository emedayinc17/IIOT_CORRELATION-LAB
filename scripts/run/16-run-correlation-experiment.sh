#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

prefer_microk8s_kubectl(){
  if command -v microk8s >/dev/null 2>&1; then echo "microk8s kubectl"; elif command -v kubectl >/dev/null 2>&1; then echo kubectl; else fail "No se encontró microk8s ni kubectl."; fi
}

KUBECTL="$(prefer_microk8s_kubectl)"
WAZUH_NS="${WAZUH_NS:-security}"
RAW_DIR="${ROOT_DIR}/results/raw/scenario_d"
PROCESSED_DIR="${ROOT_DIR}/results/processed"
EVIDENCE_DIR="${ROOT_DIR}/evidence/wazuh"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
CORRELATION_WINDOW_SECONDS="${CORRELATION_WINDOW_SECONDS:-120}"
ZABBIX_HISTORY_LOOKBACK_SECONDS="${ZABBIX_HISTORY_LOOKBACK_SECONDS:-900}"
ZABBIX_HISTORY_FORWARD_SECONDS="${ZABBIX_HISTORY_FORWARD_SECONDS:-900}"
MIN_ZABBIX_REAL_SAMPLES_PER_ATTACK="${MIN_ZABBIX_REAL_SAMPLES_PER_ATTACK:-1}"
FAIL_ON_MISSING_ZABBIX_HISTORY="${FAIL_ON_MISSING_ZABBIX_HISTORY:-1}"
ATTACKS_FILE="${RAW_DIR}/mitre_ics_attacks.csv"
HTTP_OBS_FILE="${RAW_DIR}/attack_http_observations.csv"
WAZUH_EVENTS_FILE="${RAW_DIR}/wazuh_security_events.csv"
ZABBIX_FILE="${RAW_DIR}/zabbix_correlation_metrics.csv"
CORRELATION_FILE="${PROCESSED_DIR}/correlation_dataset.csv"
ZABBIX_VALIDATION_FILE="${RAW_DIR}/zabbix_history_validation.csv"

ZABBIX_URL="${ZABBIX_URL:-http://10.10.0.160/api_jsonrpc.php}"
ZABBIX_USER="${ZABBIX_USER:-Admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-zabbix}"

find_manager_pod(){
  local pod=""
  pod="$(${KUBECTL} -n "$WAZUH_NS" get pods -l 'app=wazuh-manager,node-type=master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "$pod" ]]; then
    pod="$(${KUBECTL} -n "$WAZUH_NS" get pods --no-headers 2>/dev/null | awk '/wazuh-manager-master/ && $3 == "Running" {print $1; exit}')"
  fi
  echo "$pod"
}

mkdir -p "$RAW_DIR" "$PROCESSED_DIR" "$EVIDENCE_DIR"
log "Ejecutando correlación Escenario D — Zabbix + Wazuh con history.get real"
log "Cliente Kubernetes: ${KUBECTL}"
log "Ventana de correlación fuerte: ${CORRELATION_WINDOW_SECONDS}s"
log "Ventana history.get Zabbix: -${ZABBIX_HISTORY_LOOKBACK_SECONDS}s / +${ZABBIX_HISTORY_FORWARD_SECONDS}s"

[[ -s "$ATTACKS_FILE" ]] || fail "No existe dataset de ataques: ${ATTACKS_FILE}. Ejecuta 15-run-mitre-ics-attacks.sh."
[[ -s "$HTTP_OBS_FILE" ]] || fail "No existe dataset de observaciones HTTP: ${HTTP_OBS_FILE}. Ejecuta 15-run-mitre-ics-attacks.sh."
${KUBECTL} get ns "$WAZUH_NS" >/dev/null 2>&1 || fail "No existe namespace ${WAZUH_NS}."
manager_pod="$(find_manager_pod)"
[[ -n "$manager_pod" ]] || fail "No se pudo identificar Wazuh Manager master."

log "Exportando eventos Wazuh SCENARIO_D desde localfile y alerts.json..."
${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- bash -lc 'cat /var/ossec/logs/iiot-lab/scenario_d_attacks.json 2>/dev/null || true' > "$EVIDENCE_DIR/${TS}-scenario-d-localfile-events.ndjson" || true
${KUBECTL} -n "$WAZUH_NS" exec "$manager_pod" -- bash -lc 'tail -n 3000 /var/ossec/logs/alerts/alerts.json 2>/dev/null || true' > "$EVIDENCE_DIR/${TS}-scenario-d-alerts.json" || true

log "Consultando history.get real de Zabbix y generando dataset correlacionado..."
export RAW_DIR PROCESSED_DIR ATTACKS_FILE HTTP_OBS_FILE WAZUH_EVENTS_FILE ZABBIX_FILE CORRELATION_FILE ZABBIX_VALIDATION_FILE EVIDENCE_DIR TS CORRELATION_WINDOW_SECONDS ZABBIX_HISTORY_LOOKBACK_SECONDS ZABBIX_HISTORY_FORWARD_SECONDS MIN_ZABBIX_REAL_SAMPLES_PER_ATTACK FAIL_ON_MISSING_ZABBIX_HISTORY ZABBIX_URL ZABBIX_USER ZABBIX_PASSWORD
python3 <<'PY'
import csv, json, os, statistics, time, sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

raw_dir = Path(os.environ['RAW_DIR'])
processed_dir = Path(os.environ['PROCESSED_DIR'])
attacks_file = Path(os.environ['ATTACKS_FILE'])
http_obs_file = Path(os.environ['HTTP_OBS_FILE'])
wazuh_events_file = Path(os.environ['WAZUH_EVENTS_FILE'])
zabbix_file = Path(os.environ['ZABBIX_FILE'])
correlation_file = Path(os.environ['CORRELATION_FILE'])
zabbix_validation_file = Path(os.environ['ZABBIX_VALIDATION_FILE'])
evidence_dir = Path(os.environ['EVIDENCE_DIR'])
ts = os.environ['TS']
strong_window = int(os.environ['CORRELATION_WINDOW_SECONDS'])
lookback = int(os.environ['ZABBIX_HISTORY_LOOKBACK_SECONDS'])
forward = int(os.environ['ZABBIX_HISTORY_FORWARD_SECONDS'])
min_real = int(os.environ['MIN_ZABBIX_REAL_SAMPLES_PER_ATTACK'])
fail_missing = os.environ['FAIL_ON_MISSING_ZABBIX_HISTORY'] == '1'
zabbix_url = os.environ['ZABBIX_URL']
zabbix_user = os.environ['ZABBIX_USER']
zabbix_password = os.environ['ZABBIX_PASSWORD']

localfile_ndjson = evidence_dir / f'{ts}-scenario-d-localfile-events.ndjson'

LAB_HOSTS = {'health-app', 'telemetry-api', 'vulnerable-app', 'mqtt-broker'}
TARGET_TO_ZABBIX_HOST = {
    'mosquitto': 'mqtt-broker',
    'mqtt-broker': 'mqtt-broker',
    'health-app': 'health-app',
    'telemetry-api': 'telemetry-api',
    'vulnerable-app': 'vulnerable-app'
}

def parse_iso(s):
    s = (s or '').strip()
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    return datetime.fromisoformat(s)

def epoch_from_iso(s):
    return int(parse_iso(s).timestamp())

def epoch_to_iso(e):
    try:
        return datetime.fromtimestamp(int(e), timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    except Exception:
        return ''

def read_csv(path):
    with path.open(newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))

def write_csv(path, fieldnames, rows):
    with path.open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader(); w.writerows(rows)

def safe_float(v, default=0.0):
    try:
        return float(v)
    except Exception:
        return default

def zbx_api(method, params=None, auth=None):
    payload = {'jsonrpc': '2.0', 'method': method, 'params': params or {}, 'id': 1}
    if auth:
        payload['auth'] = auth
    req = Request(zabbix_url, data=json.dumps(payload).encode(), headers={'Content-Type':'application/json'})
    with urlopen(req, timeout=25) as r:
        data = json.loads(r.read().decode())
    if 'error' in data:
        raise RuntimeError(data['error'])
    return data['result']

attacks = read_csv(attacks_file)
http_obs = read_csv(http_obs_file)

wazuh_events = []
if localfile_ndjson.exists():
    for line in localfile_ndjson.read_text(encoding='utf-8', errors='ignore').splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        lab = obj.get('iiot_lab', {}) if isinstance(obj, dict) else {}
        if lab.get('scenario') != 'SCENARIO_D':
            continue
        wazuh_events.append({
            'timestamp_utc': obj.get('timestamp_utc') or obj.get('timestamp') or '',
            'attack_uid': lab.get('attack_uid', ''),
            'attack_id': lab.get('attack_id', ''),
            'mitre_ics': lab.get('mitre_ics', ''),
            'component': obj.get('component') or lab.get('asset', ''),
            'event_type': obj.get('event_type', ''),
            'source': 'wazuh_localfile_json'
        })
write_csv(wazuh_events_file, ['timestamp_utc','attack_uid','attack_id','mitre_ics','component','event_type','source'], wazuh_events)

# Zabbix item discovery.
auth = zbx_api('user.login', {'username': zabbix_user, 'password': zabbix_password})
items = zbx_api('item.get', {
    'output': ['itemid','name','key_','lastvalue','lastclock','value_type','state','status'],
    'selectHosts': ['host'],
    'search': {'key_': 'net.tcp.service'},
    'sortfield': 'name'
}, auth)
selected = []
for item in items:
    hosts = item.get('hosts') or []
    if not hosts:
        continue
    host = hosts[0].get('host','')
    if host in LAB_HOSTS:
        item['_host'] = host
        selected.append(item)

if not selected:
    raise RuntimeError('No se encontraron items Zabbix net.tcp.service para hosts del laboratorio. Ejecuta 06-configure-zabbix-monitoring.sh y 12-validate-wazuh-security.sh antes de D.')

# Evidence: item inventory used for correlation.
write_csv(evidence_dir / f'{ts}-scenario-d-zabbix-items-used.csv',
          ['host','itemid','name','key_','value_type','lastvalue','lastclock','state','status'],
          [{k: it.get(k,'') for k in ['itemid','name','key_','value_type','lastvalue','lastclock','state','status']} | {'host': it['_host']} for it in selected])

zabbix_rows = []
validation_rows = []
for attack in attacks:
    uid = attack['attack_uid']
    start_epoch = int(attack.get('start_epoch') or epoch_from_iso(attack.get('start_utc')))
    end_epoch = int(attack.get('end_epoch') or epoch_from_iso(attack.get('end_utc')))
    target_host = TARGET_TO_ZABBIX_HOST.get(attack.get('target_component',''), attack.get('target_component',''))
    query_from = max(0, start_epoch - lookback)
    query_till = max(int(time.time()), end_epoch + forward)
    real_samples_target = 0
    real_samples_total = 0
    nearest_delta_abs = None

    for item in selected:
        value_type = int(item.get('value_type', 3))
        history = zbx_api('history.get', {
            'output': 'extend',
            'history': value_type,
            'itemids': item['itemid'],
            'time_from': query_from,
            'time_till': query_till,
            'sortfield': 'clock',
            'sortorder': 'ASC',
            'limit': 2000
        }, auth)
        values = [safe_float(h.get('value')) for h in history]
        clocks = [int(h.get('clock', 0)) for h in history if str(h.get('clock','')).isdigit()]
        samples = len(values)
        real_samples_total += samples
        if item['_host'] == target_host:
            real_samples_target += samples
            for c in clocks:
                d = min(abs(c - start_epoch), abs(c - end_epoch))
                nearest_delta_abs = d if nearest_delta_abs is None else min(nearest_delta_abs, d)
        zabbix_rows.append({
            'attack_uid': uid,
            'target_host': target_host,
            'host': item['_host'],
            'item': item.get('name',''),
            'key': item.get('key_',''),
            'itemid': item.get('itemid',''),
            'value_type': value_type,
            'samples': samples,
            'min_value': min(values) if values else '',
            'avg_value': round(sum(values)/len(values), 6) if values else '',
            'max_value': max(values) if values else '',
            'last_value': values[-1] if values else '',
            'first_clock': clocks[0] if clocks else '',
            'last_clock': clocks[-1] if clocks else '',
            'first_utc': epoch_to_iso(clocks[0]) if clocks else '',
            'last_utc': epoch_to_iso(clocks[-1]) if clocks else '',
            'source': 'history.get' if samples else 'NO_HISTORY_IN_WINDOW'
        })
    validation_rows.append({
        'attack_uid': uid,
        'attack_id': attack.get('attack_id',''),
        'target_component': attack.get('target_component',''),
        'target_zabbix_host': target_host,
        'real_zabbix_samples_target': real_samples_target,
        'real_zabbix_samples_all_hosts': real_samples_total,
        'nearest_zabbix_sample_delta_seconds': '' if nearest_delta_abs is None else nearest_delta_abs,
        'zabbix_history_status': 'OK' if real_samples_target >= min_real else 'MISSING_TARGET_HISTORY'
    })

write_csv(zabbix_file, ['attack_uid','target_host','host','item','key','itemid','value_type','samples','min_value','avg_value','max_value','last_value','first_clock','last_clock','first_utc','last_utc','source'], zabbix_rows)
write_csv(zabbix_validation_file, ['attack_uid','attack_id','target_component','target_zabbix_host','real_zabbix_samples_target','real_zabbix_samples_all_hosts','nearest_zabbix_sample_delta_seconds','zabbix_history_status'], validation_rows)

missing = [r for r in validation_rows if r['zabbix_history_status'] != 'OK']
if missing and fail_missing:
    detail = '\n'.join(f"{r['attack_uid']} target={r['target_zabbix_host']} samples={r['real_zabbix_samples_target']}" for r in missing[:20])
    (evidence_dir / f'{ts}-scenario-d-zabbix-history-missing.txt').write_text(detail + '\n', encoding='utf-8')
    raise RuntimeError('Zabbix history.get no devolvió muestras reales para uno o más ataques. No se generará correlación cuantitativa falsa. Detalle:\n' + detail)

wazuh_by_uid = defaultdict(list)
for ev in wazuh_events:
    wazuh_by_uid[ev['attack_uid']].append(ev)
http_by_uid = defaultdict(list)
for obs in http_obs:
    http_by_uid[obs['attack_uid']].append(obs)
zbx_by_uid = defaultdict(list)
for row in zabbix_rows:
    zbx_by_uid[row['attack_uid']].append(row)
validation_by_uid = {r['attack_uid']: r for r in validation_rows}

corr_rows = []
for attack in attacks:
    uid = attack['attack_uid']
    observations = http_by_uid.get(uid, [])
    pre = [o for o in observations if o.get('phase') == 'pre']
    post = [o for o in observations if o.get('phase') == 'post']
    pre_latency = statistics.mean([safe_float(o.get('time_total_seconds')) for o in pre]) if pre else 0.0
    post_latency = statistics.mean([safe_float(o.get('time_total_seconds')) for o in post]) if post else 0.0
    http_error = any((o.get('http_code','000') == '000' or not o.get('http_code','').startswith(('2','3'))) for o in post)
    evs = wazuh_by_uid.get(uid, [])
    zbx_rows = zbx_by_uid.get(uid, [])
    vrow = validation_by_uid.get(uid, {})
    target_host = TARGET_TO_ZABBIX_HOST.get(attack.get('target_component',''), attack.get('target_component',''))
    target_zbx = [z for z in zbx_rows if z.get('host') == target_host]
    real_samples = int(vrow.get('real_zabbix_samples_target') or 0)
    nearest_delta = vrow.get('nearest_zabbix_sample_delta_seconds','')

    # Operational degradation from real Zabbix only: availability item observed down OR latency item degraded > 50 ms.
    zabbix_degraded = 'NO'
    for zr in target_zbx:
        key = zr.get('key','')
        samples = int(zr.get('samples') or 0)
        if samples <= 0:
            continue
        min_v = safe_float(zr.get('min_value'), None)
        max_v = safe_float(zr.get('max_value'), None)
        avg_v = safe_float(zr.get('avg_value'), None)
        if key.startswith('net.tcp.service[') and min_v is not None and min_v < 1:
            zabbix_degraded = 'YES'
        if key.startswith('net.tcp.service.perf[') and max_v is not None and avg_v is not None and max_v >= max(avg_v + 0.05, avg_v * 2.0):
            zabbix_degraded = 'YES'

    strong_temporal = False
    try:
        strong_temporal = nearest_delta != '' and int(nearest_delta) <= strong_window
    except Exception:
        strong_temporal = False
    correlation_strength = 'strong' if evs and real_samples >= min_real and strong_temporal else ('moderate' if evs and real_samples >= min_real else 'weak')

    corr_rows.append({
        'scenario': 'SCENARIO_D',
        'attack_uid': uid,
        'iteration': attack.get('iteration',''),
        'attack_id': attack.get('attack_id',''),
        'mitre_ics': attack.get('mitre_ics',''),
        'technique': attack.get('technique',''),
        'target_component': attack.get('target_component',''),
        'target_zabbix_host': target_host,
        'start_utc': attack.get('start_utc',''),
        'end_utc': attack.get('end_utc',''),
        'wazuh_detected': 'YES' if evs else 'NO',
        'wazuh_event_count': len(evs),
        'zabbix_real_samples_target': real_samples,
        'zabbix_real_samples_all_hosts': vrow.get('real_zabbix_samples_all_hosts',''),
        'nearest_zabbix_sample_delta_seconds': nearest_delta,
        'zabbix_degraded': zabbix_degraded,
        'http_error_observed': 'YES' if http_error else 'NO',
        'http_pre_latency_avg_s': round(pre_latency, 6),
        'http_post_latency_avg_s': round(post_latency, 6),
        'http_latency_delta_s': round(post_latency - pre_latency, 6),
        'correlation_window_seconds': strong_window,
        'correlation_strength': correlation_strength,
        'zabbix_source': 'history.get'
    })

write_csv(correlation_file, ['scenario','attack_uid','iteration','attack_id','mitre_ics','technique','target_component','target_zabbix_host','start_utc','end_utc','wazuh_detected','wazuh_event_count','zabbix_real_samples_target','zabbix_real_samples_all_hosts','nearest_zabbix_sample_delta_seconds','zabbix_degraded','http_error_observed','http_pre_latency_avg_s','http_post_latency_avg_s','http_latency_delta_s','correlation_window_seconds','correlation_strength','zabbix_source'], corr_rows)
metadata = {
    'timestamp_utc': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'scenario': 'SCENARIO_D',
    'zabbix_method': 'history.get',
    'correlation_window_seconds': strong_window,
    'zabbix_history_lookback_seconds': lookback,
    'zabbix_history_forward_seconds': forward,
    'fail_on_missing_zabbix_history': fail_missing,
    'attacks': len(attacks),
    'wazuh_events': len(wazuh_events),
    'zabbix_history_rows': len(zabbix_rows),
    'correlation_rows': len(corr_rows)
}
(evidence_dir / f'{ts}-scenario-d-correlation-metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
print(f'[OK] Correlation dataset generated with real Zabbix history.get: {correlation_file}')
PY

csv_has_data "$WAZUH_EVENTS_FILE"
csv_has_data "$CORRELATION_FILE"
csv_has_data "$ZABBIX_FILE"
csv_has_data "$ZABBIX_VALIDATION_FILE"

summary_header "Scenario D Correlation Experiment — Real Zabbix History"
summary_ok "Eventos Wazuh exportados: results/raw/scenario_d/wazuh_security_events.csv"
summary_ok "Métricas Zabbix reales exportadas con history.get: results/raw/scenario_d/zabbix_correlation_metrics.csv"
summary_ok "Validación history.get generada: results/raw/scenario_d/zabbix_history_validation.csv"
summary_ok "Dataset correlacionado generado: results/processed/correlation_dataset.csv"
summary_ok "Ventana de correlación fuerte aplicada: ${CORRELATION_WINDOW_SECONDS}s"
summary_ok "Escenario D listo para exportación final de datasets/tablas/figuras"
