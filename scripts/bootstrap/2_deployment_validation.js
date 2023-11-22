// Deployment validation
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");

async function run() {
    console.log("=======Start Deployment Validation=======");

    // Check environment variables
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
    let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
    let childGatewayAddr = helper.requireEnv("CHILD_GATEWAY_ADDRESS");
    let childGasServiceAddr = helper.requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let multisigAddr = helper.requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootGatewayAddr = helper.requireEnv("ROOT_GATEWAY_ADDRESS");
    let rootGasService = helper.requireEnv("ROOT_GAS_SERVICE_ADDRESS");

    // Check duplicates
    if (helper.hasDuplicates([childGatewayAddr, childGasServiceAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }
    if (helper.hasDuplicates([rootGatewayAddr, rootGasService])) {
        throw("Duplicate address detected!");
    }

    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));

    // Check child chain.
    console.log("Check contracts on child chain...");
    console.log("Check gateway contract...")
    await helper.requireNonEmptyCode(childProvider, childGatewayAddr);
    console.log("Succeed.");
    console.log("Check gas service contract...")
    await helper.requireNonEmptyCode(childProvider, childGasServiceAddr);
    console.log("Succeed.");
    if (process.env["SKIP_MULTISIG_CHECK"] != null) {
        console.log("Skip multisig contract check...");
    } else {
        console.log("Check multisig contract...");
        await helper.requireNonEmptyCode(childProvider, multisigAddr);
        console.log("Succeed.");
    }

    // Check root chain.
    console.log("Check contracts on root chain...");
    console.log("Check gateway contract...");
    await helper.requireNonEmptyCode(rootProvider, rootGatewayAddr);
    console.log("Succeed.");
    console.log("Check gas service contract...");
    await helper.requireNonEmptyCode(rootProvider, rootGasService);
    console.log("Succeed.");

    console.log("=======End Deployment Validation=======");
}

run();