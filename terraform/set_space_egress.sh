#!/usr/bin/env bash

org="TKTK-cloud.gov-org-name"

usage="
$0: Set egress rules for given space

Usage:
  $0 -h
  $0 -s <SPACE NAME> [-o <ORG NAME>] [-p] [-t]

Options:
-h: show help and exit
-s <SPACE NAME>: configure the space to act on. Required
-o <ORG NAME>: configure the organization to act on. Default: $org
-p: Add the public egress rules
-t: Add the trusted egress rules

Notes:
* If -p or -t are not passed, the related security groups will be removed, if they were present
"

set -e

space=""
public=false
trusted=false

while getopts ":hs:o:pt" opt; do
  case "$opt" in
    s)
      space=${OPTARG}
      ;;
    o)
      org=${OPTARG}
      ;;
    p)
      public=true
      ;;
    t)
      trusted=true
      ;;
    h)
      echo "$usage"
      exit 0
      ;;
  esac
done

if [[ $space = "" ]]; then
  echo "$usage"
  exit 1
fi

if [[ $public = true ]]; then
  cf bind-security-group public_networks_egress $org --space $space
else
  cf unbind-security-group public_networks_egress $org $space
fi

if [[ $trusted = true ]]; then
  cf bind-security-group trusted_local_networks_egress $org --space $space
else
  cf unbind-security-group trusted_local_networks_egress $org $space
fi

echo "Done"
