// IMX burning
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");

// Transfer 200 million IMX to child bridge
const TRANSFER_TO_CHILD_BRIDGE = "200000000";

async function run() {
    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let childBridgeAddr = requireEnv("CHILD_BRIDGE_ADDRESS");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");

    // Check duplicates
    if (hasDuplicates([adminAddr, childBridgeAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }

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
    let adminBal = await childProvider.getBalance(adminAddr);
    let bridgeBal = await childProvider.getBalance(childBridgeAddr);
    let multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));
    console.log("Burn IMX in...");
    await wait();

    // Transfer to child bridge
    console.log("Transfer 200m to child bridge...");
    let [priorityFee, maxFee] = await getFee(adminWallet);
    let resp = await adminWallet.sendTransaction({
        to: childBridgeAddr,
        value: ethers.utils.parseEther(TRANSFER_TO_CHILD_BRIDGE),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await waitForReceipt(resp.hash, childProvider);
    adminBal = await childProvider.getBalance(adminAddr);
    bridgeBal = await childProvider.getBalance(childBridgeAddr);
    multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    // Transfer to multisig
    console.log("Transfer remaining to multisig...");
    [priorityFee, maxFee] = await getFee(adminWallet);
    resp = await adminWallet.sendTransaction({
        to: multisigAddr,
        value: adminBal.sub(ethers.utils.parseEther("0.01")),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await waitForReceipt(resp.hash, childProvider);
    adminBal = await childProvider.getBalance(adminAddr);
    bridgeBal = await childProvider.getBalance(childBridgeAddr);
    multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));
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

function hasDuplicates(array) {
    return (new Set(array)).size !== array.length;
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