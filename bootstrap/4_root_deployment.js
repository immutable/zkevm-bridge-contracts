// Deploy root contracts
'use strict';
require('dotenv').config();
const { ethers, ContractFactory } = require("ethers");
const fs = require('fs');

async function run() {
    // Check environment variables
    let childChainName = requireEnv("CHILD_CHAIN_NAME");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let rootGatewayAddr = requireEnv("ROOT_GATEWAY_ADDRESS");
    let rootGasService = requireEnv("ROOT_GAS_SERVICE_ADDRESS");

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
    console.log("Deploy root bridge contract in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    let factory = new ContractFactory(rootBridgeContractObj.abi, rootBridgeContractObj.bytecode, adminWallet);

    let rootBridge = await factory.deploy();

    let receipt;
    while (receipt == null) {
        receipt = await rootProvider.getTransactionReceipt(rootBridge.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
    console.log("Deployed to ROOT_BRIDGE_ADDRESS: ", rootBridge.address);

    let adapterContractObj = JSON.parse(fs.readFileSync('../out/RootAxelarBridgeAdaptor.sol/RootAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Deploy root adapter contract in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    factory = new ContractFactory(adapterContractObj.abi, adapterContractObj.bytecode, adminWallet);

    let rootAdapter = await factory.deploy(rootBridge.address, childChainName, rootGatewayAddr, rootGasService);

    receipt = null;
    while (receipt == null) {
        receipt = await rootProvider.getTransactionReceipt(rootAdapter.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
    console.log("Deployed to ROOT_ADAPTER_ADDRESS: ", rootAdapter.address);

    let templateContractObj = JSON.parse(fs.readFileSync('../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
    console.log("Deploy root template contract in...")
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    factory = new ContractFactory(templateContractObj.abi, templateContractObj.bytecode, adminWallet);

    let rootTemplate = await factory.deploy();

    receipt = null;
    while (receipt == null) {
        receipt = await rootProvider.getTransactionReceipt(rootTemplate.deployTransaction.hash)
        await delay(1000);
    }
    console.log(receipt);
    console.log("Deployed to ROOT_TOKEN_TEMPLATE: ", rootTemplate.address);

    let resp = await rootTemplate.initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18);
    receipt = null;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(resp.hash)
        await delay(1000);
    }
    console.log(receipt);

    fs.writeFileSync("./4.out.tmp", "ROOT_BRIDGE_ADDRESS:" + rootBridge.address + "\n" + "ROOT_ADAPTER_ADDRESS:" + rootAdapter.address + "\n" + "ROOT_TOKEN_TEMPLATE:" + rootTemplate.address);
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