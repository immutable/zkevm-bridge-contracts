// Initialise child contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const fs = require('fs');

async function run() {
    let rootChainName = requireEnv("ROOT_CHAIN_NAME");
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let childGasServiceAddr = requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let childBridgeAddr = requireEnv("CHILD_BRIDGE_ADDRESS");
    let childAdaptorAddr = requireEnv("CHILD_ADAPTOR_ADDRESS");
    let childTemplateAddr = requireEnv("CHILD_TOKEN_TEMPLATE");
    let rootAdaptorAddr = requireEnv("ROOT_ADAPTOR_ADDRESS");
    let imxRootAddr = requireEnv("IMX_ROOT_ADDR");
    let wimxChildAddr = requireEnv("WRAPPED_IMX_ADDRESS");

    // Get admin address
    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let adminWallet;
    if (adminEOASecret == "ledger") {
        adminWallet = new LedgerSigner(childProvider);
    } else {
        adminWallet = new ethers.Wallet(adminEOASecret, childProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Admin address is: ", adminAddr);

    // Execute
    console.log("Initialise child contracts in...");
    await wait();

    // Initialise child bridge
    let childBridgeObj = JSON.parse(fs.readFileSync('../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    console.log("Initialise child bridge...");
    let childBridge = new ethers.Contract(childBridgeAddr, childBridgeObj.abi, childProvider);
    let [priorityFee, maxFee] = await getFee(adminWallet);
    let resp = await childBridge.connect(adminWallet).initialize(childAdaptorAddr, ethers.utils.getAddress(rootAdaptorAddr), childTemplateAddr, rootChainName, imxRootAddr, wimxChildAddr, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await waitForReceipt(resp.hash, childProvider);

    // Initialise child adaptor
    let childAdaptorObj = JSON.parse(fs.readFileSync('../out/ChildAxelarBridgeAdaptor.sol/ChildAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Initialise child adaptor...");
    let childAdaptor = new ethers.Contract(childAdaptorAddr, childAdaptorObj.abi, childProvider);
    [priorityFee, maxFee] = await getFee(adminWallet);
    resp = await childAdaptor.connect(adminWallet).initialize(rootChainName, childBridgeAddr, childGasServiceAddr, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await waitForReceipt(resp.hash, childProvider);
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

async function getFee(adminWallet) {
    let feeData = await adminWallet.getFeeData();
    let baseFee = feeData.lastBaseFeePerGas;
    let gasPrice = feeData.gasPrice;
    let priorityFee = Math.round(gasPrice * 150 / 100);
    let maxFee = Math.round(1.13 * baseFee + priorityFee);
    return [priorityFee, maxFee];
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