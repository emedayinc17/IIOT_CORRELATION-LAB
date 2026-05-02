#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"

KUBECTL="$(detect_kubectl)"
OUT_DIR="${ROOT_DIR}/evidence/inventory"
mkdir -p "$OUT_DIR"

log "Exportando inventario del laboratorio..."

OS_PRETTY="$(. /etc/os-release && echo "${PRETTY_NAME}")"
KERNEL="$(uname -r)"
HOSTNAME="$(hostname)"
DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NODE_NAME="$(${KUBECTL} get nodes -o jsonpath='{.items[0].metadata.name}')"
K8S_VERSION="$(${KUBECTL} get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')"
CONTAINER_RUNTIME="$(${KUBECTL} get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}')"
OS_IMAGE="$(${KUBECTL} get nodes -o jsonpath='{.items[0].status.nodeInfo.osImage}')"
ARCH="$(${KUBECTL} get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}')"
MICROK8S_VERSION="$(microk8s version 2>/dev/null | head -n 1 || true)"

${KUBECTL} get nodes -o wide > "${OUT_DIR}/nodes.txt"
${KUBECTL} get pods -A -o wide > "${OUT_DIR}/pods_all.txt"
${KUBECTL} get svc -A -o wide > "${OUT_DIR}/services_all.txt"
${KUBECTL} get ns > "${OUT_DIR}/namespaces.txt"
${KUBECTL} get sc -o wide > "${OUT_DIR}/storageclasses.txt"
${KUBECTL} get ingressclass -o wide > "${OUT_DIR}/ingressclasses.txt" || true
${KUBECTL} get ipaddresspool -A -o yaml > "${OUT_DIR}/metallb_ipaddresspools.yaml" || true
${KUBECTL} get l2advertisement -A -o yaml > "${OUT_DIR}/metallb_l2advertisements.yaml" || true
${KUBECTL} get deploy -n iiot-poc -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.template.spec.containers[0].image}{"\n"}{end}' > "${OUT_DIR}/iiot_images.txt" || true
${KUBECTL} get deploy -n monitoring -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.template.spec.containers[0].image}{"\n"}{end}' > "${OUT_DIR}/monitoring_images.txt" || true
${KUBECTL} get ds -n monitoring -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.template.spec.containers[0].image}{"\n"}{end}' > "${OUT_DIR}/monitoring_daemonset_images.txt" || true

cat > "${OUT_DIR}/version_matrix.md" <<EOF
# Version Matrix

Generated UTC: ${DATE_UTC}

| Component | Value |
|---|---|
| Hostname | ${HOSTNAME} |
| OS | ${OS_PRETTY} |
| Kernel | ${KERNEL} |
| Node | ${NODE_NAME} |
| Kubernetes | ${K8S_VERSION} |
| MicroK8s | ${MICROK8S_VERSION} |
| Container Runtime | ${CONTAINER_RUNTIME} |
| OS Image | ${OS_IMAGE} |
| Architecture | ${ARCH} |

## IIoT Images

\`\`\`text
$(cat "${OUT_DIR}/iiot_images.txt" 2>/dev/null || true)
\`\`\`

## Monitoring Images

\`\`\`text
$(cat "${OUT_DIR}/monitoring_images.txt" 2>/dev/null || true)
$(cat "${OUT_DIR}/monitoring_daemonset_images.txt" 2>/dev/null || true)
\`\`\`
EOF

python3 - <<PY
import json
from pathlib import Path
data = {
    "generated_utc": "${DATE_UTC}",
    "hostname": "${HOSTNAME}",
    "os": "${OS_PRETTY}",
    "kernel": "${KERNEL}",
    "node": "${NODE_NAME}",
    "kubernetes": "${K8S_VERSION}",
    "microk8s": "${MICROK8S_VERSION}",
    "container_runtime": "${CONTAINER_RUNTIME}",
    "os_image": "${OS_IMAGE}",
    "architecture": "${ARCH}"
}
Path("${OUT_DIR}/version_matrix.json").write_text(json.dumps(data, indent=2))
PY

summary_header "Lab Inventory Export"
summary_ok "Nodos exportados"
summary_ok "Pods y servicios exportados"
summary_ok "StorageClass e IngressClass exportados"
summary_ok "MetalLB exportado"
summary_ok "Imágenes IIoT y Monitoring exportadas"
summary_ok "Matriz de versiones generada: evidence/inventory/version_matrix.md"
summary_ok "Inventario listo para documentación de reproducibilidad"
