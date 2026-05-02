#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"
script_start "$(basename "$0")"
OUT_FILE="${1:-results/raw/http_baseline.csv}"; ITERATIONS="${ITERATIONS:-300}"; SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
mkdir -p "$(dirname "$OUT_FILE")"; echo "timestamp_utc,target,http_code,time_total_seconds" > "$OUT_FILE"
collect(){ local target="$1"; local url="$2"; local ts result code total; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; result="$(curl -s -o /dev/null -w "%{http_code},%{time_total}" "$url" || echo "000,0")"; code="$(echo "$result"|cut -d',' -f1)"; total="$(echo "$result"|cut -d',' -f2)"; echo "$ts,$target,$code,$total" >> "$OUT_FILE"; }
for i in $(seq 1 "$ITERATIONS"); do collect "health-app" "http://10.10.0.152:8080/health"; collect "telemetry-api" "http://10.10.0.153:8080/telemetry"; collect "vulnerable-app" "http://10.10.0.154:8080/health"; sleep "$SLEEP_SECONDS"; done
