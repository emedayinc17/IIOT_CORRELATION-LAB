# IIoT Correlation Lab — Zabbix + Wazuh for Mining 4.0

Reproducible laboratory to evaluate correlation between operational monitoring and security events in a simulated IIoT environment, oriented to Mining 4.0 and critical industrial infrastructure scenarios.

This repository implements a complete experimental chain based on:

```text
IIoT Foundation → Zabbix Monitoring → Wazuh Security → MITRE ICS Correlation
```

The objective is not to evaluate Kubernetes, high availability, hardening, or enterprise SIEM performance. Kubernetes/MicroK8s is used only as a reproducible execution platform for the lab.

---

## 1. Project objective

The lab aims to demonstrate, under controlled and reproducible conditions, that an integrated operational and security monitoring architecture can correlate:

- operational metrics from IIoT services collected by Zabbix;
- security events registered by Wazuh;
- controlled attacks mapped to MITRE ATT&CK for ICS;
- common temporal windows for experimental analysis.

The generated evidence supports an academic paper on IIoT, Mining 4.0, operational monitoring, security event detection, and experimental correlation.

---

## 2. Methodological scope

The lab is intentionally simple, controlled, and reproducible. It does not implement enterprise architecture or components that do not directly support the experimental hypothesis.

| Included | Excluded |
|---|---|
| MicroK8s single-node | HA Kubernetes cluster |
| Simulated IIoT Foundation | Real production industrial systems |
| Persistent Zabbix | Prometheus/Grafana as an additional layer |
| Single-node/all-in-one Wazuh | Distributed/HA Wazuh |
| Controlled MITRE ATT&CK for ICS | Uncontrolled attacks |
| Datasets, tables, figures, and freeze | Kubernetes hardening evaluation |

Guiding principle:

```text
If it does not strengthen reproducibility, correlation, or experimental evidence, it is not implemented.
```

---

## 3. Expected base environment

The lab was built and validated on the following environment:

| Element | Expected value |
|---|---|
| Kubernetes | MicroK8s |
| Kubernetes version | v1.30.x |
| Node | single-node |
| Operating system | Ubuntu 24.04 |
| Runtime | containerd |
| CNI | Calico |
| Ingress | NGINX Ingress |
| LoadBalancer | MetalLB |
| StorageClass | microk8s-hostpath |

Scripts validate prerequisites before continuing and export evidence under `evidence/` and `baseline/`.

---

## 4. Experimental architecture

| Layer | Components | Experimental role |
|---|---|---|
| IIoT Foundation | Mosquitto, health-app, telemetry-api, vulnerable-app, sensor-simulator | Target services and base instrumentation |
| Operational monitoring | Zabbix Server, PostgreSQL, Zabbix Web, Zabbix Agent | Availability and latency metrics with real `history.get` |
| Security | Wazuh Manager, Indexer, Dashboard | Security events and MITRE ICS rules |
| Correlation | Scripts `15–18` | Attacks, extraction, correlation, tables, figures, and freeze |

Default MetalLB IPs:

| Service | IP |
|---|---:|
| MQTT / Mosquitto | `10.10.0.151` |
| health-app | `10.10.0.152` |
| telemetry-api | `10.10.0.153` |
| vulnerable-app | `10.10.0.154` |
| Zabbix Web/API | `10.10.0.160` |
| Wazuh Dashboard | `10.10.0.161` |
| Wazuh Manager/API | `10.10.0.162` |

---

## 5. Experimental scenarios

| Scenario | Purpose | Main output |
|---|---|---|
| A — IIoT Foundation | Deploy IIoT services and capture baseline without external monitoring | `baseline/scenario_A_*` |
| B — Zabbix Monitoring | Configure operational monitoring and Zabbix baseline | `baseline/scenario_B_*` |
| C — Wazuh Security | Deploy Wazuh and register baseline security events | `baseline/scenario_c_wazuh_security/` |
| D — MITRE ICS Correlation | Run controlled attacks and correlate Zabbix/Wazuh | `baseline/scenario_d_correlation_*` |

MITRE ATT&CK for ICS techniques used in D:

| Technique | ID | Target component |
|---|---|---|
| Unauthorized Command Message | T0809 | `mosquitto` |
| Data Manipulation | T0814 | `telemetry-api` |
| Denial of Service | T0860 | `vulnerable-app` |

---

## 6. Repository structure

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

## 7. Technical and methodological documentation

| Document | Description |
|---|---|
| `docs/00-overview.md` | Lab overview |
| `docs/01-architecture.md` | Architecture and components |
| `docs/02-environment.md` | Environment and prerequisites |
| `docs/03-foundation-iiot.md` | IIoT Foundation |
| `docs/04-operational-baseline.md` | Operational baseline |
| `docs/05-zabbix-monitoring.md` | Zabbix and real metrics |
| `docs/06-wazuh-security.md` | Wazuh, rules, Dashboard/API |
| `docs/07-correlation.md` | Correlation model |
| `docs/08-experiments.md` | Scenarios and parameters |
| `docs/09-results.md` | Results, datasets, and evidence |
| `docs/10-reproducibility.md` | Reproducible workflow and freeze |
| `docs/11-experimental-design.md` | Scientific justification |
| `docs/12-version-matrix.md` | Version matrix |
| `docs/13-reviewer-traceability.md` | Reviewer traceability |

---

## 8. Complete reproducible execution flow

Run from the repository root:

```bash
cd ~/iiot-correlation-lab
chmod +x scripts/run/*.sh scripts/collectors/*.sh
```

### 8.1 Scenario A — IIoT Foundation

```bash
./scripts/run/00-reset-lab.sh
./scripts/run/01-deploy-foundation.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
```

Purpose: initial validation of IIoT services and baseline without additional monitoring.

### 8.2 Scenario B — Zabbix Monitoring

```bash
./scripts/run/04-deploy-zabbix.sh
./scripts/run/05-validate-zabbix.sh
ZABBIX_ITEM_DELAY=5s ./scripts/run/06-configure-zabbix-monitoring.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
```

Purpose: operational instrumentation. Script `06` validates that Zabbix produces real `history.get` samples for IIoT items.

### 8.3 Scenario C — Wazuh Security

```bash
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
ITERATIONS=3 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

Purpose: single-node/all-in-one Wazuh deployment/reconciliation, IIoT/MITRE ICS rules, Dashboard/API, and security baseline.

### 8.4 Scenario D — MITRE ICS + Correlation

Quick validation run:

```bash
ITERATIONS=5 SLEEP_SECONDS=2 ./scripts/run/15-run-mitre-ics-attacks.sh
CORRELATION_WINDOW_SECONDS=120 ./scripts/run/16-run-correlation-experiment.sh
./scripts/run/17-export-final-datasets.sh
./scripts/run/18-freeze-correlation-results.sh
```

Recommended paper-final campaign:

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

Notes:

- `ITERATIONS=20` improves statistical robustness compared with a quick validation run.
- `ZABBIX_ITEM_DELAY=5s` improves temporal proximity between attack and operational sample.
- `BASELINE_WARMUP_SECONDS=60` allows real pre-attack samples to be captured.
- `DOS_REQUESTS`, `DOS_CONCURRENCY`, and `ATTACK_DURATION_SECONDS` increase the chance of observable operational degradation.
- `ZABBIX_HISTORY_LOOKBACK_SECONDS=120` and `ZABBIX_HISTORY_FORWARD_SECONDS=120` avoid diluted correlations from overly broad windows.

---

## 9. Validation run vs final campaign

| Run type | Purpose | Typical parameters |
|---|---|---|
| Technical validation | Verify infrastructure, collectors, and datasets | `ITERATIONS=3–5`, short attacks |
| Paper-final campaign | Generate defensible experimental evidence | `ITERATIONS=20+`, Zabbix 5s, calibrated DoS, 120s windows |

A technical validation run should not be overinterpreted as final experimental evidence. The final campaign should be used for detection, correlation, and operational impact discussion.

---

## 10. Generated results

```text
results/raw/          raw datasets by scenario
results/processed/    correlated and processed datasets
results/tables/       tables ready for analysis/paper
results/figures/      reproducible SVG figures
baseline/             reproducible scenario freezes
evidence/             inventories, logs, configuration, and evidence
```

Key Scenario D files:

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

## 11. Reproducibility and freeze

Each scenario generates frozen evidence. Freezes include datasets, Kubernetes snapshots, relevant manifests, and `SHA256SUMS` where applicable.

```text
baseline/scenario_A_*
baseline/scenario_B_*
baseline/scenario_c_wazuh_security/
baseline/scenario_d_correlation_*
```

The freeze allows an evaluator to review exactly what was executed and what evidence was generated.

---

## 12. Bilingual operational messages

Scripts print bilingual guidance in Spanish and English, including:

- script objective;
- approximate ETA;
- current phase;
- operator notes;
- final `[SUMMARY]`.

This supports local execution, international review, and technical defense.

---

## 13. Declared limitations

This lab does not represent a real production mining plant. It is a controlled, reproducible, academic IIoT environment. Conclusions must be limited to the experimental validity of the lab and not generalized as absolute claims about real industrial environments.

Main limitations:

- reduced scale;
- simulated IIoT services;
- single-node Wazuh;
- single-node MicroK8s;
- controlled attacks;
- dependency on attack intensity and temporal-window parameters.

These limitations are explicit to avoid overclaiming and strengthen methodological transparency.

---

## 14. Expected state before using results in the paper

Before writing final results, verify:

```bash
cat results/tables/table_attack_detection.csv
cat results/tables/table_correlation_latency.csv
cat results/tables/table_sla_impact.csv
cat results/tables/table_zabbix_history_quality.csv
column -s, -t < results/processed/correlation_dataset.csv | head -30
```

Minimum criteria:

- Wazuh detects events by MITRE ICS technique;
- Zabbix contains real `history.get` samples;
- `avg_nearest_zabbix_sample_delta_s` is within a defensible temporal window;
- operational degradation is not reported unless supported by data;
- limitations are explicitly declared.

