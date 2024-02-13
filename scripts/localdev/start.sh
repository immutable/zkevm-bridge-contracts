#!/bin/bash
set -ex
set -o pipefail

# Stop previous deployment.
./stop.sh

cp .env.local .env

# Start root & child chain.
npx hardhat node --config ./rootchain.config.ts --port 8500 > /dev/null 2>&1 &
npx hardhat node --config ./childchain.config.ts --port 8501 > /dev/null 2>&1 &
sleep 10

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    ./stop.sh
}

# Setup root & child chain.
npx hardhat run ./rootchain_setup.ts --config ./rootchain.config.ts --network localhost
npx hardhat run ./childchain_setup.ts --config ./childchain.config.ts --network localhost

echo "Successfully setup root chain and child chain..."

if [ -z ${LOCAL_CHAIN_ONLY+x} ]; then
    # Pre validation
    SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/0_pre_validation.ts 2>&1 | tee bootstrap.out

    # Fund accounts
    SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/1_deployer_funding.ts 2>&1 | tee -a bootstrap.out
    echo "Successfully run 1_deployer_funding.ts..."

    # Setup axelar
    npx ts-node axelar_setup.ts

    ./stop.sh
fi