# 11 — Experimental Design

## Objetivo

Formalizar las decisiones experimentales utilizadas en el laboratorio para responder observaciones de reproducibilidad, transparencia técnica y justificación metodológica.

## Matriz de configuración experimental

| Parámetro | Valor recomendado | Justificación |
|---|---:|---|
| Validation run | 20 s a 10 min | verificar despliegue, conectividad y collectors |
| Official run | 30 min | capturar variabilidad operacional suficiente para comparar escenarios |
| Endurance run | 6 h | validar estabilidad de largo plazo |
| Iterations official | 900 | con intervalo de 2 s equivale a 30 min |
| Sleep interval | 2 s | granularidad suficiente sin sobrecargar el laboratorio |
| MQTT interval | 2 s | simula telemetría periódica continua |
| Replicaciones | 20 | reduce variabilidad y permite análisis estadístico |
| Storage Zabbix | 20 Gi | conserva configuración e histórico operacional |
| IPs estáticas | Sí | asegura endpoints reproducibles |

## Realista vs simulado

| Aspecto | Clasificación | Comentario |
|---|---|---|
| MQTT | Realista | protocolo frecuente en IIoT |
| Telemetría periódica | Realista | representa sensores industriales |
| Zabbix | Realista | herramienta real de monitoreo |
| Wazuh | Realista | SIEM/XDR real |
| Kubernetes | Medio reproducible | no representa necesariamente producción minera |
| PLC físicos | Simulado/ausente | no se usan dispositivos físicos |
| SCADA real | Simulado/ausente | se modelan flujos representativos |
| red minera productiva | Simulado/ausente | se usa red de laboratorio |

## Limitaciones

El laboratorio reproduce comportamientos operacionales, telemetría y eventos representativos de entornos IIoT industriales, pero no incluye PLC físicos, red minera productiva ni sistemas SCADA propietarios. Esta limitación se considera aceptable porque el objetivo es evaluar correlación operacional-seguridad bajo condiciones controladas y reproducibles.


## Decisión experimental para Escenario C

| Decisión | Valor | Justificación |
|---|---|---|
| Modelo Wazuh | single-node/all-in-one | suficiente para laboratorio reproducible y controlado |
| Namespace | `security` | separación lógica de la capa de seguridad |
| HA/cluster Wazuh | excluido | no aporta a la hipótesis de correlación |
| Kubernetes security | excluido | fuera del alcance del paper |
| Eventos C | baseline sin ataque | permite comparar contra Escenario D |
| Técnicas MITRE ICS | preparadas, no ejecutadas | se evaluarán en Escenario D |

## Racional científico

El uso de Wazuh single-node reduce fuentes de variabilidad ajenas a la hipótesis. La investigación busca observar si la combinación de métricas operacionales y eventos de seguridad mejora la trazabilidad de incidentes IIoT, no evaluar resiliencia de un SIEM distribuido.

La separación entre Escenario C y D permite que el paper diferencie claramente entre instrumentación de seguridad y evaluación bajo ataque.
