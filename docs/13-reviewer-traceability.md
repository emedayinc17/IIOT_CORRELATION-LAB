## Evidencia de correlación por ejecución

Para cerrar la brecha estadística, la correlación final se basa en deltas por ejecución (`attack_uid`) y no únicamente en promedios agregados.

| Campo | Propósito |
|---|---|
| `nearest_zabbix_sample_delta_s` | distancia temporal ataque → muestra Zabbix |
| `wazuh_event_delta_s` | distancia temporal ataque → evento Wazuh |
| `strong_temporal_correlation` | validez dentro de la ventana definida |
| `correlation_window_seconds` | ventana usada para clasificación |


<!-- SCENARIO_E_NOISE_FPR_V1 -->

## Reviewer traceability — Scenario E

| Reviewer concern | Scenario E evidence |
|---|---|
| False positives | `table_noise_fpr_summary.csv` |
| Operational variability | LOW/MEDIUM/HIGH noise profiles |
| Statistical confidence | Wilson CI for FPR |
| Reproducibility | `baseline/scenario_e_noise_fpr_*.tar.gz` |
| Separation between attacks and noise | `noise_uid` and `scenario=SCENARIO_E` |

