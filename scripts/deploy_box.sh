#!/bin/bash

set -e  # exit on any error
test -n "$DEBUG" && set -x

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
root_dir="$script_dir/.."

# change current dir to repo root dir for the duration of this script
cd "$root_dir"

# clone validator smart contract repo

docker run --network=host --rm -v ./sources/core-services:/temp -v ./deployment:/deployment -w /app node:24.14.1 \
    sh -c "mkdir -p /app \
    && export CI=1 \
    && apt update \
    && apt install -y jq \
    && cp -r /temp/* /app/ \
    && corepack enable \
    && pnpm install \
    && pnpm build:all \
    && cd contracts/admin-scripts \
    && echo 'TEST_HARDHAT_NETWORK_URL=http://127.0.0.1:8545' >> .env \
    && echo 'PILOT_HARDHAT_NETWORK_URL=http://127.0.0.1:8545' >> .env \
    && echo 'CONFORMANCE_HARDHAT_NETWORK_URL=http://127.0.0.1:8545' >> .env \
    && pnpm compile \
    && npx hardhat accounts --network box \
    && touch deployments.env \
    && touch wallets.env \
    && pnpm box \
    && cp deployments.env /deployment/deployments.env \
    && sort -u -t '=' -k 1,1 .env deployments.env wallets.env > .envmix \
    && mv .envmix .env \
    && echo 'EBSI_DOMAIN=https://ebsi.oari.io' >> .env \
    && npx hardhat --network box bootstrap \
    && cp wallets.env /deployment/wallets.env"
