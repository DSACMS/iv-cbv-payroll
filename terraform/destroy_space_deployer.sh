#!/usr/bin/env bash

set -e

if [[ $# -ne 2 ]]; then
  echo "$0 <<SPACE_NAME>> <<ACCOUNT_NAME>>"
  exit 1;
fi

space=$1
service=$2

cf target -s $space

# destroy service key
cf delete-service-key $service space-deployer-key -f

# destroy service
cf delete-service $service -f
