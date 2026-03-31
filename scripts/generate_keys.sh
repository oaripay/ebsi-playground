#!/bin/bash

set -e  # exit on any error
test -n "$DEBUG" && set -x

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
root_dir="$script_dir/.."

# change current dir to repo root dir for the duration of this script
cd "$root_dir"

# clone validator smart contract repo

if [ -e "keys/genesis.json" ]; then echo "keys/genesis.json already exists. Exiting..."; exit; fi

# cleanup and create tmp dir for besu container volume:
rm -rf keys/tmp
mkdir -p keys/tmp
chmod -R 777 keys/tmp

echo "Generate client keys and genesis file..."
docker run --rm -v ./:/repo_root hyperledger/besu:24.9.1 \
    operator generate-blockchain-config \
        --config-file=/repo_root/scripts/generate_keys.conf.json \
        --to=/repo_root/keys/tmp \
        --private-key-file-name=key
# get addresses
addresses=$(find keys/tmp/keys/ -type d -exec basename {} \; | grep '^0x' | tr '\n' ',' | sed 's/,$//')
admin_address=$(find keys/tmp/keys/ -type d -exec basename {} \; | grep '^0x' | head -n 1)
priv_key=$(cat keys/tmp/keys/${admin_address}/key)


echo "Generate genesis file"
docker run --rm -v ./sources/validator-smart-contract:/temp -v ./keys/tmp:/genesis -w /app node:24.14.1 \
    sh -c "mkdir -p /app \
    && cp -r /temp/* /app/ \
    && echo '${priv_key}' > .secret.privatekey \
    && yarn install \
    && npx hardhat --network hardhat genesis --role-operator ${admin_address} --validators '${addresses}' --multisig-owners ${admin_address} --multisig-required 1 --chain-id 6175 \
    && cp ./generated/6175/genesis.json /genesis"

echo "Copy genesis file -> keys/genesis.json"

# Apply free gas settings and fund hardhat deployer account
jq '
  .alloc["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"] = {balance: "100000000000000000000"} |
  .config.zeroBaseFee = true |
  .config.contractSizeLimit = 2147483647 |
  .gasLimit = "0x1fffffffffffff"
' keys/tmp/genesis.json > keys/genesis.json && echo "Applied free gas config and added hardhat deployer (100 ETH) to genesis"

n=1
for dir in $(ls -d keys/tmp/keys/* | sort); do
    mkdir -p keys/node$n
    echo "Copy $dir -> keys/node$n"
    cp -a "$dir/key" "$dir/key.pub" keys/node$n/
    ((n++))
done

echo "Configure Besu bootnode address from node1 public key -> keys/bootnode.env"
NODE1_PUBKEY=$(tail -c 128 keys/node1/key.pub)
echo "BESU_BOOTNODE_PUBKEY=$NODE1_PUBKEY" > keys/bootnode.env

# fix permissions to make sure keys can be read by non-root container users:
chmod -R go+rx keys
