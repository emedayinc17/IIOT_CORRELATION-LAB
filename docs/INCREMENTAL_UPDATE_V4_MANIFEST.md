# Incremental Update V4 Manifest | Manifiesto de actualización incremental V4

## Objetivo | Objective

Agregar wrappers de ejecución por escenario para que el laboratorio pueda ejecutarse con pocos comandos, sin eliminar los scripts técnicos existentes. | Add scenario execution wrappers so the laboratory can be executed with a few commands, without removing existing technical scripts.

## Archivos agregados o actualizados | Added or updated files

| Archivo | Acción |
|---|---|
| `scripts/run/33-run-scenario-a-foundation.sh` | Nuevo wrapper escenario A. |
| `scripts/run/34-run-scenario-b-zabbix.sh` | Nuevo wrapper escenario B. |
| `scripts/run/35-run-scenario-c-wazuh.sh` | Nuevo wrapper escenario C. |
| `scripts/run/36-run-scenario-d-correlation.sh` | Nuevo wrapper escenario D. |
| `scripts/run/37-run-scenario-e-noise-fpr.sh` | Nuevo wrapper escenario E. |
| `scripts/run/38-run-all-scenarios-ae.sh` | Nuevo wrapper completo A-E. |
| `scripts/run/29-run-paper-final-campaign.sh` | Ajustado para ejecutar D-E usando wrappers. |
| `README.md` | Ajustado para priorizar ejecución por escenario. |
| `README.en.md` | Ajustado para priorizar ejecución por escenario. |
| `config/experiment.conf` | Agrega controles de wrappers y mantiene parámetros paper-final. |
| `docs/21-scenario-wrapper-execution.md` | Nuevo documento de wrappers. |
| `docs/17-configuration-and-execution.md` | Actualizado con wrappers. |
| `docs/18-non-programmer-workflow.md` | Actualizado con ejecución A-E y D-E. |

## Compatibilidad | Compatibility

No se eliminan scripts `00–28`; los wrappers solo agrupan su ejecución. | Scripts `00–28` are not removed; wrappers only group their execution.
