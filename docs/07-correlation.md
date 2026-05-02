# 07 — Correlation

## Propósito

La correlación se ejecutará formalmente en el Escenario D, una vez que existan métricas operacionales de Zabbix, eventos de seguridad de Wazuh y ataques MITRE ATT&CK for ICS ejecutados bajo condiciones controladas.

El Escenario C prepara la fuente de seguridad y valida que Wazuh pueda recibir eventos estructurados con timestamps comparables.

## Fuentes de datos

| Fuente | Escenario | Dataset | Uso |
|---|---|---|---|
| Foundation IIoT | A/B/C/D | HTTP/MQTT/K8s collectors | estado operacional base |
| Zabbix | B/C/D | `zabbix_items_snapshot.csv` y exports | disponibilidad/latencia/triggers |
| Wazuh | C/D | `wazuh_security_baseline.csv`, alerts/archives | eventos de seguridad |
| Ataques MITRE ICS | D | datasets por técnica | evaluación correlacionada |

## Clave de correlación

La correlación se basará en:

- `timestamp_utc`;
- `scenario`;
- `component`;
- `attack_id`;
- ventanas temporales de preataque, ataque y recuperación;
- estado operacional reportado por Zabbix;
- alerta o evento de seguridad reportado por Wazuh.

## Rol del Escenario C

El Escenario C no mide aún eficacia de detección bajo ataque. Su función es establecer la capa SIEM/XDR reproducible y generar un baseline de seguridad sin ataque.

Esto permite diferenciar en Escenario D entre:

| Estado | Interpretación |
|---|---|
| Evento de baseline | condición normal instrumentada |
| Evento de ataque | actividad MITRE ICS inducida |
| Cambio Zabbix sin alerta Wazuh | impacto operacional no clasificado como seguridad |
| Alerta Wazuh sin cambio Zabbix | evento de seguridad sin degradación operacional visible |
| Alerta Wazuh + degradación Zabbix | correlación operacional-seguridad fuerte |

## Salida esperada para el paper

La correlación deberá producir tablas comparativas por escenario y técnica, por ejemplo:

| Escenario | Técnica | Zabbix availability | Zabbix latency p95 | Wazuh event | Correlación |
|---|---|---:|---:|---|---|
| C | NONE | baseline | baseline | baseline_security_probe | baseline |
| D | T0809 | variable | variable | MITRE ICS event | evaluable |
| D | T0814 | variable | variable | MITRE ICS event | evaluable |
| D | T0860 | variable | variable | MITRE ICS event | evaluable |
