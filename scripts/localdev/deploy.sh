#!/bin/bash
set -ex
set -o pipefail

# Verify deployment
SKIP_WAIT_FOR_CONFIRMATION=true SKIP_MULTISIG_CHECK=true npx ts-node ../bootstrap/2_deployment_validation.ts 2>&1 | tee -a bootstrap.out

# Deploy child contracts
SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/3_child_deployment.ts 2>&1 | tee -a bootstrap.out

# Deploy root contracts
SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/4_root_deployment.ts 2>&1 | tee -a bootstrap.out

# Initialise child contracts
SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/5_child_initialisation.ts 2>&1 | tee -a bootstrap.out

# IMX Burning
SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/6_imx_burning.ts 2>&1 | tee -a bootstrap.out

# IMX Rebalancing
SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/7_imx_rebalancing.ts 2>&1 | tee -a bootstrap.out

# Initialise root contracts
SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/8_root_initialisation.ts 2>&1 | tee -a bootstrap.out

# Prepare for test
SKIP_WAIT_FOR_CONFIRMATION=true npx ts-node ../bootstrap/9_test_preparation.ts 2>&1 | tee -a bootstrap.out