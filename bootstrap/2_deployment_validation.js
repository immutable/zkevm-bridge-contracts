// Deployment validation
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");

async function run() {
    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID =requireEnv("CHILD_CHAIN_ID");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let childGatewayAddr = requireEnv("CHILD_GATEWAY_ADDRESS");
    let childGasServiceAddr = requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootGatewayAddr = requireEnv("ROOT_GATEWAY_ADDRESS");
    let rootGasService = requireEnv("ROOT_GAS_SERVICE_ADDRESS");

    // Check duplicates
    if (hasDuplicates([childGatewayAddr, childGasServiceAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }
    if (hasDuplicates([rootGatewayAddr, rootGasService])) {
        throw("Duplicate address detected!");
    }

    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));

    // Check child chain.
    console.log("Check contracts on child chain...");
    await requireNonEmptyCode(childProvider, childGatewayAddr);
    await requireNonEmptyCode(childProvider, childGasServiceAddr);
    await requireNonEmptyCode(childProvider, multisigAddr);

    // Check root chain.
    console.log("Check contracts on root chain...");
    await requireNonEmptyCode(rootProvider, rootGatewayAddr);
    await requireNonEmptyCode(rootProvider, rootGasService);
}

run();

// Helper functions
function requireEnv(envName) {
    let val = process.env[envName];
    if (val == null || val == "") {
        throw(envName + " not set!");
    }
    console.log(envName + " is set to be: ", val);
    return val;
}

async function requireNonEmptyCode(provider, addr) {
    if (await provider.getCode(addr) == "0x") {
        throw(addr + " has empty code!");
    }
    console.log(addr + " has code.");
}

function hasDuplicates(array) {
    return (new Set(array)).size !== array.length;
}