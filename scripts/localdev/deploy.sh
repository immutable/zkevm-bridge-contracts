#!/bin/bash

# Verify deployment
SKIP_WAIT_FOR_CONFIRMATION=true SKIP_MULTISIG_CHECK=true node ../bootstrap2/2_deployment_validation.js

# Deploy child contracts
SKIP_WAIT_FOR_CONFIRMATION=true node ../bootstrap2/3_child_deployment.js