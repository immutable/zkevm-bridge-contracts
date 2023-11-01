// Initialise root contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const fs = require('fs');

async function run() {
    // Check environment variables
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let rootBridgeAddr = requireEnv("ROOT_BRIDGE_ADDRESS");
    let rootAdapterAddr = requireEnv("ROOT_ADAPTER_ADDRESS");
    let rootTemplateAddr = requireEnv("ROOT_TOKEN_TEMPLATE");
    let childBridgeAddr = requireEnv("CHILD_BRIDGE_ADDRESS");
    let childAdapterAddr = requireEnv("CHILD_ADAPTER_ADDRESS");
    let imxRootAddr = requireEnv("IMX_ROOT_ADDR");
    let wethRootAddr = requireEnv("WETH_ROOT_ADDR");

    // Get admin address
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let adminWallet;
    if (adminEOASecret == "ledger") {
        adminWallet = new LedgerSigner(rootProvider);
    } else {
        adminWallet = new ethers.Wallet(adminEOASecret, rootProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Admin address is: ", adminAddr);

    // Execute
    let rootBridgeContractObj = JSON.parse(fs.readFileSync('../out/RootERC20Bridge.sol/RootERC20Bridge.json', 'utf8'));
    let adapterContractObj = JSON.parse(fs.readFileSync('../out/RootAxelarBridgeAdaptor.sol/RootAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Initialise root contracts in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }

    const rootBridge = new ethers.Contract(rootBridgeAddr, rootBridgeContractObj.abi, rootProvider);
    let resp = await rootBridge.connect(adminWallet).initialize(rootAdapterAddr, childBridgeAddr, ethers.utils.getAddress(childAdapterAddr), rootTemplateAddr, imxRootAddr, wethRootAddr);

    let receipt;
    while (receipt == null) {
        receipt = await rootProvider.getTransactionReceipt(resp.hash)
        await delay(1000);
    }
    console.log(receipt);

    const rootAdapter = new ethers.Contract(rootAdapterAddr, adapterContractObj.abi, rootProvider);
    resp = await rootAdapter.connect(adminWallet).setChildBridgeAdaptor();

    receipt = null;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(childTemplate.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
}

run();

// Helper functions
function requireEnv(envName) {
    let val = process.env[envName];
    if (val == null || val == "") {
        throw(envName + " not set!");
    }
    if (!envName.includes("SECRET")) {
        console.log(envName + ": ", val);
    }
    return val
}

function delay(time) {
    return new Promise(resolve => setTimeout(resolve, time));
}