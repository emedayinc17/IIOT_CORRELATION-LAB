# Experimental Metadata Final

- Metadata version: `1.1`
- Generated UTC: `2026-05-02T21:14:05Z`
- Experiment ID: `scenario_d_final`
- Dataset version: `1.1`

## Campaign parameters
- `iterations_recommended`: `20`
- `baseline_warmup_seconds`: `60`
- `inter_attack_cooldown_seconds`: `10`
- `dos_requests`: `500`
- `dos_concurrency`: `30`
- `attack_duration_seconds`: `30`
- `http_probe_interval_seconds`: `2`
- `zabbix_polling_seconds`: `5`
- `correlation_window_seconds`: `120`
- `zabbix_history_lookback_seconds`: `120`
- `zabbix_history_forward_seconds`: `120`

## Normalization summary
- `generated_utc`: `2026-05-02T21:14:05Z`
- `campaign_attack_uids`: `60`
- `events_normalized_rows`: `199`
- `metrics_normalized_rows`: `11566`
- `correlation_normalized_rows`: `60`
- `excluded_wazuh_events_not_in_final_campaign`: `0`
- `events_missing_required_fields`: `0`
- `metrics_missing_required_fields`: `0`
- `correlation_missing_required_fields`: `0`
- `schema_file`: `results/processed/normalized/dataset_schema.json`

## Methodological note
Correlation is event-based temporal correlation within a predefined window, not Pearson/Spearman statistical correlation.
