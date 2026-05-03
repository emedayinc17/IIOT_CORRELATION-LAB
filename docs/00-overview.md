# 00 — Visión general del laboratorio

## Propósito

Este repositorio implementa un laboratorio reproducible para evaluar correlación temporal basada en eventos entre monitoreo operacional y eventos de seguridad en un entorno IIoT aplicado a Minería 4.0.

El foco del laboratorio es:

```text
IIoT + Zabbix + Wazuh + correlación temporal + control de falsos positivos
```

Kubernetes se utiliza únicamente como medio reproducible de despliegue. No es el objeto de estudio.

## Estado de escenarios

| Escenario | Estado | Propósito |
|---|---|---|
| A — Foundation IIoT | Implementado | Desplegar servicios IIoT base y generar baseline operacional inicial |
| B — Zabbix Monitoring | Implementado | Capturar métricas operacionales reales con Zabbix |
| C — Wazuh Security | Implementado | Registrar eventos de seguridad y reglas MITRE ICS en Wazuh |
| D — MITRE ICS Correlation | Implementado | Ejecutar ataques controlados y correlacionar Wazuh/Zabbix por `attack_uid` |
| E — Operational Noise/FPR | Implementado | Medir falsos positivos bajo ruido operacional legítimo |

## Preguntas experimentales que responde el laboratorio

| Pregunta | Evidencia |
|---|---|
| ¿Cómo se desplegó? | YAMLs, scripts y snapshots Kubernetes |
| ¿Cómo se ejecutó? | metadata experimental y parámetros de corrida |
| ¿Qué versiones se usaron? | inventario y matriz de versiones |
| ¿Qué ocurrió? | datasets raw |
| ¿Cómo se midió? | scripts estadísticos y tablas derivadas |
| ¿Cómo se correlacionó? | datasets por `attack_uid` y deltas temporales |
| ¿Cómo se reproduce? | freezes `.tar.gz` y `SHA256SUMS` |

## Alcance

El laboratorio evalúa:

- detección de eventos MITRE ATT&CK for ICS controlados;
- correlación temporal operacional-seguridad;
- observabilidad mediante Zabbix `history.get`;
- eventos de seguridad mediante Wazuh;
- calidad de datasets y trazabilidad;
- falsos positivos bajo ruido operacional legítimo.

## Fuera de alcance

No se evalúa:

- alta disponibilidad de Kubernetes;
- SIEM distribuido o HA;
- hardening Kubernetes;
- service mesh;
- chaos engineering;
- benchmark de performance;
- ML/anomaly detection;
- resiliencia industrial extrema.

## Política de idioma

La documentación principal del repositorio se mantiene en español. El archivo `README.en.md` provee una vista ejecutiva en inglés para lectores internacionales.

Los nombres técnicos, campos de datasets, técnicas MITRE ATT&CK for ICS y rutas de archivos se mantienen en inglés cuando corresponda por convención técnica.
