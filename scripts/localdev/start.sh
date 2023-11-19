#!/bin/bash

# Stop previous deployment.
./stop.sh

mv .env.local .env

# Start root & child chain.
npx hardhat node --config ./rootchain.config.js --port 8500 > /dev/null 2>&1 &
npx hardhat node --config ./childchain.config.js --port 8501 > /dev/null 2>&1 &
sleep 3

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    ./stop.sh
}

# Setup root & child chain.
npx hardhat run ./rootchain_setup.js --config ./rootchain.config.js --network localhost
if [ $? -ne 0 ]; then
    ./stop.sh
    echo "Fail to setup rootchain..."
    exit 1
fi
npx hardhat run ./childchain_setup.js --config ./childchain.config.js --network localhost
if [ $? -ne 0 ]; then
    ./stop.sh
    echo "Fail to setup childchain..."
    exit 1
fi
echo "Successfully setup root chain and child chain..."

# Fund accounts
# TODO!

# Setup axelar
node axelar_setup.js

./stop.sh