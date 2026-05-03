# 05 — Zabbix Operational Monitoring

This section defines the operational observability layer used by the IIoT Correlation Lab. Zabbix is used to collect availability and latency indicators from the IIoT services deployed in the `iiot-poc` namespace.

## Scope

Zabbix is used only for operational monitoring. It is not used as a security tool and does not replace Wazuh. Its role in the experimental workflow is to provide measurable operational telemetry that can later be correlated with Wazuh security events.

## Monitored IIoT services

| Host | MetalLB IP | Port | Zabbix checks |
|---|---:|---:|---|
| `mqtt-broker` | `10.10.0.151` | `1883` | TCP availability and TCP latency |
| `health-app` | `10.10.0.152` | `8080` | HTTP availability and HTTP latency |
| `telemetry-api` | `10.10.0.153` | `8080` | HTTP availability and HTTP latency |
| `vulnerable-app` | `10.10.0.154` | `8080` | HTTP availability and HTTP latency |

## Correct simple-check configuration

The Zabbix simple checks must include the target IP explicitly in the item key. This avoids unsupported items when the host interface is absent or not usable by the simple check engine.

Correct examples:

```text
net.tcp.service[http,10.10.0.152,8080]
net.tcp.service.perf[http,10.10.0.152,8080]
net.tcp.service[tcp,10.10.0.151,1883]
net.tcp.service.perf[tcp,10.10.0.151,1883]
```

The following form must not be used because it leaves the IP parameter empty and can make the item unsupported:

```text
net.tcp.service[http,,8080]
net.tcp.service.perf[http,,8080]
```

## Reproducible configuration

The operational monitoring layer is configured with:

```bash
./scripts/run/06-configure-zabbix-monitoring.sh
```

The script performs the following actions:

1. Validates the Zabbix API and web endpoint.
2. Creates or updates the `IIoT Lab Services` host group.
3. Creates or updates the four IIoT hosts.
4. Ensures each host has an explicit IP interface mapped to the corresponding MetalLB address.
5. Creates or updates availability and latency items using explicit-IP simple checks.
6. Removes or updates legacy unsupported items with empty IP parameters.
7. Creates or updates operational triggers.
8. Waits until `history.get` returns real samples for all monitored items.
9. Exports configuration evidence under `evidence/zabbix/`.

## Experimental relevance

The Scenario D correlation workflow depends on Zabbix historical samples. Therefore, `item.get.lastvalue` is not considered sufficient evidence for the paper. The experimental pipeline requires real `history.get` samples with non-zero `lastclock` values before generating quantitative correlation datasets.
