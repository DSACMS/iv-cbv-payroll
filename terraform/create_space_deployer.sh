#!/usr/bin/env bash

set -e
set -o pipefail

if [[ $# -lt 2 ]]; then
  echo "$0 <<SPACE_NAME>> <<ACCOUNT_NAME>>"
  exit 1;
fi

space=$1
service=$2

cf target -s $space 1>&2

# create space deployer service
cf create-service cloud-gov-service-account space-deployer $service 1>&2

# create service key
cf create-service-key $service space-deployer-key 1>&2

# output service key to stdout in secrets.auto.tfvars format
creds=`cf service-key $service space-deployer-key | tail -n 4`
username=`echo $creds | jq '.username'`
password=`echo $creds | jq '.password'`

cat << EOF
# generated with $0 $space $service
# revoke with $(dirname $0)/destroy_space_deployer.sh $space $service

cf_user = $username
cf_password = $password
EOF
