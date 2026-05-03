# 01 — Arquitectura del laboratorio

## Resumen

La arquitectura está organizada por capas funcionales. Cada capa aporta una función experimental específica y se despliega sobre un clúster MicroK8s single-node.

| Capa | Namespace | Componentes principales | Estado |
|---|---|---|---|
| Foundation IIoT | `iiot-poc` | Mosquitto, sensor-simulator, health-app, telemetry-api, vulnerable-app | Implementado |
| Monitoreo operacional | `monitoring` | Zabbix Server, Zabbix Web, PostgreSQL, Zabbix Agent | Implementado |
| Seguridad | `security` | Wazuh Manager, Wazuh Indexer, Wazuh Dashboard | Implementado |
| Correlación y evidencia | filesystem repo | scripts, datasets, figures, freezes | Implementado |

## Entorno base

| Elemento | Valor esperado |
|---|---|
| Kubernetes | MicroK8s |
| Nodo | single-node |
| Sistema operativo | Ubuntu 24.04 |
| Runtime | containerd |
| CNI | Calico |
| LoadBalancer | MetalLB |
| StorageClass | microk8s-hostpath |

## Flujo lógico

```text
Foundation IIoT
  ├─ MQTT / HTTP / telemetría
  ├─ Zabbix recopila métricas operacionales
  ├─ Wazuh registra eventos de seguridad
  └─ scripts de correlación generan datasets y evidencia
```

## Foundation IIoT

La capa Foundation simula servicios IIoT básicos:

| Servicio | Propósito |
|---|---|
| `mqtt-broker` | punto de publicación MQTT para telemetría |
| `sensor-simulator` | generación de telemetría simulada |
| `health-app` | endpoint operacional de salud |
| `telemetry-api` | API de telemetría y métricas |
| `vulnerable-app` | servicio HTTP utilizado para pruebas controladas |

## Zabbix

Zabbix captura disponibilidad, latencia y valores históricos mediante checks `net.tcp.service` y `net.tcp.service.perf`.

La evidencia operacional se recupera mediante `history.get` real para evitar datasets sintéticos.

## Wazuh

Wazuh se implementa como capa de seguridad single-node/all-in-one dentro del namespace `security`.

Esta decisión evita complejidad HA que no aporta a la hipótesis principal, manteniendo reproducibilidad, control experimental y trazabilidad.

## Correlación

La correlación es temporal y basada en eventos. No se reporta como correlación estadística Pearson/Spearman.

Una correlación se considera válida cuando:

```text
existe evento Wazuh
existe muestra Zabbix real
ambos se ubican dentro de la ventana temporal definida
```

## Escenario E

El Escenario E agrega ruido operacional legítimo sin ataques para estimar falsos positivos. Usa perfiles LOW, MEDIUM y HIGH con endpoints HTTP saludables y mensajes MQTT válidos.
