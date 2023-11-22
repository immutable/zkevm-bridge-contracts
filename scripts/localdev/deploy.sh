#!/bin/bash

# Verify deployment
SKIP_WAIT_FOR_CONFIRMATION=true SKIP_MULTISIG_CHECK=true node ../bootstrap/2_deployment_validation.js 2>&1 | tee -a bootstrap.out
if [ $? -ne 0 ]; then
    exit 1;
fi

# Deploy child contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/3_child_deployment.js 2>&1 | tee -a bootstrap.out
if [ $? -ne 0 ]; then
    exit 1;
fi

# Deploy root contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/4_root_deployment.js 2>&1 | tee -a bootstrap.out
if [ $? -ne 0 ]; then
    exit 1;
fi

# Initialise child contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/5_child_initialisation.js 2>&1 | tee -a bootstrap.out
if [ $? -ne 0 ]; then
    exit 1;
fi

# IMX Burning
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/6_imx_burning.js 2>&1 | tee -a bootstrap.out
if [ $? -ne 0 ]; then
    exit 1;
fi

# IMX Rebalancing
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/7_imx_rebalancing.js 2>&1 | tee -a bootstrap.out
if [ $? -ne 0 ]; then
    exit 1;
fi

# Initialise root contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/8_root_initialisation.js 2>&1 | tee -a bootstrap.out
if [ $? -ne 0 ]; then
    exit 1;
fi