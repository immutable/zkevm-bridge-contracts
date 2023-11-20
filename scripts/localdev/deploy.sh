#!/bin/bash

# Verify deployment
SKIP_WAIT_FOR_CONFIRMATION=true SKIP_MULTISIG_CHECK=true node ../bootstrap2/2_deployment_validation.js

# Deploy child contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap2/3_child_deployment.js

# Deploy root contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap2/4_root_deployment.js

# Initialise child contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap2/5_child_initialisation.js

# IMX Burning
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap2/6_imx_burning.js

# IMX Rebalancing
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap2/7_imx_rebalancing.js

# Initialise root contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap2/8_root_initialisation.js