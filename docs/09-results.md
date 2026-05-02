# 09. Results

## Scenario D correction: real Zabbix metrics

Scenario D must not treat empty or cached Zabbix values as operational evidence. The correlation workflow therefore uses the Zabbix API `history.get` method to extract real historical samples for the items created in Scenario B.

The following files are expected after the corrected workflow:

```text
results/raw/scenario_d/zabbix_correlation_metrics.csv
results/raw/scenario_d/zabbix_history_validation.csv
results/processed/correlation_dataset.csv
results/tables/table_zabbix_history_quality.csv
```

A correlation is considered strong only when:

1. a Wazuh security event exists for the attack UID,
2. Zabbix returned real historical samples for the target component,
3. the nearest Zabbix sample is within the configured correlation window.

If Zabbix does not return real history for the target component, the script fails by default instead of generating dummy operational degradation values. This protects the validity of the experimental results and avoids overstating the operational impact of the attacks.


## Calibración paper-final Escenario D

La corrida final del Escenario D debe diferenciarse de las pruebas funcionales rápidas. Para sustentar correlación operacional + seguridad, se usa polling Zabbix calibrado mediante `ZABBIX_ITEM_DELAY=5s`, ataques con duración controlada (`ATTACK_DURATION_SECONDS`), mayor intensidad (`DOS_REQUESTS`, `DOS_CONCURRENCY`) y ventanas de correlación acotadas (`ZABBIX_HISTORY_LOOKBACK_SECONDS=120`, `ZABBIX_HISTORY_FORWARD_SECONDS=120`).

Parámetros recomendados para ejecución final reproducible:

```bash
ZABBIX_ITEM_DELAY=5s ./scripts/run/06-configure-zabbix-monitoring.sh
ITERATIONS=20 SLEEP_SECONDS=5 BASELINE_WARMUP_SECONDS=60 INTER_ATTACK_COOLDOWN_SECONDS=10 DOS_REQUESTS=500 DOS_CONCURRENCY=30 ATTACK_DURATION_SECONDS=30 HTTP_PROBE_INTERVAL_SECONDS=2 ./scripts/run/15-run-mitre-ics-attacks.sh
CORRELATION_WINDOW_SECONDS=120 ZABBIX_HISTORY_LOOKBACK_SECONDS=120 ZABBIX_HISTORY_FORWARD_SECONDS=120 ./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
```

Las pruebas rápidas anteriores se consideran validación técnica/piloto; la campaña final debe reportarse con los parámetros anteriores o con valores explícitamente documentados en la metadata generada.
