// Deploy child contracts
'use strict';
require('dotenv').config();
const { ethers, ContractFactory } = require("ethers");
const fs = require('fs');

async function run() {
    // Check environment variables
    let rootChainName = requireEnv("ROOT_CHAIN_NAME");
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let childGatewayAddr = requireEnv("CHILD_GATEWAY_ADDRESS");
    let childGasServiceAddr = requireEnv("CHILD_GAS_SERVICE_ADDRESS");

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
    console.log("Deploy child bridge contract in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    let factory = new ContractFactory(childBridgeContractObj.abi, childBridgeContractObj.bytecode, adminWallet);
    
    let feeData = await adminWallet.getFeeData();
    let baseFee = feeData.lastBaseFeePerGas;
    let gasPrice = feeData.gasPrice;
    let priorityFee = Math.round(gasPrice * 150 / 100);
    let maxFee = Math.round(1.13 * baseFee + priorityFee);
    let childBridge = await factory.deploy({
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });

    let receipt;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(childBridge.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
    console.log("Deployed to CHILD_BRIDGE_ADDRESS: ", childBridge.address);

    let wIMXContractObj = JSON.parse(fs.readFileSync('../out/WIMX.sol/WIMX.json', 'utf8'));
    console.log("Deploy WIMX contract in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    factory = new ContractFactory(wIMXContractObj.abi, wIMXContractObj.bytecode, adminWallet);

    feeData = await adminWallet.getFeeData();
    baseFee = feeData.lastBaseFeePerGas;
    gasPrice = feeData.gasPrice;
    priorityFee = Math.round(gasPrice * 150 / 100);
    maxFee = Math.round(1.13 * baseFee + priorityFee);
    let WIMX = await factory.deploy({
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });

    receipt = null;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(WIMX.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
    console.log("Deployed to WRAPPED_IMX_ADDRESS: ", WIMX.address);

    let adapterContractObj = JSON.parse(fs.readFileSync('../out/ChildAxelarBridgeAdaptor.sol/ChildAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Deploy child adapter contract in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    factory = new ContractFactory(adapterContractObj.abi, adapterContractObj.bytecode, adminWallet);

    feeData = await adminWallet.getFeeData();
    baseFee = feeData.lastBaseFeePerGas;
    gasPrice = feeData.gasPrice;
    priorityFee = Math.round(gasPrice * 150 / 100);
    maxFee = Math.round(1.13 * baseFee + priorityFee);
    let childAdapter = await factory.deploy(childGatewayAddr, childBridge.address, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });

    receipt = null;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(childAdapter.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
    console.log("Deployed to CHILD_ADAPTER_ADDRESS: ", childAdapter.address);

    let templateContractObj = JSON.parse(fs.readFileSync('../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
    console.log("Deploy child template contract in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    factory = new ContractFactory(templateContractObj.abi, templateContractObj.bytecode, adminWallet);

    feeData = await adminWallet.getFeeData();
    baseFee = feeData.lastBaseFeePerGas;
    gasPrice = feeData.gasPrice;
    priorityFee = Math.round(gasPrice * 150 / 100);
    maxFee = Math.round(1.13 * baseFee + priorityFee);
    let childTemplate = await factory.deploy({
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });

    receipt = null;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(childTemplate.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
    console.log("Deployed to CHILD_TOKEN_TEMPLATE: ", childTemplate.address);

    feeData = await adminWallet.getFeeData();
    baseFee = feeData.lastBaseFeePerGas;
    gasPrice = feeData.gasPrice;
    priorityFee = Math.round(gasPrice * 150 / 100);
    maxFee = Math.round(1.13 * baseFee + priorityFee);
    let resp = await childTemplate.initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    receipt = null;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(resp.hash)
        await delay(1000);
    }
    console.log(receipt);


    fs.writeFileSync("./3.out.tmp", "CHILD_BRIDGE_ADDRESS:" + childBridge.address + "\n" + "WRAPPED_IMX_ADDRESS:" + WIMX.address + "\n" + "CHILD_ADAPTER_ADDRESS:" + childAdapter.address + "\n" + "CHILD_TOKEN_TEMPLATE:" + childTemplate.address);
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