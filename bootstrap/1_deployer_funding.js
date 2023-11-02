// Deployer funding
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')

async function run() {
    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let axelarEOA = requireEnv("AXELAR_EOA");
    let axelarFund = requireEnv("AXELAR_FUND");

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

    // Check duplicates
    if (hasDuplicates([adminAddr, axelarEOA])) {
        throw("Duplicate address detected!");
    }
    
    // Execute
    console.log("Fund deployer in...");
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
    let feeData = await adminWallet.getFeeData();
    let baseFee = feeData.lastBaseFeePerGas;
    let gasPrice = feeData.gasPrice;
    let priorityFee = Math.round(gasPrice * 150 / 100);
    let maxFee = Math.round(1.13 * baseFee + priorityFee);

    let txn = {
        to: axelarEOA,
        value: ethers.utils.parseEther(axelarFund),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    }
    let resp = await adminWallet.sendTransaction(txn)

    let receipt;
    while (receipt == null) {
        receipt = await childProvider.getTransactionReceipt(resp.hash)
        await delay(1000);
    }
    console.log(receipt);

    // Check target balance
    let balance = await childProvider.getBalance(axelarEOA)
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(balance));
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