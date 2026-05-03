# 21 - Ejecución por escenario mediante wrappers | Scenario execution using wrappers

## Objetivo | Objective

Reducir complejidad operativa agrupando los scripts técnicos `00–28` en wrappers por escenario. | Reduce operational complexity by grouping technical scripts `00–28` into scenario wrappers.

## Wrappers disponibles | Available wrappers

| Escenario | Script rápido | Scripts técnicos agrupados |
|---|---|---|
| A - Foundation IIoT | `33-run-scenario-a-foundation.sh` | `01`, `02`, `03` y opcional `00` |
| B - Zabbix Monitoring | `34-run-scenario-b-zabbix.sh` | `04`, `05`, `06`, `07`, `08`, `09`, `10` |
| C - Wazuh Security | `35-run-scenario-c-wazuh.sh` | `11`, `12`, `13`, `14` |
| D - MITRE ICS Correlation | `36-run-scenario-d-correlation.sh` | `15`, `16`, `17`, `18`, `19`, `20`, `21`, `22` |
| E - Operational Noise/FPR | `37-run-scenario-e-noise-fpr.sh` | `23`, `24`, `25`, `26` |
| A-E completo | `38-run-all-scenarios-ae.sh` | `33`, `34`, `35`, `36`, `37`, `27`, `28`, `32`, `31` |

## Uso recomendado | Recommended usage

Para reconstruir todo el laboratorio y generar evidencia completa: | To rebuild the full laboratory and generate complete evidence:

```bash
./scripts/run/38-run-all-scenarios-ae.sh
```

Para ejecutar solo campañas cuantitativas finales: | To run only the final quantitative campaigns:

```bash
./scripts/run/29-run-paper-final-campaign.sh
```

Para ejecutar un escenario específico: | To run a specific scenario:

```bash
./scripts/run/33-run-scenario-a-foundation.sh
./scripts/run/34-run-scenario-b-zabbix.sh
./scripts/run/35-run-scenario-c-wazuh.sh
./scripts/run/36-run-scenario-d-correlation.sh
./scripts/run/37-run-scenario-e-noise-fpr.sh
```

## Control de reset | Reset control

Por seguridad, el escenario A no ejecuta `00-reset-lab.sh` salvo que se active explícitamente: | For safety, scenario A does not run `00-reset-lab.sh` unless explicitly enabled:

```bash
RESET_BEFORE_SCENARIO_A="true"
```

Este valor se define en `config/experiment.conf`. | This value is defined in `config/experiment.conf`.

## Regla metodológica | Methodological rule

Los wrappers facilitan ejecución por terceros, pero los scripts `00–28` permanecen como evidencia auditable de cada paso técnico. | Wrappers simplify third-party execution, but scripts `00–28` remain auditable evidence for each technical step.
