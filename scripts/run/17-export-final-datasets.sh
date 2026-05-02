#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

RAW_D="${ROOT_DIR}/results/raw/scenario_d"
PROCESSED="${ROOT_DIR}/results/processed"
TABLES="${ROOT_DIR}/results/tables"
FIGURES="${ROOT_DIR}/results/figures"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
CORR="${PROCESSED}/correlation_dataset.csv"
ZBX_VALIDATION="${RAW_D}/zabbix_history_validation.csv"

mkdir -p "$RAW_D" "$PROCESSED" "$TABLES" "$FIGURES"
log "Exportando datasets finales, tablas y figuras del Escenario D con métricas Zabbix reales"
[[ -s "$CORR" ]] || fail "No existe dataset correlacionado: ${CORR}. Ejecuta 16-run-correlation-experiment.sh."
[[ -s "$ZBX_VALIDATION" ]] || fail "No existe validación Zabbix real: ${ZBX_VALIDATION}. Ejecuta 16-run-correlation-experiment.sh actualizado."

export RAW_D PROCESSED TABLES FIGURES TS CORR ZBX_VALIDATION
python3 <<'PY'
import csv, json, statistics
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
import os

raw_d = Path(os.environ['RAW_D'])
processed = Path(os.environ['PROCESSED'])
tables = Path(os.environ['TABLES'])
figures = Path(os.environ['FIGURES'])
ts = os.environ['TS']
corr = Path(os.environ['CORR'])
zbx_validation = Path(os.environ['ZBX_VALIDATION'])

def read_csv(path):
    with path.open(newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))

def write_csv(path, fieldnames, rows):
    with path.open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader(); w.writerows(rows)

def safe_float(v):
    try: return float(v)
    except Exception: return 0.0

def safe_int(v):
    try: return int(float(v))
    except Exception: return 0

rows = read_csv(corr)
zbx_rows = read_csv(zbx_validation)
if not rows:
    raise RuntimeError('correlation_dataset.csv no contiene filas de datos')
if not any(safe_int(r.get('zabbix_real_samples_target')) > 0 for r in rows):
    raise RuntimeError('No hay muestras Zabbix reales en correlation_dataset.csv. No se exportarán tablas con métricas dummy.')

by_attack = defaultdict(list)
for r in rows:
    by_attack[r['attack_id']].append(r)

attack_detection = []
correlation_latency = []
sla_impact = []
zabbix_quality = []
for attack_id, vals in sorted(by_attack.items()):
    total = len(vals)
    detected = sum(1 for r in vals if r.get('wazuh_detected') == 'YES')
    strong = sum(1 for r in vals if r.get('correlation_strength') == 'strong')
    moderate = sum(1 for r in vals if r.get('correlation_strength') == 'moderate')
    real_zbx = sum(1 for r in vals if safe_int(r.get('zabbix_real_samples_target')) > 0)
    degraded = sum(1 for r in vals if r.get('zabbix_degraded') == 'YES')
    http_errors = sum(1 for r in vals if r.get('http_error_observed') == 'YES')
    deltas = [safe_float(r.get('http_latency_delta_s')) for r in vals]
    post_lat = [safe_float(r.get('http_post_latency_avg_s')) for r in vals]
    nearest = [safe_int(r.get('nearest_zabbix_sample_delta_seconds')) for r in vals if str(r.get('nearest_zabbix_sample_delta_seconds','')).strip() != '']

    attack_detection.append({
        'scenario': 'SCENARIO_D',
        'attack_id': attack_id,
        'mitre_ics': vals[0].get('mitre_ics',''),
        'technique': vals[0].get('technique',''),
        'executions': total,
        'wazuh_detected': detected,
        'detection_rate_percent': round(100*detected/total, 2) if total else 0,
        'zabbix_real_sampled_executions': real_zbx,
        'zabbix_real_sampling_percent': round(100*real_zbx/total, 2) if total else 0,
        'strong_correlation_count': strong,
        'strong_correlation_percent': round(100*strong/total, 2) if total else 0,
        'moderate_correlation_count': moderate
    })
    correlation_latency.append({
        'scenario': 'SCENARIO_D',
        'attack_id': attack_id,
        'executions': total,
        'avg_http_latency_delta_s': round(sum(deltas)/len(deltas), 6) if deltas else 0,
        'max_http_latency_delta_s': round(max(deltas), 6) if deltas else 0,
        'avg_post_latency_s': round(sum(post_lat)/len(post_lat), 6) if post_lat else 0,
        'avg_nearest_zabbix_sample_delta_s': round(sum(nearest)/len(nearest), 2) if nearest else ''
    })
    sla_impact.append({
        'scenario': 'SCENARIO_D',
        'attack_id': attack_id,
        'executions': total,
        'zabbix_operational_degradation_count': degraded,
        'zabbix_operational_degradation_percent': round(100*degraded/total, 2) if total else 0,
        'http_error_observed_count': http_errors,
        'http_error_observed_percent': round(100*http_errors/total, 2) if total else 0
    })
    zabbix_quality.append({
        'scenario': 'SCENARIO_D',
        'attack_id': attack_id,
        'executions': total,
        'executions_with_real_zabbix_history': real_zbx,
        'real_zabbix_history_percent': round(100*real_zbx/total, 2) if total else 0,
        'min_nearest_zabbix_sample_delta_s': min(nearest) if nearest else '',
        'max_nearest_zabbix_sample_delta_s': max(nearest) if nearest else '',
        'avg_nearest_zabbix_sample_delta_s': round(sum(nearest)/len(nearest), 2) if nearest else ''
    })

write_csv(tables / 'table_attack_detection.csv', ['scenario','attack_id','mitre_ics','technique','executions','wazuh_detected','detection_rate_percent','zabbix_real_sampled_executions','zabbix_real_sampling_percent','strong_correlation_count','strong_correlation_percent','moderate_correlation_count'], attack_detection)
write_csv(tables / 'table_correlation_latency.csv', ['scenario','attack_id','executions','avg_http_latency_delta_s','max_http_latency_delta_s','avg_post_latency_s','avg_nearest_zabbix_sample_delta_s'], correlation_latency)
write_csv(tables / 'table_sla_impact.csv', ['scenario','attack_id','executions','zabbix_operational_degradation_count','zabbix_operational_degradation_percent','http_error_observed_count','http_error_observed_percent'], sla_impact)
write_csv(tables / 'table_zabbix_history_quality.csv', ['scenario','attack_id','executions','executions_with_real_zabbix_history','real_zabbix_history_percent','min_nearest_zabbix_sample_delta_s','max_nearest_zabbix_sample_delta_s','avg_nearest_zabbix_sample_delta_s'], zabbix_quality)
write_csv(processed / 'attack_effectiveness.csv', ['scenario','attack_id','mitre_ics','technique','executions','wazuh_detected','detection_rate_percent','zabbix_real_sampled_executions','zabbix_real_sampling_percent','strong_correlation_count','strong_correlation_percent','moderate_correlation_count'], attack_detection)

def svg_bar(path, title, data, value_key, label_key='attack_id', width=820, height=420):
    margin = 70
    values = [safe_float(d.get(value_key)) for d in data]
    max_val = max(values + [1])
    bar_w = (width - 2*margin) / max(len(data), 1) * 0.65
    gap = (width - 2*margin) / max(len(data), 1)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">', '<rect width="100%" height="100%" fill="white"/>', f'<text x="{width/2}" y="35" text-anchor="middle" font-family="Arial" font-size="20">{title}</text>', f'<line x1="{margin}" y1="{height-margin}" x2="{width-margin}" y2="{height-margin}" stroke="black"/>', f'<line x1="{margin}" y1="{margin}" x2="{margin}" y2="{height-margin}" stroke="black"/>']
    for i, d in enumerate(data):
        val = safe_float(d.get(value_key))
        x = margin + i*gap + (gap-bar_w)/2
        bh = (height - 2*margin) * (val / max_val) if max_val else 0
        y = height - margin - bh
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_w:.1f}" height="{bh:.1f}" fill="#cccccc" stroke="black"/>')
        parts.append(f'<text x="{x+bar_w/2:.1f}" y="{max(y-6, 50):.1f}" text-anchor="middle" font-family="Arial" font-size="12">{val:.2f}</text>')
        parts.append(f'<text x="{x+bar_w/2:.1f}" y="{height-margin+22}" text-anchor="middle" font-family="Arial" font-size="13">{d[label_key]}</text>')
    parts.append('</svg>')
    path.write_text('\n'.join(parts), encoding='utf-8')

svg_bar(figures / 'figure_detection_comparison.svg', 'Wazuh detection rate by MITRE ICS technique', attack_detection, 'detection_rate_percent')
svg_bar(figures / 'figure_operational_vs_security.svg', 'Strong temporal correlation percentage by technique', attack_detection, 'strong_correlation_percent')
svg_bar(figures / 'figure_attack_timeline.svg', 'Average HTTP latency delta by technique', correlation_latency, 'avg_http_latency_delta_s')
svg_bar(figures / 'figure_zabbix_history_quality.svg', 'Real Zabbix history coverage by technique', zabbix_quality, 'real_zabbix_history_percent')

summary = {
    'timestamp_utc': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'scenario': 'SCENARIO_D',
    'input': str(corr),
    'zabbix_history_validation': str(zbx_validation),
    'tables': ['results/tables/table_attack_detection.csv','results/tables/table_correlation_latency.csv','results/tables/table_sla_impact.csv','results/tables/table_zabbix_history_quality.csv'],
    'figures': ['results/figures/figure_detection_comparison.svg','results/figures/figure_operational_vs_security.svg','results/figures/figure_attack_timeline.svg','results/figures/figure_zabbix_history_quality.svg'],
    'rows': len(rows),
    'note': 'Tables are generated only when correlation_dataset.csv contains real Zabbix history.get samples.'
}
(processed / 'scenario_d_final_export_metadata.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print('[OK] Final tables and figures generated from real Zabbix history')
PY

csv_has_data "${TABLES}/table_attack_detection.csv"
csv_has_data "${TABLES}/table_correlation_latency.csv"
csv_has_data "${TABLES}/table_sla_impact.csv"
csv_has_data "${TABLES}/table_zabbix_history_quality.csv"
csv_has_data "${PROCESSED}/attack_effectiveness.csv"
[[ -s "${FIGURES}/figure_detection_comparison.svg" ]] || fail "No se generó figure_detection_comparison.svg"
[[ -s "${FIGURES}/figure_operational_vs_security.svg" ]] || fail "No se generó figure_operational_vs_security.svg"
[[ -s "${FIGURES}/figure_attack_timeline.svg" ]] || fail "No se generó figure_attack_timeline.svg"
[[ -s "${FIGURES}/figure_zabbix_history_quality.svg" ]] || fail "No se generó figure_zabbix_history_quality.svg"

summary_header "Scenario D Final Dataset Export — Real Zabbix Metrics"
summary_ok "Tabla generada: results/tables/table_attack_detection.csv"
summary_ok "Tabla generada: results/tables/table_correlation_latency.csv"
summary_ok "Tabla generada: results/tables/table_sla_impact.csv"
summary_ok "Tabla generada: results/tables/table_zabbix_history_quality.csv"
summary_ok "Dataset procesado: results/processed/attack_effectiveness.csv"
summary_ok "Figuras SVG generadas en results/figures/"
summary_ok "Escenario D listo para freeze reproducible con métricas Zabbix reales"
