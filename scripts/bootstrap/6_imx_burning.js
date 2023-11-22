// IMX burning
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')
const fs = require('fs');

async function run() {
    // Check environment variables
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = helper.requireEnv("CHILD_ADMIN_EOA_SECRET");
    let multisigAddr = helper.requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let imxDepositLimit = helper.requireEnv("IMX_DEPOSIT_LIMIT");

    // Read from contract file.
    let data = fs.readFileSync(".child.bridge.contracts.json", 'utf-8');
    let childContracts = JSON.parse(data);
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;

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
    if (helper.hasDuplicates([adminAddr, childBridgeAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }

    // Execute
    let adminBal = await childProvider.getBalance(adminAddr);
    let bridgeBal = await childProvider.getBalance(childBridgeAddr);
    let multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    if (adminBal.lt(ethers.utils.parseEther("0.01"))) {
        console.log("IMX Burning has already been done, skip.")
        return;
    }

    console.log("Burn IMX in...");
    await helper.waitForConfirmation();

    let childBridgeObj = JSON.parse(fs.readFileSync('../../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    let childBridge = new ethers.Contract(childBridgeAddr, childBridgeObj.abi, childProvider);

    console.log("Transfer " + imxDepositLimit +  " IMX to child bridge...");
    let [priorityFee, maxFee] = await helper.getFee(adminWallet);
    let resp = await childBridge.connect(adminWallet).treasuryDeposit({
        value: ethers.utils.parseEther(imxDepositLimit),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    })
    await helper.waitForReceipt(resp.hash, childProvider);
    adminBal = await childProvider.getBalance(adminAddr);
    bridgeBal = await childProvider.getBalance(childBridgeAddr);
    multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    // Transfer to multisig
    console.log("Transfer remaining to multisig...");
    [priorityFee, maxFee] = await helper.getFee(adminWallet);
    resp = await adminWallet.sendTransaction({
        to: multisigAddr,
        value: adminBal.sub(ethers.utils.parseEther("0.01")),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await helper.waitForReceipt(resp.hash, childProvider);
    adminBal = await childProvider.getBalance(adminAddr);
    bridgeBal = await childProvider.getBalance(childBridgeAddr);
    multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));
}
run();