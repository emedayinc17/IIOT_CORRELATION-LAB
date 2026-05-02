# IIoT Correlation Lab

Laboratorio reproducible para evaluar correlación entre monitoreo operacional y eventos de seguridad en entornos IIoT aplicados a Minería 4.0.

# Documentación

La documentación técnica y metodológica del proyecto se encuentra en:

| Documento | Descripción |
|---|---|
| `docs/00-overview.md` | visión general del laboratorio |
| `docs/01-architecture.md` | arquitectura y componentes |
| `docs/02-environment.md` | entorno y prerequisitos |
| `docs/03-foundation-iiot.md` | despliegue Foundation IIoT |
| `docs/04-operational-baseline.md` | baseline operacional |
| `docs/05-zabbix-monitoring.md` | monitoreo operacional con Zabbix |
| `docs/06-wazuh-security.md` | instrumentación de seguridad |
| `docs/07-correlation.md` | correlación operacional y seguridad |
| `docs/08-experiments.md` | escenarios experimentales |
| `docs/09-results.md` | resultados y evidencias |
| `docs/10-reproducibility.md` | reproducibilidad del laboratorio |
| `docs/11-experimental-design.md` | justificación científica de parámetros experimentales |
| `docs/12-version-matrix.md` | matriz de versiones del laboratorio |
| `docs/13-reviewer-traceability.md` | trazabilidad entre observaciones y evidencias |

# Ejecución

Los scripts ejecutables se encuentran en:

```text
scripts/run/
```

La secuencia debe ejecutarse en orden numérico.

## Secuencia reproducible hasta Escenario C

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
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
ITERATIONS=3 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

## Corrida oficial recomendada para Escenario B

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

Para una corrida oficial de baseline de seguridad, usar el mismo patrón temporal del laboratorio:

```bash
ITERATIONS=900 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

El detalle metodológico de Wazuh se documenta en `docs/06-wazuh-security.md`; la correlación posterior se reserva para `docs/07-correlation.md` y Escenario D.

# Resultados

```text
results/
├── raw/
├── processed/
├── figures/
└── tables/
```

# Evidencias

```text
baseline/
evidence/
├── inventory/
├── zabbix/
└── wazuh/
```

<!-- SCENARIO_D_INCREMENTAL_V1 -->

## Escenario D — ataques MITRE ICS y correlación

Después de congelar los escenarios A, B y C, el flujo experimental final se ejecuta con:

```bash
ITERATIONS=5 SLEEP_SECONDS=2 ./scripts/run/15-run-mitre-ics-attacks.sh
CORRELATION_WINDOW_SECONDS=120 ./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
```

Este escenario no instala infraestructura adicional. Reutiliza Foundation IIoT, Zabbix y Wazuh para generar datasets correlacionados y evidencia reproducible.
