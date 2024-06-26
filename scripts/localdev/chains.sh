#!/bin/bash
set -ex
set -o pipefail

# Stop previous deployment.
./stop.sh

# Start root & child chain.
npx hardhat node --config ./rootchain.config.ts --port 8500 > /dev/null 2>&1 &
sleep 10
