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
