'use strict';
const { ethers: hardhat } = require("hardhat");
const helper = require("./helpers.js");
const { ethers, ContractFactory } = require("ethers");
const fs = require('fs');
require('dotenv').config();

async function main() {
    let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
    let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
    let rootDeployerKey = helper.requireEnv("ROOT_DEPLOYER_SECRET");
    let axelarDeployerKey = helper.requireEnv("AXELAR_ROOT_EOA_SECRET");

    // Get root provider.
    let rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));

    // Get deployer wallet on the root chain.
    let rootDeployer = new ethers.Wallet(rootDeployerKey, rootProvider);

    // Get axelar wallet on the root chain.
    let axelarDeployer = new ethers.Wallet(axelarDeployerKey, rootProvider);
    
    // Generate a key to deploy IMX contract and fund ROOT_DEPLOYER.
    let admin = ethers.Wallet.createRandom().connect(rootProvider);

    // Give admin account 10000 ETH.
    await hardhat.provider.send("hardhat_setBalance", [
        admin.address,
        "0x21E19E0C9BAB2400000",
    ]);

    // Deploy IMX contract
    let IMXObj = JSON.parse(fs.readFileSync('../out/ERC20PresetMinterPauser.sol/ERC20PresetMinterPauser.json', 'utf8'));
    console.log("Deploy IMX contract on root chain...");

    let factory = new ContractFactory(IMXObj.abi, IMXObj.bytecode, admin);
    let IMX = await factory.deploy("Immutable X", "IMX");
    let txn = IMX.deployTransaction;
    await helper.waitForReceipt(txn.hash, rootProvider);

    // Mint 1100 IMX to root deployer
    let resp = await IMX.connect(admin).mint(rootDeployer.address, ethers.utils.parseEther("1100.0"));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // Transfer 0.1 ETH to root deployer
    resp = await admin.sendTransaction({
        to: rootDeployer.address,
        value: ethers.utils.parseEther("0.1"),
    })
    await helper.waitForReceipt(resp.hash, rootProvider);

    // Transfer 500 ETH to axelar deployer
    resp = await admin.sendTransaction({
        to: axelarDeployer.address,
        value: ethers.utils.parseEther("500.0"),
    })

    console.log("Root deployer now has " + ethers.utils.formatEther(await IMX.balanceOf(rootDeployer.address)) + " IMX.");
    console.log("Root deployer now has " + ethers.utils.formatEther(await rootProvider.getBalance(rootDeployer.address)) + " ETH.");
    console.log("Root axelar now has " + ethers.utils.formatEther(await rootProvider.getBalance(axelarDeployer.address)) + " ETH.");

    console.log("Finished setting up on root chain.");
}
main();