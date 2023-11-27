import * as dotenv from "dotenv";
dotenv.config();
import { ethers as hardhat } from "hardhat";
import { ethers } from "ethers";
import { requireEnv, deployRootContract, waitForReceipt } from "../helpers/helpers";
import * as fs from "fs";

async function main() {
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let rootAdminKey = requireEnv("ROOT_EOA_SECRET");
    let rootDeployerKey = requireEnv("ROOT_DEPLOYER_SECRET");
    let axelarDeployerKey = requireEnv("AXELAR_ROOT_EOA_SECRET");
    let rootTestKey = requireEnv("TEST_ACCOUNT_SECRET");
    let rootRateAdminKey = requireEnv("ROOT_BRIDGE_RATE_ADMIN_SECRET");

    // Get root provider.
    let rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));

    // Get deployer wallet on the root chain.
    let rootDeployer = new ethers.Wallet(rootDeployerKey, rootProvider);

    // Get axelar wallet on the root chain.
    let axelarDeployer = new ethers.Wallet(axelarDeployerKey, rootProvider);

    // Get test wwallet on the root chain.
    let testWallet = new ethers.Wallet(rootTestKey, rootProvider);

    // Get rate admin wallet on the root chain.
    let rateAdminWallet = new ethers.Wallet(rootRateAdminKey, rootProvider);
    
    // Get root admin eoa wallet.
    let admin = new ethers.Wallet(rootAdminKey, rootProvider);

    // Give admin account 10000 ETH.
    await hardhat.provider.send("hardhat_setBalance", [
        admin.address,
        "0x21E19E0C9BAB2400000",
    ]);

    // Deploy IMX contract
    console.log("Deploy IMX contract on root chain...");
    let IMX = await deployRootContract("ERC20PresetMinterPauser", admin, "IMX Token", "IMX");
    await waitForReceipt(IMX.deployTransaction.hash, rootProvider);
    console.log("IMX deployed at: " + IMX.address);

    // Deploy WETH contract
    console.log("Deploy WETH contract on root chain...");
    let WETH = await deployRootContract("WETH", admin);
    await waitForReceipt(WETH.deployTransaction.hash, rootProvider);
    console.log("WETH deployed at: " + WETH.address);

    // Mint 1100 IMX to root deployer
    let resp = await IMX.connect(admin).mint(rootDeployer.address, ethers.utils.parseEther("1100.0"));
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 1000 IMX to test wallet
    resp = await IMX.connect(admin).mint(testWallet.address, ethers.utils.parseEther("1000.0"))
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 0.1 ETH to root deployer
    resp = await admin.sendTransaction({
        to: rootDeployer.address,
        value: ethers.utils.parseEther("0.1"),
    })
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 500 ETH to axelar deployer
    resp = await admin.sendTransaction({
        to: axelarDeployer.address,
        value: ethers.utils.parseEther("500.0"),
    })

    // Transfer 10 ETH to test wallet
    resp = await admin.sendTransaction({
        to: testWallet.address,
        value: ethers.utils.parseEther("10.0"),
    })
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 0.1 ETH to rate admin
    resp = await admin.sendTransaction({
        to: rateAdminWallet.address,
        value: ethers.utils.parseEther("10.0"),
    })
    await waitForReceipt(resp.hash, rootProvider);

    console.log("Root deployer now has " + ethers.utils.formatEther(await IMX.balanceOf(rootDeployer.address)) + " IMX.");
    console.log("Root deployer now has " + ethers.utils.formatEther(await rootProvider.getBalance(rootDeployer.address)) + " ETH.");
    console.log("Root axelar now has " + ethers.utils.formatEther(await rootProvider.getBalance(axelarDeployer.address)) + " ETH.");

    console.log("Finished setting up on root chain.");
    let contractData = {
        IMX_ROOT_ADDR: IMX.address,
        WETH_ROOT_ADDR: WETH.address,
    };
    fs.writeFileSync(".root.contracts.json", JSON.stringify(contractData, null, 2));
}
main();