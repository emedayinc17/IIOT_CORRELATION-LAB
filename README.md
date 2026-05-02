# IIoT Correlation Lab

Laboratorio reproducible para evaluar correlación entre monitoreo operacional y eventos de seguridad en entornos IIoT aplicados a Minería 4.0.

El proyecto implementa un entorno controlado sobre MicroK8s para observar cómo se relacionan métricas operacionales capturadas con Zabbix y eventos de seguridad registrados por Wazuh ante técnicas MITRE ATT&CK for ICS.

## Objetivo

Evaluar si la integración de monitoreo operacional y seguridad permite generar evidencia correlacionada, reproducible y trazable ante eventos IIoT representativos.

El foco del laboratorio es:

```text
IIoT + Zabbix + Wazuh + correlación
```

No se evalúa alta disponibilidad, resiliencia enterprise, hardening Kubernetes, service mesh ni seguridad del clúster Kubernetes. Kubernetes se usa únicamente como medio reproducible de laboratorio.

## Arquitectura resumida

| Capa | Componentes | Propósito |
|---|---|---|
| Foundation IIoT | Mosquitto, sensor-simulator, health-app, telemetry-api, vulnerable-app | Simular servicios IIoT y telemetría |
| Monitoreo operacional | Zabbix Server, Zabbix Web, PostgreSQL, Zabbix Agent | Medir disponibilidad, latencia e histórico operacional |
| Seguridad | Wazuh Manager, Wazuh Indexer, Wazuh Dashboard | Registrar eventos de seguridad y reglas MITRE ICS |
| Correlación | Scripts 15–18, datasets CSV/SVG, freezes | Relacionar eventos Wazuh con métricas Zabbix |

## Entorno esperado

| Elemento | Valor |
|---|---|
| Kubernetes | MicroK8s |
| Nodo | single-node |
| OS | Ubuntu 24.04 |
| Runtime | containerd |
| CNI | Calico |
| Ingress | NGINX Ingress |
| LoadBalancer | MetalLB |
| StorageClass | microk8s-hostpath |

## Estructura principal

```text
README.md
README.en.md
docs/
scripts/
kubernetes/
results/
baseline/
evidence/
```

## Documentación

| Documento | Descripción |
|---|---|
| `docs/00-overview.md` | visión general del laboratorio |
| `docs/01-architecture.md` | arquitectura y componentes |
| `docs/02-environment.md` | entorno y prerequisitos |
| `docs/03-foundation-iiot.md` | despliegue Foundation IIoT |
| `docs/04-operational-baseline.md` | baseline operacional |
| `docs/05-zabbix-monitoring.md` | monitoreo operacional con Zabbix |
| `docs/06-wazuh-security.md` | instrumentación de seguridad con Wazuh |
| `docs/07-correlation.md` | correlación operacional y seguridad |
| `docs/08-experiments.md` | escenarios experimentales |
| `docs/09-results.md` | resultados, datasets y evidencias |
| `docs/10-reproducibility.md` | reproducibilidad del laboratorio |
| `docs/11-experimental-design.md` | justificación científica de parámetros experimentales |
| `docs/12-version-matrix.md` | matriz de versiones del laboratorio |
| `docs/13-reviewer-traceability.md` | trazabilidad entre observaciones y evidencias |

## Escenarios experimentales

| Escenario | Descripción | Resultado esperado |
|---|---|---|
| A | Foundation IIoT | baseline operacional sin monitoreo externo |
| B | Foundation IIoT + Zabbix | métricas operacionales reales e histórico Zabbix |
| C | Foundation IIoT + Zabbix + Wazuh | baseline de seguridad y eventos Wazuh |
| D | Ataques MITRE ICS + correlación | datasets correlacionados Zabbix/Wazuh |

## Secuencia reproducible completa

Los scripts se ejecutan en orden numérico desde `scripts/run/`.

### Escenario A — Foundation IIoT

```bash
./scripts/run/00-reset-lab.sh
./scripts/run/01-deploy-foundation.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
```

### Escenario B — Zabbix Monitoring

```bash
./scripts/run/04-deploy-zabbix.sh
./scripts/run/05-validate-zabbix.sh
ZABBIX_ITEM_DELAY=5s ./scripts/run/06-configure-zabbix-monitoring.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
```

Para una corrida operacional más amplia:

```bash
ITERATIONS=900 SLEEP_SECONDS=2 DURATION_SECONDS=1800 ./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
```

### Escenario C — Wazuh Security Baseline

```bash
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
ITERATIONS=3 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

### Escenario D — MITRE ATT&CK for ICS + correlación

La corrida final recomendada para paper utiliza 20 iteraciones, polling Zabbix calibrado y ventanas temporales acotadas:

```bash
ITERATIONS=20 \
SLEEP_SECONDS=5 \
BASELINE_WARMUP_SECONDS=60 \
INTER_ATTACK_COOLDOWN_SECONDS=10 \
DOS_REQUESTS=500 \
DOS_CONCURRENCY=30 \
ATTACK_DURATION_SECONDS=30 \
HTTP_PROBE_INTERVAL_SECONDS=2 \
./scripts/run/15-run-mitre-ics-attacks.sh

CORRELATION_WINDOW_SECONDS=120 \
ZABBIX_HISTORY_LOOKBACK_SECONDS=120 \
ZABBIX_HISTORY_FORWARD_SECONDS=120 \
./scripts/run/16-run-correlation-experiment.sh

./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
```

## Parámetros principales del Escenario D

| Parámetro | Valor recomendado | Justificación |
|---|---:|---|
| `ITERATIONS` | 20 | repeticiones suficientes para corrida paper-final controlada |
| `BASELINE_WARMUP_SECONDS` | 60 | permite alinear polling Zabbix antes de ataques |
| `INTER_ATTACK_COOLDOWN_SECONDS` | 10 | reduce solapamiento entre iteraciones |
| `DOS_REQUESTS` | 500 | intensidad controlada para T0860 |
| `DOS_CONCURRENCY` | 30 | concurrencia suficiente sin destruir el laboratorio |
| `ATTACK_DURATION_SECONDS` | 30 | ventana observable para Zabbix/Wazuh |
| `CORRELATION_WINDOW_SECONDS` | 120 | ventana fuerte de correlación temporal |
| `ZABBIX_HISTORY_LOOKBACK_SECONDS` | 120 | histórico operacional cercano al ataque |
| `ZABBIX_HISTORY_FORWARD_SECONDS` | 120 | recuperación/efecto posterior cercano al ataque |

## Resultados

```text
results/
├── raw/
├── processed/
├── figures/
└── tables/
```

Archivos principales esperados:

| Ruta | Descripción |
|---|---|
| `results/raw/scenario_d/mitre_ics_attacks.csv` | eventos de ataque ejecutados |
| `results/raw/scenario_d/wazuh_security_events.csv` | eventos Wazuh exportados |
| `results/raw/scenario_d/zabbix_correlation_metrics.csv` | métricas Zabbix reales vía `history.get` |
| `results/processed/correlation_dataset.csv` | dataset correlacionado final |
| `results/tables/table_attack_detection.csv` | detección por técnica |
| `results/tables/table_correlation_latency.csv` | distancia temporal y latencia |
| `results/tables/table_sla_impact.csv` | impacto operacional |
| `results/tables/table_zabbix_history_quality.csv` | calidad del histórico Zabbix |
| `results/figures/*.svg` | figuras para análisis y paper |

## Evidencias y freezes

```text
baseline/
evidence/
├── inventory/
├── zabbix/
└── wazuh/
```

Cada freeze incluye datasets, snapshots Kubernetes y `SHA256SUMS` para trazabilidad.

## Interpretación metodológica

El objetivo principal del Escenario D no es maximizar degradación destructiva del entorno IIoT, sino evaluar:

- detección de amenazas,
- correlación temporal operacional-seguridad,
- observabilidad reproducible,
- integración entre métricas Zabbix y eventos Wazuh.

Los ataques fueron ejecutados bajo un modelo controlado y reproducible orientado a evaluar correlación temporal y capacidad de observabilidad, no a maximizar degradación operacional destructiva ni resiliencia industrial extrema.

Por ello, técnicas como T0809 y T0814 pueden comprometer integridad lógica o generar eventos de seguridad sin producir degradación operacional severa observable en SLA o disponibilidad. En cambio, T0860 está orientado explícitamente a disponibilidad y puede producir errores HTTP observables.

## Estado final esperado

Al completar los scripts `00` a `18`, el laboratorio debe contar con:

```text
[OK] Foundation IIoT desplegado y congelado
[OK] Zabbix con histórico operacional real
[OK] Wazuh con eventos MITRE ICS y dashboard/API funcionales
[OK] Campaña D ejecutada con 20 iteraciones
[OK] Datasets raw/processed/tables/figures generados
[OK] Freeze final reproducible con SHA256SUMS
```
