# 02 — Environment

## Especificación base del entorno

| Elemento | Valor esperado |
|---|---|
| VM | `iiot-lab-k8s` |
| OS | Ubuntu Server 24.04 LTS |
| Kubernetes | MicroK8s v1.30.x |
| Runtime | containerd |
| CNI | Calico |
| Ingress | NGINX Ingress Controller |
| LoadBalancer | MetalLB |
| StorageClass | `microk8s-hostpath` |
| Nodo | single-node experimental |
| Red laboratorio | `10.10.0.0/24` |

## Recursos de VM

| Recurso | Valor |
|---|---:|
| vCPU | 6 o más |
| RAM | 16 GB o más |
| Disco sistema | 80 GB |
| Disco Kubernetes | 100 GB o más |
| Mount recomendado | `/mnt/k8s-storage` |

## Network policies

En esta etapa no se aplican `NetworkPolicy` restrictivas porque el objetivo es garantizar conectividad reproducible entre servicios experimentales y herramientas de observabilidad. La segmentación se realiza mediante namespaces e IPs controladas. Las `NetworkPolicy` pueden agregarse en una iteración posterior si el análisis requiere evaluar aislamiento de red.

## Validación de ambiente

El inventario se exporta mediante:

```bash
./scripts/run/09-export-lab-inventory.sh
```

El resultado se almacena en:

```text
evidence/inventory/
```
