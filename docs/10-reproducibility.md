# 10 — Reproducibilidad

## Principio

Cada escenario debe poder reproducirse con:

```text
scripts + metadata + datasets raw + evidencia + freeze + SHA256SUMS
```

## Secuencia general

```bash
./scripts/run/00-reset-lab.sh
./scripts/run/01-deploy-foundation.sh
./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
./scripts/run/04-deploy-zabbix.sh
./scripts/run/05-validate-zabbix.sh
./scripts/run/06-configure-zabbix-monitoring.sh
./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
./scripts/run/15-run-mitre-ics-attacks.sh
./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
./scripts/run/19-normalize-experimental-datasets.sh
./scripts/run/20-generate-experimental-metadata.sh
./scripts/run/21-analyze-temporal-correlation.sh
./scripts/run/22-run-statistical-analysis.sh
./scripts/run/23-run-operational-noise-control.sh
./scripts/run/24-analyze-false-positive-rate.sh
./scripts/run/25-freeze-noise-control-results.sh
```

## Limpieza segura para repetir Escenario E

Borrar solo artefactos derivados de E:

```bash
rm -rf results/raw/scenario_e
rm -rf results/processed/scenario_e
rm -f results/tables/table_noise_fpr_summary.csv
rm -f results/tables/table_noise_wilson_ci.csv
rm -f results/tables/table_noise_profile_summary.csv
rm -f results/tables/table_noise_zabbix_quality.csv
rm -f results/figures/figure_noise_fpr_by_profile.svg
rm -rf evidence/wazuh/scenario_e
```

No borrar:

```text
results/raw/scenario_d
results/processed/correlation_dataset.csv
baseline/
evidence/
```

## Freeze

Los freezes deben incluir:

- datasets raw;
- datasets processed;
- tablas;
- figuras;
- scripts usados;
- snapshots Kubernetes;
- metadata;
- `SHA256SUMS`.

## Archivos temporales/históricos

Los documentos de implementación incremental pueden conservarse si se desea trazabilidad histórica, pero la documentación formal debe estar consolidada en los capítulos principales.


## Configuración centralizada paper-final

Los valores operativos de la campaña final se concentran en:

```text
config/experiment.conf
```

Este archivo evita repetir variables manualmente en los scripts y permite que un tercero verifique los parámetros usados para las corridas D y E.

## Capa de orquestación 29–32

Los scripts `29` a `32` no reemplazan los scripts existentes. Funcionan como capa de ejecución, validación y visualización:

```bash
./scripts/run/29-run-paper-final-campaign.sh
./scripts/run/30-validate-paper-readiness.sh
./scripts/run/31-show-paper-results.sh
./scripts/run/32-verify-final-freeze.sh
```

## Ejecución recomendada para revisor no programador

```bash
./scripts/run/30-validate-paper-readiness.sh
./scripts/run/31-show-paper-results.sh
```

Si se desea repetir la campaña cuantitativa completa:

```bash
./scripts/run/29-run-paper-final-campaign.sh
```

## Regla de coherencia

Los valores reportados en el artículo deben coincidir con `config/experiment.conf`, `results/processed/experimental_metadata_final.json` o los metadatos congelados dentro del último `final_methodology_package_*`.
