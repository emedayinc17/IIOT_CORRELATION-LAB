# 01 — Architecture

## Arquitectura lógica

```text
┌───────────────────────────────────────────────────────────────┐
│                       Kubernetes Cluster                       │
│                       MicroK8s / Ubuntu                        │
│                       Node: iiot-lab-k8s                       │
│                       IP: 10.10.0.101                          │
├───────────────────────────────────────────────────────────────┤
│ Namespace: iiot-poc                                            │
│                                                               │
│  Sensor Simulator ─────MQTT────▶ Mosquitto Broker              │
│                                10.10.0.151:1883               │
│                                                               │
│  Health App        10.10.0.152:8080                            │
│  Telemetry API     10.10.0.153:8080                            │
│  Vulnerable App    10.10.0.154:8080                            │
├───────────────────────────────────────────────────────────────┤
│ Namespace: monitoring                                          │
│                                                               │
│  Zabbix Web UI     10.10.0.160:80                              │
│       │                                                       │
│       ▼                                                       │
│  Zabbix Server     10051/TCP                                   │
│       │                                                       │
│       ▼                                                       │
│  PostgreSQL + PVC  zabbix-postgres-pvc                         │
│                                                               │
│  Zabbix Agent2     DaemonSet                                   │
├───────────────────────────────────────────────────────────────┤
│ Namespace: security                                            │
│                                                               │
│  Wazuh Manager / Indexer / Dashboard                           │
│  Pendiente para Escenario C                                    │
├───────────────────────────────────────────────────────────────┤
│ Platform services                                              │
│                                                               │
│  CoreDNS / Calico / MetalLB / NGINX Ingress / hostpath-storage │
└───────────────────────────────────────────────────────────────┘
```

## Direccionamiento experimental

| Servicio | Namespace | IP/Endpoint | Propósito |
|---|---|---:|---|
| MQTT Broker | `iiot-poc` | `10.10.0.151:1883` | canal de telemetría |
| Health App | `iiot-poc` | `10.10.0.152:8080` | disponibilidad/SLA |
| Telemetry API | `iiot-poc` | `10.10.0.153:8080` | telemetría operacional |
| Vulnerable App | `iiot-poc` | `10.10.0.154:8080` | objetivo controlado |
| Zabbix UI | `monitoring` | `10.10.0.160:80` | monitoreo operacional |

## Segmentación lógica

| Namespace | Función |
|---|---|
| `iiot-poc` | zona IIoT simulada |
| `monitoring` | monitoreo operacional |
| `security` | seguridad/Wazuh |
| `ingress` | ingress controller |
| `kube-system` | servicios base Kubernetes |
| `metallb-system` | LoadBalancer L2 |

## Persistencia

| Componente | Persistencia | Justificación |
|---|---|---|
| Foundation IIoT | No crítica | servicios stateless o telemetría efímera |
| Mosquitto | No persistente | enfoque en telemetría en tiempo real |
| Zabbix PostgreSQL | PVC obligatorio | conserva configuración, histórico, eventos |
| Wazuh Indexer | PVC obligatorio futuro | conserva eventos y alertas |

## Decisiones arquitectónicas

- Kubernetes se usa como plataforma reproducible, no como objeto principal de investigación.
- Las IPs de MetalLB son estáticas para asegurar repetibilidad experimental.
- Zabbix se usa para observabilidad operacional.
- Wazuh se incorporará como capa de seguridad sobre eventos IIoT.
- La correlación se realizará posteriormente usando datasets exportados y timestamps normalizados.
