// Initialise root contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const fs = require('fs');

async function run() {
    // Check environment variables
    let childChainName = requireEnv("CHILD_CHAIN_NAME");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let rootGasServiceAddr = requireEnv("ROOT_GAS_SERVICE_ADDRESS");
    let rootBridgeAddr = requireEnv("ROOT_BRIDGE_ADDRESS");
    let rootAdaptorAddr = requireEnv("ROOT_ADAPTOR_ADDRESS");
    let rootTemplateAddr = requireEnv("ROOT_TOKEN_TEMPLATE");
    let childBridgeAddr = requireEnv("CHILD_BRIDGE_ADDRESS");
    let childAdaptorAddr = requireEnv("CHILD_ADAPTOR_ADDRESS");
    let imxRootAddr = requireEnv("IMX_ROOT_ADDR");
    let wethRootAddr = requireEnv("WETH_ROOT_ADDR");
    let imxDepositLimit = requireEnv("IMX_DEPOSIT_LIMIT");

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
    console.log("Initialise root contracts in...");
    await wait();

    // Initialise root bridge
    let rootBridgeObj = JSON.parse(fs.readFileSync('../out/RootERC20Bridge.sol/RootERC20Bridge.json', 'utf8'));
    console.log("Initialise root bridge...");
    let rootBridge = new ethers.Contract(rootBridgeAddr, rootBridgeObj.abi, rootProvider);
    let resp = await rootBridge.connect(adminWallet).initialize(rootAdaptorAddr, childBridgeAddr, ethers.utils.getAddress(childAdaptorAddr), rootTemplateAddr, imxRootAddr, wethRootAddr, childChainName, ethers.utils.parseEther(imxDepositLimit));
    await waitForReceipt(resp.hash, rootProvider);

    // Initialise root adaptor
    let rootAdaptorObj = JSON.parse(fs.readFileSync('../out/RootAxelarBridgeAdaptor.sol/RootAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Initialise root adaptor...");
    let rootAdaptor = new ethers.Contract(rootAdaptorAddr, rootAdaptorObj.abi, rootProvider);
    resp = await rootAdaptor.connect(adminWallet).initialize(rootBridgeAddr, childChainName, rootGasServiceAddr);
    await waitForReceipt(resp.hash, rootProvider);
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

async function wait() {
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
}

async function waitForReceipt(txHash, provider) {
    let receipt;
    while (receipt == null) {
        receipt = await provider.getTransactionReceipt(txHash)
        await delay(1000);
    }
    if (receipt.status != 1) {
        throw("Fail to execute");
    }
    console.log(receipt);
    console.log("Succeed.");
}