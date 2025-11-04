#!/usr/bin/env bash
set -euo pipefail

MOTO_ENDPOINT="${SQS_ENDPOINT:-http://localhost:5000}"
PORT="${MOTO_ENDPOINT##*:}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

is_moto() { curl -sSf "${MOTO_ENDPOINT}/" >/dev/null 2>&1; }

if is_moto; then
  echo "[moto] Moto already running at ${MOTO_ENDPOINT}. Not starting another."
  # Keep the process alive so Foreman doesn't shut everything down
  exec tail -f /dev/null
fi

# If port is in use but not by Moto, abort clearly
if command -v ss >/dev/null 2>&1 && ss -ltn "( sport = :${PORT} )" | grep -q LISTEN; then
  echo "[moto] ERROR: Port ${PORT} is in use by another program (not Moto). Change SQS_ENDPOINT or free the port."
  exit 1
fi

echo "[moto] Starting Moto on ${MOTO_ENDPOINT} ..."
exec moto_server -p "${PORT}"
