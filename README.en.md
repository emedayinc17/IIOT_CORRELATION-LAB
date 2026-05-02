# IIoT Correlation Lab

Reproducible laboratory for evaluating correlation between operational monitoring and security events in IIoT environments applied to Mining 4.0.

The project implements a controlled MicroK8s-based environment to observe how operational metrics collected by Zabbix relate to security events registered by Wazuh during MITRE ATT&CK for ICS techniques.

## Objective

Evaluate whether integrating operational monitoring and security monitoring can produce correlated, reproducible, and traceable evidence for representative IIoT events.

The laboratory scope is:

```text
IIoT + Zabbix + Wazuh + correlation
```

This project does not evaluate high availability, enterprise SIEM resilience, Kubernetes hardening, service mesh, or Kubernetes cluster security. Kubernetes is used only as a reproducible laboratory substrate.

## Architecture summary

| Layer | Components | Purpose |
|---|---|---|
| IIoT Foundation | Mosquitto, sensor-simulator, health-app, telemetry-api, vulnerable-app | Simulate IIoT services and telemetry |
| Operational monitoring | Zabbix Server, Zabbix Web, PostgreSQL, Zabbix Agent | Measure availability, latency, and operational history |
| Security monitoring | Wazuh Manager, Wazuh Indexer, Wazuh Dashboard | Register security events and MITRE ICS rules |
| Correlation | Scripts 15–18, CSV/SVG datasets, freezes | Relate Wazuh events with Zabbix metrics |

## Expected environment

| Element | Value |
|---|---|
| Kubernetes | MicroK8s |
| Node | single-node |
| OS | Ubuntu 24.04 |
| Runtime | containerd |
| CNI | Calico |
| Ingress | NGINX Ingress |
| LoadBalancer | MetalLB |
| StorageClass | microk8s-hostpath |

## Documentation map

| Document | Description |
|---|---|
| `docs/00-overview.md` | laboratory overview |
| `docs/01-architecture.md` | architecture and components |
| `docs/02-environment.md` | environment and prerequisites |
| `docs/03-foundation-iiot.md` | Foundation IIoT deployment |
| `docs/04-operational-baseline.md` | operational baseline |
| `docs/05-zabbix-monitoring.md` | operational monitoring with Zabbix |
| `docs/06-wazuh-security.md` | security instrumentation with Wazuh |
| `docs/07-correlation.md` | operational/security correlation |
| `docs/08-experiments.md` | experimental scenarios |
| `docs/09-results.md` | results, datasets, and evidence |
| `docs/10-reproducibility.md` | laboratory reproducibility |
| `docs/11-experimental-design.md` | scientific justification of experimental parameters |
| `docs/12-version-matrix.md` | version matrix |
| `docs/13-reviewer-traceability.md` | reviewer observation traceability |

## Experimental scenarios

| Scenario | Description | Expected result |
|---|---|---|
| A | Foundation IIoT | operational baseline without external monitoring |
| B | Foundation IIoT + Zabbix | real operational metrics and Zabbix history |
| C | Foundation IIoT + Zabbix + Wazuh | security baseline and Wazuh events |
| D | MITRE ICS attacks + correlation | correlated Zabbix/Wazuh datasets |

## Full reproducible execution flow

Scripts must be executed in numeric order from `scripts/run/`.

### Scenario A — Foundation IIoT

```bash
./scripts/run/00-reset-lab.sh
./scripts/run/01-deploy-foundation.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/02-run-operational-baseline.sh
./scripts/run/03-freeze-operational-baseline.sh
```

### Scenario B — Zabbix Monitoring

```bash
./scripts/run/04-deploy-zabbix.sh
./scripts/run/05-validate-zabbix.sh
ZABBIX_ITEM_DELAY=5s ./scripts/run/06-configure-zabbix-monitoring.sh
ITERATIONS=3 SLEEP_SECONDS=2 DURATION_SECONDS=20 ./scripts/run/07-run-zabbix-operational-baseline.sh
./scripts/run/08-freeze-zabbix-operational-baseline.sh
./scripts/run/09-export-lab-inventory.sh
./scripts/run/10-export-zabbix-configuration.sh
```

### Scenario C — Wazuh Security Baseline

```bash
./scripts/run/11-deploy-wazuh-security.sh
./scripts/run/12-validate-wazuh-security.sh
ITERATIONS=3 SLEEP_SECONDS=2 ./scripts/run/13-run-wazuh-security-baseline.sh
./scripts/run/14-freeze-wazuh-security-baseline.sh
```

### Scenario D — MITRE ATT&CK for ICS + correlation

Recommended final campaign:

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

## Methodological interpretation

Scenario D is not designed to maximize destructive operational degradation. It evaluates detection, temporal correlation, reproducible observability, and integration between Zabbix metrics and Wazuh events.

The attacks were executed under a controlled and reproducible model aimed at evaluating temporal correlation and observability, not at maximizing destructive degradation or extreme industrial resilience.

Therefore, techniques such as T0809 and T0814 may compromise logical integrity or generate security events without necessarily causing severe SLA or availability degradation. T0860, however, explicitly targets availability and can generate observable HTTP errors.

## Expected final state

After completing scripts `00` through `18`, the laboratory should include:

```text
[OK] Foundation IIoT deployed and frozen
[OK] Zabbix with real operational history
[OK] Wazuh with MITRE ICS events and functional dashboard/API
[OK] Scenario D campaign executed with 20 iterations
[OK] Raw/processed/tables/figures datasets generated
[OK] Final reproducible freeze with SHA256SUMS
```
