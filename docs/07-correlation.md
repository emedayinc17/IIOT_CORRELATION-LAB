## Corrección v1.1 — deltas temporales por ejecución

El dataset `results/processed/correlation_dataset.csv` debe incluir, por cada `attack_uid`, los campos:

```text
nearest_zabbix_sample_utc
nearest_zabbix_sample_delta_s
wazuh_event_utc
wazuh_event_delta_s
correlation_window_seconds
```

Estos campos permiten calcular percentiles, bootstrap CI y tablas de latencia temporal usando deltas por ejecución individual, no promedios agregados por técnica.
