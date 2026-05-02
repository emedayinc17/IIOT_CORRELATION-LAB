#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; source "${ROOT_DIR}/scripts/lib/common.sh"
OUT_FILE="${1:-results/raw/mqtt_messages.csv}"; DURATION_SECONDS="${DURATION_SECONDS:-600}"
mkdir -p "$(dirname "$OUT_FILE")"; echo "timestamp_utc,topic,payload" > "$OUT_FILE"
ensure_mqtt_client; timeout "$DURATION_SECONDS" mosquitto_sub -h 10.10.0.151 -t 'sensors/#' -F '%I,%t,%p' >> "$OUT_FILE" || true
