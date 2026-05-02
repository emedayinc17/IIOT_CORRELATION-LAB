# 10 — Reproducibility

## Secuencia reproducible hasta Escenario B

```bash
./scripts/run/00-reset-lab.sh
./scripts/run/01-deploy-foundation.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
./scripts/run/04-deploy-zabbix.sh
./scripts/run/05-validate-zabbix.sh
./scripts/run/06-configure-zabbix-monitoring.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
```

## Corrida oficial recomendada

```bash
ITERATIONS=900 SLEEP_SECONDS=2 DURATION_SECONDS=1800 ./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
```


## Continuación reproducible — Escenario C

```bash
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
ITERATIONS=3 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

## Corrida oficial recomendada — Escenario C

```bash
ITERATIONS=900 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

## Variables controladas

| Variable | Default | Descripción |
|---|---:|---|
| `WAZUH_VERSION` | `v4.14.5` | rama del repositorio oficial Wazuh Kubernetes |
| `WAZUH_NS` | `security` | namespace del Escenario C |
| `WAZUH_DASHBOARD_IP` | `10.10.0.161` | IP MetalLB dashboard |
| `WAZUH_MANAGER_IP` | `10.10.0.162` | IP MetalLB manager |
| `WAZUH_STORAGE_CLASS` / `STORAGE_CLASS` | `microk8s-hostpath` | StorageClass base del clúster usada para adaptar `wazuh-storage` |
| `ITERATIONS` | `3` validación / `900` oficial | número de iteraciones de baseline |
| `SLEEP_SECONDS` | `2` | intervalo entre eventos |

## Principio de no destructividad

El Escenario C agrega archivos numerados y carpetas ya previstas por el laboratorio. No renombra `kubernetes/zabbix`, no cambia los escenarios A/B y no reemplaza collectors existentes.

## Reproducibilidad Escenario C v6

Para evitar variabilidad externa durante la defensa del paper, la reconciliación v6 no ejecuta `git clone` en tiempo de ejecución cuando Wazuh ya existe en el cluster. El script `11-deploy-wazuh-security.sh` opera como reconciliador correctivo: valida el cluster real, corrige permisos de reglas, valida servicios, y exporta un snapshot de manifiestos en `kubernetes/security/wazuh-frozen/`.

El snapshot congelado permite documentar qué recursos fueron aplicados y conservar evidencia local de la configuración resultante. El objetivo es reforzar reproducibilidad y trazabilidad, no introducir un nuevo stack ni ampliar el alcance hacia seguridad Kubernetes.

<!-- SCENARIO_D_INCREMENTAL_V1 -->
## Reproducibilidad del Escenario D

El Escenario D es reproducible porque:

- no instala herramientas adicionales;
- reutiliza Foundation IIoT, Zabbix y Wazuh ya congelados;
- usa endpoints fijos del laboratorio;
- usa timestamps UTC;
- genera datasets CSV estructurados;
- congela resultados, evidencia y checksums en `baseline/scenario_d_correlation_<timestamp>`.

### Orden de ejecución

```text
15-run-mitre-ics-attacks.sh
16-run-correlation-experiment.sh
17-export-final-datasets.sh
18-freeze-correlation-results.sh
```

Cada script termina con un bloque `[SUMMARY]` y checklist `[OK]`.
