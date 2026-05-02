# IIoT Correlation Lab — Zabbix + Wazuh para Minería 4.0

Laboratorio reproducible para evaluar la correlación entre monitoreo operacional y eventos de seguridad en un entorno IIoT simulado, orientado a escenarios de Minería 4.0 e infraestructuras industriales críticas.

Este repositorio implementa una cadena experimental completa basada en:

```text
Foundation IIoT → Zabbix Monitoring → Wazuh Security → MITRE ICS Correlation
```

El objetivo no es evaluar Kubernetes, alta disponibilidad, hardening ni rendimiento enterprise de SIEM. Kubernetes/MicroK8s se utiliza únicamente como plataforma reproducible para ejecutar el laboratorio.

---

## 1. Objetivo del proyecto

El laboratorio busca demostrar, bajo condiciones controladas y reproducibles, que una arquitectura integrada de monitoreo operacional y monitoreo de seguridad puede correlacionar:

- métricas operacionales de servicios IIoT obtenidas desde Zabbix;
- eventos de seguridad registrados por Wazuh;
- ataques controlados mapeados a MITRE ATT&CK for ICS;
- ventanas temporales comunes para análisis experimental.

La evidencia generada sirve como soporte para un paper académico sobre IIoT, Minería 4.0, monitoreo operacional, detección de eventos de seguridad y correlación experimental.

---

## 2. Alcance metodológico

El laboratorio está diseñado para ser simple, controlado y reproducible. Por decisión metodológica, no implementa arquitectura enterprise ni componentes que no aporten directamente a la hipótesis experimental.

| Incluido | Excluido |
|---|---|
| MicroK8s single-node | Clúster Kubernetes HA |
| Foundation IIoT simulada | Sistemas industriales reales en producción |
| Zabbix persistente | Prometheus/Grafana como capa adicional |
| Wazuh single-node/all-in-one | Wazuh HA/distribuido |
| MITRE ATT&CK for ICS controlado | Ataques no controlados |
| Datasets, tablas, figuras y freeze | Evaluación de hardening Kubernetes |

La filosofía es:

```text
Si no fortalece reproducibilidad, correlación o evidencia experimental, no se implementa.
```

---

## 3. Entorno base esperado

El laboratorio fue construido y validado sobre el siguiente entorno:

| Elemento | Valor esperado |
|---|---|
| Kubernetes | MicroK8s |
| Versión Kubernetes | v1.30.x |
| Nodo | single-node |
| Sistema operativo | Ubuntu 24.04 |
| Runtime | containerd |
| CNI | Calico |
| Ingress | NGINX Ingress |
| LoadBalancer | MetalLB |
| StorageClass | microk8s-hostpath |

Los scripts validan prerequisitos antes de avanzar y exportan evidencia en `evidence/` y `baseline/`.

---

## 4. Arquitectura experimental

| Capa | Componentes | Rol experimental |
|---|---|---|
| Foundation IIoT | Mosquitto, health-app, telemetry-api, vulnerable-app, sensor-simulator | Servicios objetivo e instrumentación base |
| Monitoreo operacional | Zabbix Server, PostgreSQL, Zabbix Web, Zabbix Agent | Métricas de disponibilidad y latencia con `history.get` real |
| Seguridad | Wazuh Manager, Indexer, Dashboard | Eventos de seguridad y reglas MITRE ICS |
| Correlación | Scripts `15–18` | Ataques, extracción, correlación, tablas, figuras y freeze |

IPs MetalLB usadas por defecto:

| Servicio | IP |
|---|---:|
| MQTT / Mosquitto | `10.10.0.151` |
| health-app | `10.10.0.152` |
| telemetry-api | `10.10.0.153` |
| vulnerable-app | `10.10.0.154` |
| Zabbix Web/API | `10.10.0.160` |
| Wazuh Dashboard | `10.10.0.161` |
| Wazuh Manager/API | `10.10.0.162` |

---

## 5. Escenarios experimentales

| Escenario | Propósito | Resultado principal |
|---|---|---|
| A — Foundation IIoT | Desplegar servicios IIoT y capturar baseline sin monitoreo externo | `baseline/scenario_A_*` |
| B — Zabbix Monitoring | Configurar monitoreo operacional y baseline con Zabbix | `baseline/scenario_B_*` |
| C — Wazuh Security | Desplegar Wazuh y registrar eventos de seguridad base | `baseline/scenario_c_wazuh_security/` |
| D — MITRE ICS Correlation | Ejecutar ataques controlados y correlacionar Zabbix/Wazuh | `baseline/scenario_d_correlation_*` |

Técnicas MITRE ATT&CK for ICS usadas en D:

| Técnica | ID | Componente objetivo |
|---|---|---|
| Unauthorized Command Message | T0809 | `mosquitto` |
| Data Manipulation | T0814 | `telemetry-api` |
| Denial of Service | T0860 | `vulnerable-app` |

---

## 6. Estructura del repositorio

```text
README.md
README.en.md

docs/
  00-overview.md
  01-architecture.md
  02-environment.md
  03-foundation-iiot.md
  04-operational-baseline.md
  05-zabbix-monitoring.md
  06-wazuh-security.md
  07-correlation.md
  08-experiments.md
  09-results.md
  10-reproducibility.md
  11-experimental-design.md
  12-version-matrix.md
  13-reviewer-traceability.md

scripts/
  run/
  collectors/
  lib/

kubernetes/
  foundation/
  zabbix/
  security/
  experiments/

results/
  raw/
  processed/
  figures/
  tables/

baseline/
evidence/
  inventory/
  zabbix/
  wazuh/
```

---

## 7. Documentación técnica y metodológica

| Documento | Descripción |
|---|---|
| `docs/00-overview.md` | Visión general del laboratorio |
| `docs/01-architecture.md` | Arquitectura y componentes |
| `docs/02-environment.md` | Entorno y prerequisitos |
| `docs/03-foundation-iiot.md` | Foundation IIoT |
| `docs/04-operational-baseline.md` | Baseline operacional |
| `docs/05-zabbix-monitoring.md` | Zabbix y métricas reales |
| `docs/06-wazuh-security.md` | Wazuh, reglas, Dashboard/API |
| `docs/07-correlation.md` | Modelo de correlación |
| `docs/08-experiments.md` | Escenarios y parámetros |
| `docs/09-results.md` | Resultados, datasets y evidencias |
| `docs/10-reproducibility.md` | Flujo reproducible y freeze |
| `docs/11-experimental-design.md` | Justificación científica |
| `docs/12-version-matrix.md` | Matriz de versiones |
| `docs/13-reviewer-traceability.md` | Trazabilidad frente a revisores |

---

## 8. Flujo reproducible completo

Ejecutar desde la raíz del repositorio:

```bash
cd ~/iiot-correlation-lab
chmod +x scripts/run/*.sh scripts/collectors/*.sh
```

### 8.1 Escenario A — Foundation IIoT

```bash
./scripts/run/00-reset-lab.sh
./scripts/run/01-deploy-foundation.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
```

Uso: validación inicial de servicios IIoT y baseline sin monitoreo adicional.

### 8.2 Escenario B — Zabbix Monitoring

```bash
./scripts/run/04-deploy-zabbix.sh
./scripts/run/05-validate-zabbix.sh
ZABBIX_ITEM_DELAY=5s ./scripts/run/06-configure-zabbix-monitoring.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
```

Uso: instrumentación operacional. El script `06` valida que Zabbix genere `history.get` real para los ítems IIoT.

### 8.3 Escenario C — Wazuh Security

```bash
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
ITERATIONS=3 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

Uso: despliegue/reconciliación de Wazuh single-node/all-in-one, reglas IIoT/MITRE ICS, Dashboard/API y baseline de seguridad.

### 8.4 Escenario D — MITRE ICS + Correlación

Corrida rápida de validación:

```bash
ITERATIONS=5 SLEEP_SECONDS=2 ./scripts/run/15-run-mitre-ics-attacks.sh
CORRELATION_WINDOW_SECONDS=120 ./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
```

Campaña final recomendada para paper:

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

Notas:

- `ITERATIONS=20` incrementa robustez estadística frente a la corrida rápida.
- `ZABBIX_ITEM_DELAY=5s` mejora la cercanía temporal entre ataque y muestra operacional.
- `BASELINE_WARMUP_SECONDS=60` permite capturar muestras previas reales.
- `DOS_REQUESTS`, `DOS_CONCURRENCY` y `ATTACK_DURATION_SECONDS` aumentan la probabilidad de observar degradación operacional.
- `ZABBIX_HISTORY_LOOKBACK_SECONDS=120` y `ZABBIX_HISTORY_FORWARD_SECONDS=120` evitan correlaciones diluidas por ventanas excesivas.

---

## 9. Validation run vs campaña final

| Tipo de corrida | Propósito | Parámetros típicos |
|---|---|---|
| Validación técnica | Verificar que infraestructura, collectors y datasets funcionen | `ITERATIONS=3–5`, ataques cortos |
| Campaña final paper | Generar evidencia experimental defendible | `ITERATIONS=20+`, Zabbix 5s, DoS calibrado, ventanas 120s |

La validación técnica no debe sobreinterpretarse como resultado final. La campaña final es la que debe usarse para discutir detección, correlación e impacto operacional.

---

## 10. Resultados generados

```text
results/raw/          datasets brutos por escenario
results/processed/    datasets correlacionados y procesados
results/tables/       tablas listas para análisis/paper
results/figures/      figuras SVG reproducibles
baseline/             freezes reproducibles por escenario
evidence/             inventarios, logs, configuraciones y evidencias
```

Archivos clave del Escenario D:

```text
results/raw/scenario_d/mitre_ics_attacks.csv
results/raw/scenario_d/wazuh_security_events.csv
results/raw/scenario_d/zabbix_correlation_metrics.csv
results/raw/scenario_d/zabbix_history_validation.csv
results/processed/correlation_dataset.csv
results/processed/attack_effectiveness.csv
results/tables/table_attack_detection.csv
results/tables/table_correlation_latency.csv
results/tables/table_sla_impact.csv
results/tables/table_zabbix_history_quality.csv
```

---

## 11. Reproducibilidad y freeze

Cada escenario genera evidencia congelada. Los freezes incluyen datasets, snapshots Kubernetes, manifiestos relevantes y `SHA256SUMS` cuando aplica.

```text
baseline/scenario_A_*
baseline/scenario_B_*
baseline/scenario_c_wazuh_security/
baseline/scenario_d_correlation_*
```

El propósito del freeze es permitir que un evaluador revise exactamente qué se ejecutó y qué evidencia fue generada.

---

## 12. Mensajes operativos bilingües

Los scripts muestran mensajes guía en español e inglés, incluyendo:

- objetivo del script;
- ETA aproximado;
- fase actual;
- notas para el operador;
- resumen final `[SUMMARY]`.

Esto facilita ejecución local, revisión internacional y sustentación técnica.

---

## 13. Limitaciones declaradas

Este laboratorio no representa una planta minera real en producción. Es un entorno IIoT controlado, reproducible y de alcance académico. Las conclusiones deben limitarse a la validez experimental del laboratorio, no a generalizaciones absolutas sobre entornos industriales reales.

Limitaciones principales:

- escala reducida;
- servicios IIoT simulados;
- Wazuh single-node;
- MicroK8s single-node;
- ataques controlados;
- dependencia de parámetros de intensidad y ventanas temporales.

Estas limitaciones son explícitas para evitar sobredeclaraciones y fortalecer la transparencia metodológica.

---

## 14. Estado esperado antes de usar resultados en el paper

Antes de redactar resultados finales, verificar:

```bash
cat results/tables/table_attack_detection.csv
cat results/tables/table_correlation_latency.csv
cat results/tables/table_sla_impact.csv
cat results/tables/table_zabbix_history_quality.csv
column -s, -t < results/processed/correlation_dataset.csv | head -30
```

Criterios mínimos:

- Wazuh detecta eventos por técnica MITRE ICS;
- Zabbix contiene muestras reales `history.get`;
- `avg_nearest_zabbix_sample_delta_s` está dentro de una ventana defendible;
- no se reporta degradación operacional si los datos no la muestran;
- las limitaciones se declaran explícitamente.

