# 07 — Correlación operacional-seguridad

## Objetivo

Documentar el método de correlación entre eventos de seguridad Wazuh y métricas operacionales Zabbix.

La correlación usada en este laboratorio es:

```text
event-based temporal correlation
```

No corresponde a correlación estadística Pearson/Spearman.

## Definición

Una correlación temporal válida requiere:

1. una ejecución identificada por `attack_uid`;
2. un evento Wazuh asociado;
3. una muestra Zabbix real;
4. ambos eventos dentro de la ventana temporal definida.

La ventana por defecto es:

```text
CORRELATION_WINDOW_SECONDS = 120
```

## Campos principales

| Campo | Propósito |
|---|---|
| `attack_uid` | llave única de ejecución |
| `nearest_zabbix_sample_utc` | muestra Zabbix más cercana |
| `nearest_zabbix_sample_delta_s` | delta ataque → muestra Zabbix |
| `wazuh_event_utc` | evento Wazuh asociado |
| `wazuh_event_delta_s` | delta ataque → evento Wazuh |
| `correlation_window_seconds` | ventana usada |
| `strong_temporal_correlation` | clasificación final |

## Datasets

| Archivo | Descripción |
|---|---|
| `results/processed/correlation_dataset.csv` | dataset principal de correlación |
| `results/raw/scenario_d/zabbix_history_validation.csv` | validación de histórico Zabbix por ejecución |
| `results/processed/temporal_correlation_analysis.csv` | análisis por ejecución |
| `results/tables/table_temporal_correlation_summary.csv` | resumen por técnica |

## Interpretación

La correlación fuerte indica que el evento de seguridad y la muestra operacional se encuentran temporalmente alineados dentro de la ventana definida.

Esto permite afirmar correlación temporal, no causalidad absoluta ni correlación estadística multivariable.

## Uso en paper

Redacción recomendada:

```text
The study evaluates event-based temporal correlation between security events and operational metrics within a predefined time window.
```

En español:

```text
El estudio evalúa correlación temporal basada en eventos entre alertas de seguridad y métricas operacionales dentro de una ventana temporal predefinida.
```
