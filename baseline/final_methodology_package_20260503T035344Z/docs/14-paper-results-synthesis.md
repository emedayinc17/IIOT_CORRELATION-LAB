# 14 — Síntesis de resultados para paper

## Escenario D — campaña de ataque/correlación

El Escenario D evalúa tres técnicas MITRE ATT&CK for ICS:

- T0809 — Unauthorized Command Message.
- T0814 — Data Manipulation.
- T0860 — Denial of Service.

La campaña final utiliza identificadores por ejecución (`attack_uid`) y correlaciona eventos Wazuh con muestras históricas reales de Zabbix.

Redacción sugerida:

> El Escenario D produjo 60 ejecuciones de ataque distribuidas en tres técnicas MITRE ATT&CK for ICS. Para cada ejecución, el pipeline registró un evento de seguridad Wazuh y recuperó la muestra histórica real de Zabbix más cercana. La correlación temporal se evaluó mediante deltas por ejecución dentro de una ventana temporal predefinida.

## Escenario E — ruido operacional/FPR

El Escenario E evalúa ruido operacional legítimo bajo perfiles LOW, MEDIUM y HIGH.

Redacción sugerida:

> El Escenario E ejecutó 60 corridas de ruido operacional legítimo distribuidas en perfiles LOW, MEDIUM y HIGH. La campaña generó observaciones HTTP exitosas contra endpoints saludables validados y mensajes MQTT legítimos. No se observaron falsos positivos asociados con T0809, T0814 o T0860. El FPR observado fue 0/60, con un límite superior Wilson al 95% de 6.02%.

## Precisión terminológica

Usar:

```text
correlación temporal basada en eventos
```

No usar:

```text
correlación Pearson/Spearman
```

Para la tabla tipo MTTD, usar:

```text
event-based detection registration delta
```

No afirmar MTTD productivo salvo que se mida explícitamente en condiciones productivas.
