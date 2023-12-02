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
    let axelarFund = requireEnv("AXELAR_FUND");

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
    if (hasDuplicates([deployerAddr, axelarEOA, reservedDeployerAddr])) {
        throw("Duplicate address detected!");
    }

    // Execute
    console.log("Nonce reserved deployer now has: ", ethers.utils.formatEther(await childProvider.getBalance(reservedDeployerAddr)));
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));
    console.log("Fund Axelar and deployer on child chain in...");
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

    // Print target balance
    console.log("Nonce reserved deployer now has: ", ethers.utils.formatEther(await childProvider.getBalance(reservedDeployerAddr)));
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));

    console.log("=======End Deployer Funding=======");
}
run();