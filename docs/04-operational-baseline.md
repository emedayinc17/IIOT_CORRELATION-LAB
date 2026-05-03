# 04 — Baseline operacional

## Objetivo

Ejecutar una línea base operacional del entorno IIoT antes de introducir monitoreo Zabbix, seguridad Wazuh o ataques MITRE ICS.

El baseline permite comparar el comportamiento normal del laboratorio con escenarios posteriores.

## Comandos

Corrida rápida:

```bash
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
```

Corrida extendida, si se requiere mayor evidencia:

```bash
ITERATIONS=900 SLEEP_SECONDS=2 DURATION_SECONDS=1800 ./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
```

## Métricas observadas

| Métrica | Propósito |
|---|---|
| disponibilidad HTTP | verificar que servicios respondan |
| latencia HTTP | establecer comportamiento base |
| estado de pods | validar estabilidad del laboratorio |
| endpoints | confirmar rutas funcionales |

## Artefactos esperados

| Ruta | Descripción |
|---|---|
| `results/raw/` | observaciones operacionales base |
| `baseline/` | freeze del baseline |
| `evidence/inventory/` | snapshots e inventario |
| `SHA256SUMS` | integridad de artefactos congelados |

## Criterios de éxito

```text
[OK] Servicios IIoT responden
[OK] No hay errores operacionales críticos
[OK] Dataset raw generado
[OK] Freeze reproducible creado
[OK] Evidencia exportada
```

## Interpretación

Este baseline no busca detectar ataques ni medir seguridad. Su función es establecer un punto de comparación operacional para los escenarios B, C, D y E.
