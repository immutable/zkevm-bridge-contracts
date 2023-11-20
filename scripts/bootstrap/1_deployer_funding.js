// Deployer funding
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')

async function run() {
    // Check environment variables
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = helper.requireEnv("CHILD_ADMIN_EOA_SECRET");
    let axelarEOA = helper.requireEnv("AXELAR_EOA");
    let axelarFund = helper.requireEnv("AXELAR_FUND");
    let deployerEOA = helper.requireEnv("CHILD_DEPLOYER_ADDR");
    let deployerFund = helper.requireEnv("CHILD_DEPLOYER_FUND");

    // Get admin EOA address
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
    if (helper.hasDuplicates([adminAddr, axelarEOA, deployerEOA])) {
        throw("Duplicate address detected!");
    }

    // Execute
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));
    console.log("Deployer EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(deployerEOA)));
    console.log("Fund Axelar and deployer on child chain in...");
    await helper.waitForConfirmation();

    let [priorityFee, maxFee] = await helper.getFee(adminWallet);
    let resp = await adminWallet.sendTransaction({
        to: axelarEOA,
        value: ethers.utils.parseEther(axelarFund),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    })
    await helper.waitForReceipt(resp.hash, childProvider);

    [priorityFee, maxFee] = await helper.getFee(adminWallet);
    resp = await adminWallet.sendTransaction({
        to: deployerEOA,
        value: ethers.utils.parseEther(deployerFund),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    })
    await helper.waitForReceipt(resp.hash, childProvider);

    // Print target balance
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));
    console.log("Deployer EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(deployerEOA)));
}
run();