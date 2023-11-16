'use strict';
const { ethers } = require("hardhat");
const helper = require("./helpers.js");
const { ContractFactory } = require("ethers");
const fs = require('fs');
require('dotenv').config();

async function main() {
    // Get deployer key on the root chain.
    let rootDeployerKey = helper.requireEnv("ROOT_DEPLOYER_SECRET");
    let rootDeployer = new ethers.Wallet(rootDeployerKey, ethers.provider);
    
    // Generate a key to deploy IMX contract and fund ROOT_DEPLOYER.
    let admin = ethers.Wallet.createRandom(ethers.provider);

    // Give admin account 10000 ETH.
    await ethers.provider.send("hardhat_setBalance", [
        admin.address,
        "0x21E19E0C9BAB2400000",
    ]);

    // Deploy IMX contract
    let IMXObj = JSON.parse(fs.readFileSync('../out/ERC20PresetMinterPauser.sol/ERC20PresetMinterPauser.json', 'utf8'));
    console.log("Deploy IMX contract on root chain...");

    let factory = new ContractFactory(IMXObj.abi, IMXObj.bytecode, admin);
    let IMX = await factory.deploy("Immutable X", "IMX");
    let txn = IMX.deploymentTransaction();
    await helper.waitForReceipt(txn.hash, ethers.provider);

    // Mint 1100 IMX to root deployer
    let resp = await IMX.connect(admin).mint(rootDeployer.address, ethers.parseEther("1100.0"));
    await helper.waitForReceipt(resp.hash, ethers.provider);

    // Transfer 0.1 ETH to root deployer
    resp = await admin.sendTransaction({
        to: rootDeployer.address,
        value: ethers.parseEther("0.1"),
    })
    await helper.waitForReceipt(resp.hash, ethers.provider);

    console.log("Root deployer now has " + ethers.formatEther(await IMX.balanceOf(rootDeployer.address)) + " IMX.");
    console.log("Root deployer now has " + ethers.formatEther(await ethers.provider.getBalance(rootDeployer.address)) + " ETH.");
}
main();