#!/usr/bin/env bash
set -euo pipefail

MOTO_ENDPOINT="${SQS_ENDPOINT:-http://localhost:5000}"
AWS_REGION="${AWS_REGION:-us-east-1}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_REGION

is_up() { curl -sSf "${MOTO_ENDPOINT}/" >/dev/null 2>&1; }

echo "[moto-seed] Waiting for Moto at ${MOTO_ENDPOINT} ..."
for i in {1..120}; do
  if is_up; then
    echo "[moto-seed] Moto is up."
    break
  fi
  sleep 0.25
done

create_q () {
  aws --endpoint-url="$MOTO_ENDPOINT" --region "$AWS_REGION" \
    sqs create-queue --queue-name "$1" >/dev/null
  echo "  - ensured queue: $1"
}

echo "[moto-seed] Creating queues if they don't exist"
create_q "report_sender"
create_q "mixpanel_events"
create_q "newrelic_events"
echo "[moto-seed] Done."
