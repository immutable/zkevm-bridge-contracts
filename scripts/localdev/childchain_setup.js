'use strict';
const { ethers: hardhat } = require("hardhat");
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
require('dotenv').config();

async function main() {
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let childEOAKey = helper.requireEnv("CHILD_ADMIN_EOA_SECRET");

    // Get child provider.
    let childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));

    // Get admin EOA on the child chain.
    let childEOA = new ethers.Wallet(childEOAKey);

    // Give admin EOA account 2B IMX.
    await hardhat.provider.send("hardhat_setBalance", [
        childEOA.address,
        "0x6765c793fa10079d0000000",
    ]);

    console.log("Child admin EOA now has " + ethers.utils.formatEther(await childProvider.getBalance(childEOA.address)) + " IMX.");
    console.log("Finished setting up on child chain.")
}
main();