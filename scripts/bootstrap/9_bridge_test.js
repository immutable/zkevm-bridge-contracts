// Test bridge contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const { AxelarAssetTransfer, AxelarQueryAPI, CHAINS, Environment } = require('@axelar-network/axelarjs-sdk');
const fs = require('fs');

async function run() {
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let rootEOASecret = requireEnv("ROOT_TEST_ACCOUNT_KEY");
    let childEOASecret = requireEnv("CHILD_TEST_ACCOUNT_KEY");
    let rootBridgeAddr = requireEnv("ROOT_BRIDGE_ADDRESS");
    let childBridgeAddr = requireEnv("CHILD_BRIDGE_ADDRESS");

    // Query Axelar for gas fee from L1 to L2.
    // const sdk = new AxelarQueryAPI({
    //     environment: "testnet",
    // });
    // console.log(await sdk.getActiveChains()), not working!!!
    // console.log(await sdk.getGasInfo("ethereum-sepolia", "immutable-devnet", "ETH"));

    // Load child briddge, check balance.
    // const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID)); 
    // let childWallet = new ethers.Wallet(childEOASecret, childProvider);
    // let childBridgeObj = JSON.parse(fs.readFileSync('../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    // let childBridge = new ethers.Contract(childBridgeAddr, childBridgeObj.abi, childProvider);

    // let childEthTokenAddr = await childBridge.childETHToken() // 0x16D2cb9ACD09578Cb60A297872821e329134d869
    // console.log(childEthTokenAddr);

    // let childTokenTemplateObj = JSON.parse(fs.readFileSync('../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
    // let childEthToken = new ethers.Contract(childEthTokenAddr, childTokenTemplateObj.abi, childProvider);
    // console.log(ethers.utils.formatEther(await childEthToken.balanceOf(childWallet.address)));


    // Load child bridge, withdraw ETH
    // const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID)); 
    // let childWallet = new ethers.Wallet(childEOASecret, childProvider);
    // let childBridgeObj = JSON.parse(fs.readFileSync('../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    // let childBridge = new ethers.Contract(childBridgeAddr, childBridgeObj.abi, childProvider);

    // let childEthTokenAddr = await childBridge.childETHToken() // 0x16D2cb9ACD09578Cb60A297872821e329134d869
    // console.log(childEthTokenAddr);

    // let [priorityFee, maxFee] = await getFee(childWallet);
    // let resp = await childBridge.connect(childWallet).withdrawETH(ethers.utils.parseEther("0.0005"), {
    //     value: ethers.utils.parseEther("2"),
    //     maxPriorityFeePerGas: priorityFee,
    //     maxFeePerGas: maxFee,
    // })
    // console.log(resp);
    // console.log(resp.hash);


    // Load root bridge, check balance
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let rootWallet = new ethers.Wallet(rootEOASecret, rootProvider);
    let rootBridgeObj = JSON.parse(fs.readFileSync('../out/RootERC20Bridge.sol/RootERC20Bridge.json', 'utf8'));
    let rootBridge = new ethers.Contract(rootBridgeAddr, rootBridgeObj.abi, rootProvider);
    console.log(ethers.utils.formatEther(await rootProvider.getBalance(rootWallet.address)));

    // Load root bridge, deposit
    // const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    // let rootWallet = new ethers.Wallet(rootEOASecret, rootProvider);
    // let rootBridgeObj = JSON.parse(fs.readFileSync('../out/RootERC20Bridge.sol/RootERC20Bridge.json', 'utf8'));
    // let rootBridge = new ethers.Contract(rootBridgeAddr, rootBridgeObj.abi, rootProvider);
    // let resp = await rootBridge.connect(rootWallet).depositETH(ethers.utils.parseEther("0.001"), {
    //     value: ethers.utils.parseEther("0.002"),
    // });
    // console.log(resp);
    // console.log(resp.hash);
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