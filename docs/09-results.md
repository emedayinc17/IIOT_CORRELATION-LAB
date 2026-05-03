# 09 — Resultados y evidencias

## Organización

| Carpeta | Uso |
|---|---|
| `results/raw/` | datos originales |
| `results/processed/` | datasets derivados |
| `results/tables/` | tablas para análisis/paper |
| `results/figures/` | figuras SVG |
| `evidence/` | logs e inventario |
| `baseline/` | freezes reproducibles |

## Escenario D — resultados principales

La campaña D final genera:

| Archivo | Descripción |
|---|---|
| `results/raw/scenario_d/mitre_ics_attacks.csv` | ejecuciones de ataque |
| `results/raw/scenario_d/wazuh_security_events.csv` | eventos Wazuh |
| `results/raw/scenario_d/zabbix_correlation_metrics.csv` | métricas Zabbix reales |
| `results/raw/scenario_d/zabbix_history_validation.csv` | validación por `attack_uid` |
| `results/processed/correlation_dataset.csv` | correlación por ejecución |

Resultados interpretables:

- detección Wazuh por técnica;
- muestras Zabbix reales;
- correlación temporal fuerte;
- percentiles y bootstrap CI sobre deltas por ejecución.

## Escenario E — resultados principales

El Escenario E genera:

| Archivo | Descripción |
|---|---|
| `results/raw/scenario_e/noise_events.csv` | ejecuciones de ruido legítimo |
| `results/raw/scenario_e/noise_http_observations.csv` | tráfico HTTP legítimo |
| `results/raw/scenario_e/noise_mqtt_observations.csv` | publicaciones MQTT legítimas |
| `results/raw/scenario_e/http_endpoint_validation_summary.json` | validación de endpoints HTTP saludables |
| `results/processed/scenario_e/noise_fpr_dataset.csv` | dataset FPR |
| `results/tables/table_noise_fpr_summary.csv` | FPR por perfil y total |
| `results/tables/table_noise_wilson_ci.csv` | intervalos Wilson |
| `results/tables/table_noise_profile_summary.csv` | resumen operacional por perfil |
| `results/figures/figure_noise_fpr_by_profile.svg` | figura FPR por perfil |

## Interpretación FPR

Aunque el FPR observado sea 0, debe reportarse con intervalo Wilson:

```text
FPR observado = 0/N
Wilson 95% CI = [0%, límite superior]
```

Esto evita afirmar falsamente ausencia absoluta de falsos positivos.

## Limitación

Los resultados corresponden a un laboratorio controlado y reproducible. No deben extrapolarse directamente a una red industrial productiva sin validación adicional.
