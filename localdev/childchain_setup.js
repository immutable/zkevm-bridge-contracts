'use strict';
const { ethers: hardhat } = require("hardhat");
const helper = require("./helpers.js");
require('dotenv').config();

async function main() {
    // Get admin EOA on the child chain.
    let childEOAKey = helper.requireEnv("CHILD_ADMIN_EOA_SECRET");
    let childEOA = new ethers.Wallet(childEOAKey);

    // Give admin EOA account 2B IMX.
    await ethers.provider.send("hardhat_setBalance", [
        childEOA.address,
        "0x6765c793fa10079d0000000",
    ]);

    console.log("Child admin EOA now has " + ethers.formatEther(await hardhat.provider.getBalance(childEOA.address)) + " IMX.");
}
main();