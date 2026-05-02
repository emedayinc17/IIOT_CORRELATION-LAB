# 08 — Experiments

## Escenarios incrementales

| Escenario | Descripción | Objetivo |
|---|---|---|
| A | Foundation IIoT | baseline operacional sin monitoreo |
| B | Foundation IIoT + Zabbix | impacto del monitoreo operacional |
| C | Foundation IIoT + Zabbix + Wazuh | observabilidad operacional + seguridad |
| D | Correlación + ataques MITRE ICS | evaluación de detección correlacionada |

## Workflow reproducible

```text
Prepare Kubernetes baseline
        ↓
Deploy Foundation IIoT
        ↓
Validate MQTT / HTTP / DNS
        ↓
Run Scenario A baseline
        ↓
Freeze Scenario A
        ↓
Deploy persistent Zabbix
        ↓
Configure Zabbix hosts/items/triggers
        ↓
Run Scenario B baseline
        ↓
Freeze Scenario B
        ↓
Export inventory and Zabbix configuration
        ↓
Deploy Wazuh
        ↓
Integrate IIoT logs/events
        ↓
Run Scenario C security baseline
        ↓
Execute MITRE ATT&CK for ICS scenarios
        ↓
Collect Zabbix metrics and Wazuh alerts
        ↓
Correlate timestamps
        ↓
Export final datasets and figures
```

## Corridas

| Tipo | Duración | Uso |
|---|---:|---|
| Validation run | 20 s a 10 min | validación técnica |
| Official run | 30 min | análisis comparativo |
| Endurance run | 6 h | estabilidad operacional |


## Escenario C — Foundation IIoT + Zabbix + Wazuh

El Escenario C agrega Wazuh como capa de seguridad sobre el baseline operacional con Zabbix. La corrida no introduce ataques; genera eventos estructurados de baseline para comprobar ingesta, trazabilidad y congelamiento reproducible.

### Secuencia

```bash
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
ITERATIONS=3 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

### Corrida oficial

```bash
ITERATIONS=900 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

### Criterio de éxito

| Criterio | Evidencia |
|---|---|
| Wazuh operativo | `scripts/run/12-validate-wazuh-security.sh` |
| Dashboard accesible | `https://10.10.0.161` y headers exportados |
| Manager operativo | rollout y logs en `evidence/wazuh/` |
| Eventos estructurados | `results/raw/scenario_c/wazuh_security_baseline.csv` |
| Reglas IIoT/MITRE ICS preparadas | `wazuh-iiot-rules.yaml` y validación en manager |
| Freeze reproducible | `baseline/scenario_c_wazuh_security/` |

<!-- SCENARIO_D_INCREMENTAL_V1 -->
## Escenario D — ejecución experimental

El Escenario D se ejecuta después de congelar A, B y C. No instala componentes nuevos. Solo orquesta estímulos controlados sobre la Foundation IIoT y captura evidencia desde Zabbix y Wazuh.

### Secuencia reproducible

```bash
ITERATIONS=5 SLEEP_SECONDS=2 ./scripts/run/15-run-mitre-ics-attacks.sh
CORRELATION_WINDOW_SECONDS=120 ./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
```

### Parámetros controlables

| Variable | Valor por defecto | Uso |
|---|---:|---|
| `ITERATIONS` | 5 | repeticiones por técnica |
| `SLEEP_SECONDS` | 2 | separación entre estímulos |
| `DOS_REQUESTS` | 40 | solicitudes controladas para T0860 |
| `DOS_CONCURRENCY` | 8 | concurrencia controlada para T0860 |
| `CORRELATION_WINDOW_SECONDS` | 120 | ventana temporal de correlación |

### Restricción de alcance

D no evalúa seguridad de Kubernetes ni resiliencia SIEM enterprise. Evalúa la correlación entre señales operacionales IIoT y eventos de seguridad Wazuh bajo ataques MITRE ICS reproducibles.


## Calibración paper-final Escenario D

La corrida final del Escenario D debe diferenciarse de las pruebas funcionales rápidas. Para sustentar correlación operacional + seguridad, se usa polling Zabbix calibrado mediante `ZABBIX_ITEM_DELAY=5s`, ataques con duración controlada (`ATTACK_DURATION_SECONDS`), mayor intensidad (`DOS_REQUESTS`, `DOS_CONCURRENCY`) y ventanas de correlación acotadas (`ZABBIX_HISTORY_LOOKBACK_SECONDS=120`, `ZABBIX_HISTORY_FORWARD_SECONDS=120`).

Parámetros recomendados para ejecución final reproducible:

```bash
ZABBIX_ITEM_DELAY=5s ./scripts/run/06-configure-zabbix-monitoring.sh
ITERATIONS=20 SLEEP_SECONDS=5 BASELINE_WARMUP_SECONDS=60 INTER_ATTACK_COOLDOWN_SECONDS=10 DOS_REQUESTS=500 DOS_CONCURRENCY=30 ATTACK_DURATION_SECONDS=30 HTTP_PROBE_INTERVAL_SECONDS=2 ./scripts/run/15-run-mitre-ics-attacks.sh
CORRELATION_WINDOW_SECONDS=120 ZABBIX_HISTORY_LOOKBACK_SECONDS=120 ZABBIX_HISTORY_FORWARD_SECONDS=120 ./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
```

Las pruebas rápidas anteriores se consideran validación técnica/piloto; la campaña final debe reportarse con los parámetros anteriores o con valores explícitamente documentados en la metadata generada.
