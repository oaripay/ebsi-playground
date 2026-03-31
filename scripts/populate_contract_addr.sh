#!/bin/bash

set -e  # exit on any error
test -n "$DEBUG" && set -x

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
root_dir="$script_dir/.."
env_dir="$root_dir/env/all_nodes/core-services"

cd "$root_dir"

if [ ! -e "$root_dir/deployment/deployments.env" ];then
    echo "Deploy the contracts first"
    exit 0
fi

source $root_dir/deployment/deployments.env

echo "CONTRACT_ADDR=$DIDR_SC_V5_ADDRESS" > $env_dir/did-registry-api-v5.env

echo "CONTRACT_ADDR=$TIMESTAMP_SC_V4_ADDRESS" > $env_dir/timestamp-api-v4.env

echo "NODE_ENV=development" > $env_dir/trusted-issuers-registry-api-v5.env
echo "BESU_TRUSTED_ISSUERS_REGISTRY_ADDRESS=$TIR_SC_V5_ADDRESS" >> $env_dir/trusted-issuers-registry-api-v5.env

echo "CONTRACT_ADDR=$TPR_SC_V3_ADDRESS" > $env_dir/trusted-policies-registry-api-v3.env

echo "CONTRACT_ADDR=$TSR_SC_V3_ADDRESS" > $env_dir/trusted-schemas-registry-api-v3.env
