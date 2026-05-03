# Incremental Update V3 Manifest | Manifiesto de actualización incremental V3

## Objetivo | Objective

Alinear README, configuración experimental y documentación de ejecución rápida sin romper la estructura existente. | Align README, experimental configuration, and quick execution documentation without breaking the existing structure.

## Archivos modificados o agregados | Modified or added files

| Archivo | Acción |
|---|---|
| `README.md` | Reemplazo por versión operativa y breve. |
| `README.en.md` | Reemplazo por versión operativa y breve en inglés. |
| `CHANGELOG.md` | Actualización incremental V3. |
| `config/experiment.conf` | Parámetros paper-final documentados variable por variable. |
| `scripts/lib/experiment-config.sh` | Librería común de configuración y logging bilingüe. |
| `scripts/run/29-run-paper-final-campaign.sh` | Orquestador paper-final. |
| `scripts/run/30-validate-paper-readiness.sh` | Validador paper-readiness. |
| `scripts/run/31-show-paper-results.sh` | Visualizador de resultados. |
| `scripts/run/32-verify-final-freeze.sh` | Verificador SHA256 del freeze. |
| `docs/17-configuration-and-execution.md` | Guía de configuración y ejecución rápida. |
| `docs/18-non-programmer-workflow.md` | Flujo para revisor no programador. |
| `docs/19-script-message-standard.md` | Estándar bilingüe de mensajes. |
| `docs/20-paper-final-reproducibility.md` | Reproducibilidad final del artículo. |
| `docs/README_SCOPE.md` | Alcance recomendado del README. |

## Compatibilidad | Compatibility

La actualización no elimina scripts `00–28`, no borra resultados, no modifica freezes históricos y no cambia la estructura base del laboratorio. | The update does not remove scripts `00–28`, delete results, modify historical freezes, or change the base laboratory structure.
