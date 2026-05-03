# 16 — Roles y evidencias por escenario

## Propósito

Este documento aclara el rol metodológico de cada escenario para evitar la interpretación errónea de que A, B, C, D y E tienen la misma función experimental.

La estructura correcta es:

```text
A–C = construcción, instrumentación y validación funcional
D–E = campañas cuantitativas principales
```

## Matriz de escenarios

| Escenario | Rol | Tipo de evidencia | Profundidad estadística |
|---|---|---|---|
| A — Foundation IIoT | base funcional | pods, services, endpoints | validación técnica |
| B — Zabbix Monitoring | instrumentación operacional | hosts, items, history.get, tablas de calidad | validación instrumental |
| C — Wazuh Security | instrumentación de seguridad | dashboard/API, reglas, localfile, baseline | validación instrumental |
| D — MITRE ICS Correlation | campaña de ataque/correlación | 60 ejecuciones, deltas, bootstrap, percentiles | cuantitativa |
| E — Operational Noise/FPR | campaña de control FPR | 60 ejecuciones, ruido legítimo, Wilson CI | cuantitativa |

## Justificación

No todos los escenarios requieren el mismo número de repeticiones porque no responden a la misma pregunta.

A–C establecen condiciones necesarias para que D/E sean válidos:

- A confirma que el entorno IIoT existe y opera.
- B confirma que Zabbix captura métricas reales.
- C confirma que Wazuh registra eventos de seguridad.
- D mide detección y correlación ante ataques.
- E mide falsos positivos bajo operación legítima.

## Redacción recomendada para el paper

> Los escenarios A–C se utilizaron para establecer y validar la infraestructura experimental y la instrumentación de monitoreo/seguridad. Las campañas cuantitativas principales se concentraron en los escenarios D y E, donde se evaluaron detección, correlación temporal y falsos positivos mediante ejecuciones repetidas.

## Evidencia automatizada

La preparación de escenarios se valida con:

```bash
./scripts/run/28-validate-scenario-readiness.sh
```

Salidas:

```text
results/tables/table_scenario_readiness.csv
evidence/readiness/scenario_readiness_summary.json
evidence/readiness/scenario_readiness_summary.md
```

## Criterio de interpretación

Un estado `WARN` en A, B o C no necesariamente invalida D/E, pero debe revisarse para garantizar que la documentación y evidencia estén completas.

Un estado `WARN` en D o E sí debe resolverse antes de considerar el paquete final como paper-ready.


## Capa de ejecución paper-final

Para no obligar al usuario a escribir variables manualmente, se agregó una capa de ejecución parametrizada:

| Script | Rol |
|---|---|
| `29-run-paper-final-campaign.sh` | Ejecuta campañas D/E y análisis usando `config/experiment.conf`. |
| `30-validate-paper-readiness.sh` | Valida infraestructura, evidencias y readiness sin ejecutar ataques. |
| `31-show-paper-results.sh` | Muestra tablas, figuras y rutas clave para revisión. |
| `32-verify-final-freeze.sh` | Verifica el último freeze con `SHA256SUMS`. |

Estos scripts conservan la lógica existente y llaman a los scripts `15` a `28` según corresponda.
