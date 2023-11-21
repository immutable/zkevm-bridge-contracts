#!/bin/bash
set -x

# Try at most 300 seconds
counter=1
while [ $counter -le 300 ]
do
    echo "Waiting for chain and axelar setup... ${counter}"
    SKIP_WAIT_FOR_CONFIRMATION=true SKIP_MULTISIG_CHECK=true node ../bootstrap/2_deployment_validation.js > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        sleep 1
        ((counter++))
        continue
    fi
    break
done

./deploy.sh
npx mocha --require mocha-suppress-logs ../e2e/
./stop.sh