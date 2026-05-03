# Version Matrix

Generated UTC: 2026-05-02T04:01:38Z

| Component | Value |
|---|---|
| Hostname | iiot-lab-k8s |
| OS | Ubuntu 24.04.3 LTS |
| Kernel | 6.8.0-79-generic |
| Node | iiot-lab-k8s |
| Kubernetes | v1.30.14 |
| MicroK8s | MicroK8s v1.30.14 revision 8566 |
| Container Runtime | containerd://1.6.28 |
| OS Image | Ubuntu 24.04.3 LTS |
| Architecture | amd64 |

## IIoT Images

```text
health-app=python:3.11-slim
mosquitto=eclipse-mosquitto:2.0.20
sensor-simulator=eclipse-mosquitto:2.0.20
telemetry-api=python:3.11-slim
vulnerable-app=python:3.11-slim
```

## Monitoring Images

```text
zabbix-postgres=postgres:16
zabbix-server=zabbix/zabbix-server-pgsql:ubuntu-7.0-latest
zabbix-web=zabbix/zabbix-web-nginx-pgsql:ubuntu-7.0-latest
zabbix-agent=zabbix/zabbix-agent2:ubuntu-7.0-latest
```
