## Corrección v1.1 — resultados con deltas por ejecución

Las tablas finales deben ser regeneradas después de ejecutar el script 16 corregido:

```bash
./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/21-analyze-temporal-correlation.sh
./scripts/run/22-run-statistical-analysis.sh
```

No es necesario repetir el script 15 si la campaña de ataques ya fue ejecutada correctamente.


<!-- SCENARIO_E_NOISE_FPR_V1 -->

## Scenario E results

Scenario E produces `table_noise_fpr_summary.csv`, `table_noise_wilson_ci.csv`, `table_noise_profile_summary.csv`, and `table_noise_zabbix_quality.csv`. FPR must be reported with Wilson confidence intervals.

