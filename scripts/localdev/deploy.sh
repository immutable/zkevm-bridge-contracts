#!/bin/bash

# Verify deployment
SKIP_WAIT_FOR_CONFIRMATION=true SKIP_MULTISIG_CHECK=true node ../bootstrap/2_deployment_validation.js

# Deploy child contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/3_child_deployment.js

# Deploy root contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/4_root_deployment.js

# Initialise child contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/5_child_initialisation.js

# IMX Burning
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/6_imx_burning.js

# IMX Rebalancing
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/7_imx_rebalancing.js

# Initialise root contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap/8_root_initialisation.js