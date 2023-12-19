import * as dotenv from "dotenv";
dotenv.config();
import { ethers as hardhat } from "hardhat";
import { ethers } from "ethers";
import { requireEnv, deployRootContract, waitForReceipt, saveRootContracts } from "../helpers/helpers";
import * as fs from "fs";
import { RetryProvider } from "../helpers/retry";

async function main() {
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let rootAdminKey = requireEnv("ROOT_EOA_SECRET");
    let deployerAddr = requireEnv("DEPLOYER_ADDR");
    let reservedAddr = requireEnv("NONCE_RESERVED_DEPLOYER_ADDR");
    let axelarEOA = requireEnv("AXELAR_EOA");
    let rootTestKey = requireEnv("TEST_ACCOUNT_SECRET");

    // Get root provider.
    let rootProvider = new RetryProvider(rootRPCURL, Number(rootChainID));

    // Get test wwallet on the root chain.
    let testWallet = new ethers.Wallet(rootTestKey, rootProvider);
    
    // Get root admin eoa wallet.
    let admin = new ethers.Wallet(rootAdminKey, rootProvider);

    // Give admin account 10000 ETH.
    await hardhat.provider.send("hardhat_setBalance", [
        admin.address,
        "0x21E19E0C9BAB2400000",
    ]);

    // Deploy IMX contract
    console.log("Deploy IMX contract on root chain...");
    let IMX = await deployRootContract("ERC20PresetMinterPauser", admin, null, "IMX Token", "IMX");
    await waitForReceipt(IMX.deployTransaction.hash, rootProvider);
    console.log("IMX deployed at: " + IMX.address);

    // Deploy WETH contract
    console.log("Deploy WETH contract on root chain...");
    let WETH = await deployRootContract("WETH", admin, null);
    await waitForReceipt(WETH.deployTransaction.hash, rootProvider);
    console.log("WETH deployed at: " + WETH.address);

    // Mint 1110 IMX to root deployer
    let resp = await IMX.connect(admin).mint(deployerAddr, ethers.utils.parseEther("1110.0"));
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 1000 IMX to test wallet
    resp = await IMX.connect(admin).mint(testWallet.address, ethers.utils.parseEther("1000.0"))
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 0.1 ETH to root deployer
    resp = await admin.sendTransaction({
        to: deployerAddr,
        value: ethers.utils.parseEther("0.1"),
    })
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 0.1 ETH to nonce reserved root deployer
    resp = await admin.sendTransaction({
        to: reservedAddr,
        value: ethers.utils.parseEther("0.1"),
    })
    await waitForReceipt(resp.hash, rootProvider);

    // Transfer 500 ETH to axelar deployer
    resp = await admin.sendTransaction({
        to: axelarEOA,
        value: ethers.utils.parseEther("500.0"),
    })

    // Transfer 10 ETH to test wallet
    resp = await admin.sendTransaction({
        to: testWallet.address,
        value: ethers.utils.parseEther("10.0"),
    })
    await waitForReceipt(resp.hash, rootProvider);

    console.log("Root deployer now has " + ethers.utils.formatEther(await IMX.balanceOf(deployerAddr)) + " IMX.");
    console.log("Root deployer now has " + ethers.utils.formatEther(await rootProvider.getBalance(deployerAddr)) + " ETH.");
    console.log("Root axelar now has " + ethers.utils.formatEther(await rootProvider.getBalance(axelarEOA)) + " ETH.");

    console.log("Finished setting up on root chain.");
    let contractData = {
        IMX_ROOT_ADDR: IMX.address,
        WETH_ROOT_ADDR: WETH.address,
    };
    fs.writeFileSync(".root.contracts.json", JSON.stringify(contractData, null, 2));
}
main();