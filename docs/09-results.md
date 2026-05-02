# 09 — Results

## Estructura

```text
results/
├── raw/
├── processed/
├── figures/
└── tables/
```

## Escenario A

| Archivo | Descripción |
|---|---|
| `http_baseline.csv` | latencia y disponibilidad HTTP |
| `mqtt_messages.csv` | telemetría MQTT |
| `k8s_resources.csv` | recursos Kubernetes |
| `experiment_metadata.json` | metadata |

## Escenario B

| Archivo | Descripción |
|---|---|
| `http_baseline_zabbix.csv` | latencia HTTP con Zabbix activo |
| `mqtt_messages_zabbix.csv` | telemetría MQTT con Zabbix activo |
| `k8s_resources_zabbix.csv` | recursos Kubernetes con Zabbix |
| `zabbix_items_snapshot.csv` | snapshot de items Zabbix |
| `experiment_metadata_zabbix.json` | metadata |

## Evidencia adicional

```text
evidence/inventory/
evidence/zabbix/
baseline/scenario_A_*.tar.gz
baseline/scenario_B_*.tar.gz
```


## Escenario C

| Archivo | Descripción |
|---|---|
| `results/raw/scenario_c/wazuh_security_baseline.csv` | eventos estructurados de baseline de seguridad |
| `evidence/wazuh/*-wazuh-validation-summary.csv` | validación técnica de componentes Wazuh |
| `evidence/wazuh/*-scenario-c-baseline-events.ndjson` | eventos JSON escritos para Wazuh Manager |
| `evidence/wazuh/*-wazuh-alerts-tail.json` | cola de alertas Wazuh al momento de la corrida |
| `evidence/wazuh/*-wazuh-archives-tail.json` | cola de archivos Wazuh al momento de la corrida |
| `baseline/scenario_c_wazuh_security/SHA256SUMS` | checksums del freeze |

## Evidencia adicional actualizada

```text
evidence/inventory/
evidence/zabbix/
evidence/wazuh/
baseline/scenario_A_*
baseline/scenario_B_*
baseline/scenario_c_wazuh_security/
```
