#!/bin/bash

set -o pipefail

# --- Configuration ---
TOTAL_RUNS=4
COOL_DOWN_SECONDS=10 # 10 seconds
export URL=https://verify-demo.navapbc.cloud/cbv/employer_search

declare -a VUS_ARRAY
declare -a REQ_COUNT_ARRAY
declare -a REQ_RATE_ARRAY

echo "Running $TOTAL_RUNS stress tests and collecting results..."
echo "----------------------------------------------------------"

for i in $(seq 1 $TOTAL_RUNS)
do
  echo ""
  echo "Iteration $i of $TOTAL_RUNS ---"

  SUMMARY_FILE="summary_${i}.json"
  export COOKIE=$(curl -L --cookie-jar - https://verify-demo.navapbc.cloud/cbv/links/sandbox | grep _iv_cbv_payroll_session | cut -f 7)
  k6 run --summary-export=$SUMMARY_FILE stresstest.js
  K6_EXIT_CODE=$? # Capture the exit code of the k6 command

  if [ -f "$SUMMARY_FILE" ]; then
    VUS=$(jq '.metrics.vus.value' $SUMMARY_FILE)
    REQ_COUNT=$(jq '.metrics.http_reqs.count' $SUMMARY_FILE)
    REQ_RATE=$(jq '.metrics.http_reqs.rate' $SUMMARY_FILE)

    VUS_ARRAY+=(${VUS:-0})
    REQ_COUNT_ARRAY+=(${REQ_COUNT:-0})
    REQ_RATE_ARRAY+=(${REQ_RATE:-0})

    rm $SUMMARY_FILE
  fi

  # Only cool down if it's not the last run
  if [ $i -lt $TOTAL_RUNS ]; then
    echo ""
    echo "Cooling down for $COOL_DOWN_SECONDS seconds before the next run..."
    sleep $COOL_DOWN_SECONDS
  fi
done

echo ""
echo "---------------------------------------------"
echo "All test runs complete. Consolidated Summary:"
echo "---------------------------------------------"
echo "Run,VUs,Total_Reqs,Reqs_Per_Sec"

for i in $(seq 0 $(($TOTAL_RUNS - 1)))
do
  RUN_NUM=$(($i + 1))
  printf "%d,%.0f,%.0f,%.2f\n" "$RUN_NUM" "${VUS_ARRAY[$i]}" "${REQ_COUNT_ARRAY[$i]}" "${REQ_RATE_ARRAY[$i]}"
done

echo "---------------------------------------------"
