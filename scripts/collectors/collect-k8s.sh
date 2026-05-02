#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; source "${ROOT_DIR}/scripts/lib/common.sh"
OUT_FILE="${1:-results/raw/k8s_resources.csv}"; ITERATIONS="${ITERATIONS:-300}"; SLEEP_SECONDS="${SLEEP_SECONDS:-2}"; KUBECTL="$(detect_kubectl)"
mkdir -p "$(dirname "$OUT_FILE")"; echo "timestamp_utc,type,namespace,name,cpu,memory,cpu_percent,memory_percent" > "$OUT_FILE"
for i in $(seq 1 "$ITERATIONS"); do ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; ${KUBECTL} top pods -n iiot-poc --no-headers 2>/dev/null | while read -r name cpu mem; do [[ -n "${name:-}" ]] && echo "$ts,pod,iiot-poc,$name,$cpu,$mem,," >> "$OUT_FILE"; done; ${KUBECTL} top nodes --no-headers 2>/dev/null | while read -r name cpu cpu_pct mem mem_pct; do [[ -n "${name:-}" ]] && echo "$ts,node,,$name,$cpu,$mem,$cpu_pct,$mem_pct" >> "$OUT_FILE"; done; sleep "$SLEEP_SECONDS"; done
