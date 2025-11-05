#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${SQS_ENDPOINT:-http://localhost:3456}"
REGION="${AWS_REGION:-us-east-1}"

QUEUES=(report_sender mixpanel_events newrelic_events)

echo "[wait] Ensuring Moto is up at $ENDPOINT ..."
for i in {1..120}; do
  if curl -sSf "$ENDPOINT/" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

for q in "${QUEUES[@]}"; do
  echo "[wait] Waiting for queue: $q"
  for i in {1..60}; do
    if aws --endpoint-url="$ENDPOINT" --region "$REGION" \
        sqs get-queue-url --queue-name "$q" >/dev/null 2>&1; then
      echo "  ✓ $q found"
      break
    fi
    sleep 0.5
  done
done
