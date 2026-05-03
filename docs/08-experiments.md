# 08 — Escenarios experimentales

## Resumen

| Escenario | Estado | Propósito |
|---|---|---|
| A | Implementado | Foundation IIoT |
| B | Implementado | Zabbix Monitoring |
| C | Implementado | Wazuh Security |
| D | Implementado | Ataques MITRE ICS y correlación |
| E | Implementado | Ruido operacional y FPR |

## Escenario A — Foundation IIoT

Despliega servicios IIoT base y valida disponibilidad inicial.

## Escenario B — Zabbix Monitoring

Configura monitoreo operacional con Zabbix y obtiene histórico real mediante `history.get`.

## Escenario C — Wazuh Security

Implementa Wazuh single-node/all-in-one para registrar eventos de seguridad y reglas MITRE ICS.

## Escenario D — MITRE ATT&CK for ICS

Ejecuta técnicas controladas:

| Técnica | Descripción |
|---|---|
| T0809 | Unauthorized Command Message |
| T0814 | Data Manipulation |
| T0860 | Denial of Service |

La campaña final usa 20 iteraciones por técnica y genera 60 ejecuciones identificadas por `attack_uid`.

## Escenario E — Operational Noise / False Positive Control

El Escenario E ejecuta ruido operacional legítimo, no ataques.

Objetivo:

```text
estimar falsos positivos frente a T0809, T0814 y T0860
```

## Perfiles de ruido

| Perfil | HTTP concurrency | MQTT messages | Interpretación |
|---|---:|---:|---|
| LOW | 5 | 20 | operación tranquila |
| MEDIUM | 10 | 40 | operación normal activa |
| HIGH | 20 | 80 | operación intensa legítima |

## Endpoints HTTP saludables

Escenario E usa únicamente rutas validadas con HTTP 200:

| Servicio | Endpoint |
|---|---|
| health-app | `/health` |
| telemetry-api | `/health` |
| telemetry-api | `/metrics` |
| telemetry-api | `/telemetry` |
| vulnerable-app | `/health` |

No se usan rutas raíz que devuelvan 404/000.

## Comandos Escenario E

```bash
ITERATIONS_PER_PROFILE=20 \
NOISE_DURATION_SECONDS=30 \
INTER_NOISE_COOLDOWN_SECONDS=10 \
./scripts/run/23-run-operational-noise-control.sh

./scripts/run/24-analyze-false-positive-rate.sh
./scripts/run/25-freeze-noise-control-results.sh
```

## Métrica FPR

```text
FPR = ejecuciones de ruido clasificadas erróneamente como ataque / total de ejecuciones de ruido
```

El FPR se reporta con intervalo Wilson 95%.
