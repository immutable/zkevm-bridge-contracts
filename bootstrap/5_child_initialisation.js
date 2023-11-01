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
    let childBridgeAddr = requireEnv("CHILD_BRIDGE_ADDRESS");
    let childAdapterAddr = requireEnv("CHILD_ADAPTER_ADDRESS");
    let childTemplateAddr = requireEnv("CHILD_TOKEN_TEMPLATE");
    let rootAdapterAddr = requireEnv("ROOT_ADAPTER_ADDRESS");
    let imxRootAddr = requireEnv("IMX_ROOT_ADDR");

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
    let childBridgeContractObj = JSON.parse(fs.readFileSync('../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    let adapterContractObj = JSON.parse(fs.readFileSync('../out/ChildAxelarBridgeAdaptor.sol/ChildAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Initialise child contracts in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    let feeData = await adminWallet.getFeeData();
    let baseFee = feeData.lastBaseFeePerGas;
    let gasPrice = feeData.gasPrice;
    let priorityFee = Math.round(gasPrice * 150 / 100);
    let maxFee = Math.round(1.13 * baseFee + priorityFee);
    const childBridge = new ethers.Contract(childBridgeAddr, childBridgeContractObj.abi, childProvider);
    let resp = await childBridge.connect(adminWallet).initialize(childAdapterAddr, rootAdapterAddr, childTemplateAddr, rootChainName, imxRootAddr, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });

    let receipt;
    while (receipt == null) {
        receipt = await rootProvider.getTransactionReceipt(resp.hash)
        await delay(1000);
    }
    console.log(receipt);

    feeData = await adminWallet.getFeeData();
    baseFee = feeData.lastBaseFeePerGas;
    gasPrice = feeData.gasPrice;
    priorityFee = Math.round(gasPrice * 150 / 100);
    maxFee = Math.round(1.13 * baseFee + priorityFee);
    const childAdapter = new ethers.Contract(childAdapterAddr, adapterContractObj.abi, childProvider);
    resp = await childAdapter.connect(adminWallet).setRootBridgeAdaptor({
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });

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