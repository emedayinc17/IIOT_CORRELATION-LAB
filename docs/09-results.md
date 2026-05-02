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
