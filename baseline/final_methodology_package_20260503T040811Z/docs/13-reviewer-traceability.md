# 13 — Trazabilidad ante reviewers

## Mapeo general

| Pregunta reviewer | Evidencia |
|---|---|
| ¿Cómo se desplegó? | YAMLs, scripts, snapshots Kubernetes |
| ¿Cómo se ejecutó? | metadata JSON |
| ¿Qué versiones se usaron? | matriz de versiones e inventario |
| ¿Qué ocurrió? | datasets raw |
| ¿Cómo se midió? | scripts 19–24 y tablas |
| ¿Cómo se correlacionó? | `correlation_dataset.csv` y deltas por `attack_uid` |
| ¿Cómo se reproduce? | freezes `.tar.gz` y `SHA256SUMS` |

## Observaciones cubiertas

| Observación | Respuesta del laboratorio |
|---|---|
| Clarificar scripts de ataque | scripts 15–18 y metadata |
| Documentar cargas/tráfico | metadata D/E y tablas de perfil |
| Proveer estadística | Wilson CI, bootstrap CI, percentiles |
| Controlar falsos positivos | Escenario E |
| Diferenciar ruido vs ataque | `scenario`, `attack_uid`, `noise_uid` |
| Evitar datasets ad hoc | normalización y esquema común |
| Reproducibilidad | freezes por escenario |

## Escenario E

| Evidencia | Archivo |
|---|---|
| ruido legítimo | `results/raw/scenario_e/noise_events.csv` |
| endpoints saludables | `http_endpoint_validation_summary.json` |
| observaciones HTTP | `noise_http_observations.csv` |
| observaciones MQTT | `noise_mqtt_observations.csv` |
| FPR | `table_noise_fpr_summary.csv` |
| Wilson CI | `table_noise_wilson_ci.csv` |
| Freeze | `baseline/scenario_e_noise_fpr_*.tar.gz` |

## Redacción recomendada

```text
The laboratory evaluated controlled attack scenarios and a separate legitimate operational-noise control scenario to estimate false positives under normal IIoT variability.
```
