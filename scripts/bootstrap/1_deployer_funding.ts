// Deployer funding
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, waitForReceipt, getFee, hasDuplicates } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";

async function run() {
    console.log("=======Start Deployer Funding=======");

    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let reservedDeployerAddr = requireEnv("NONCE_RESERVED_DEPLOYER_ADDR");
    let reservedDeployerFund = requireEnv("CHILD_NONCE_RESERVED_DEPLOYER_FUND");
    let axelarEOA = requireEnv("AXELAR_EOA");
    let passportDeployer = requireEnv("PASSPORT_NONCE_RESERVER_ADDR");
    let axelarFund = requireEnv("AXELAR_FUND");
    let passportDeployerFund = requireEnv("PASSPORT_NONCE_RESERVER_FUND");

    // Get deployer address
    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let childDeployerWallet;
    if (deployerSecret == "ledger") {
        let index = requireEnv("DEPLOYER_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        childDeployerWallet = new LedgerSigner(childProvider, derivationPath);
    } else {
        childDeployerWallet = new ethers.Wallet(deployerSecret, childProvider);
    }
    let deployerAddr = await childDeployerWallet.getAddress();
    console.log("Deployer address is: ", deployerAddr);

    // Check duplicates
    if (hasDuplicates([deployerAddr, axelarEOA, reservedDeployerAddr, passportDeployer])) {
        throw("Duplicate address detected!");
    }

    // Execute
    console.log("Nonce reserved deployer now has: ", ethers.utils.formatEther(await childProvider.getBalance(reservedDeployerAddr)));
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));
    console.log("Passport deployer now has: ", ethers.utils.formatEther(await childProvider.getBalance(passportDeployer)));
    console.log("Fund Axelar, deployers on child chain in...");
    await waitForConfirmation();

    if ((await childProvider.getBalance(reservedDeployerAddr)).gte(ethers.utils.parseEther(reservedDeployerFund))) {
        console.log("Nonce reserved deployer has already got requested amount, skip.");
    } else {
        let [priorityFee, maxFee] = await getFee(childProvider);
        console.log("Transfer value to reserved nonce deployer...");
        let resp = await childDeployerWallet.sendTransaction({
            to: reservedDeployerAddr,
            value: ethers.utils.parseEther(reservedDeployerFund),
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })
        console.log("Transaction submitted: " + JSON.stringify(resp, null, 2));
        await waitForReceipt(resp.hash, childProvider);
    }

    if ((await childProvider.getBalance(axelarEOA)).gte(ethers.utils.parseEther(axelarFund))) {
        console.log("Axelar has already got requested amount, skip.");
    } else {
        let [priorityFee, maxFee] = await getFee(childProvider);
        console.log("Transfer value to axelar...");
        let resp = await childDeployerWallet.sendTransaction({
            to: axelarEOA,
            value: ethers.utils.parseEther(axelarFund),
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })
        console.log("Transaction submitted: " + JSON.stringify(resp, null, 2));
        await waitForReceipt(resp.hash, childProvider);
    }

    if ((await childProvider.getBalance(passportDeployer)).gte(ethers.utils.parseEther(passportDeployerFund))) {
        console.log("Passport deployer has already got requested amount, skip.");
    } else {
        let [priorityFee, maxFee] = await getFee(childProvider);
        console.log("Transfer value to Passport deployer...");
        let resp = await childDeployerWallet.sendTransaction({
            to: passportDeployer,
            value: ethers.utils.parseEther(passportDeployerFund),
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })
        console.log("Transaction submitted: " + JSON.stringify(resp, null, 2));
        await waitForReceipt(resp.hash, childProvider);
    }

    // Print target balance
    console.log("Nonce reserved deployer now has: ", ethers.utils.formatEther(await childProvider.getBalance(reservedDeployerAddr)));
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));
    console.log("Passport deployer now has: ", ethers.utils.formatEther(await childProvider.getBalance(passportDeployer)));

    console.log("=======End Deployer Funding=======");
}
run();