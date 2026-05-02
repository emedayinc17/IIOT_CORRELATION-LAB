# 00 — Overview

## Propósito

Este laboratorio implementa un entorno IIoT reproducible sobre Kubernetes para evaluar la correlación entre monitoreo operacional y eventos de ciberseguridad usando Zabbix y Wazuh.

El laboratorio se construye de forma incremental para permitir comparación entre escenarios.

## Escenarios

| Escenario | Descripción | Estado |
|---|---|---|
| A | Foundation IIoT sin monitoreo | Implementado |
| B | Foundation IIoT + Zabbix | Implementado |
| C | Foundation IIoT + Zabbix + Wazuh | Pendiente |
| D | Correlación + ataques MITRE ATT&CK for ICS | Pendiente |

## Principio metodológico

Cada escenario debe ser reproducible, documentado, medible, congelado mediante snapshots y comparable con el escenario anterior.

## Repositorio reproducible

El laboratorio se apoya en manifiestos YAML, scripts numerados, documentación incremental, datasets CSV, snapshots Kubernetes, exports lógicos de Zabbix y metadata experimental.
