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
    let adminEOASecret = requireEnv("CHILD_ADMIN_EOA_SECRET");
    let axelarEOA = requireEnv("AXELAR_EOA");
    let axelarFund = requireEnv("AXELAR_FUND");
    let deployerEOA = requireEnv("CHILD_DEPLOYER_ADDR");
    let deployerFund = requireEnv("CHILD_DEPLOYER_FUND");

    // Get admin EOA address
    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let adminWallet;
    if (adminEOASecret == "ledger") {
        let index = requireEnv("CHILD_ADMIN_EOA_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        adminWallet = new LedgerSigner(childProvider, derivationPath);
    } else {
        adminWallet = new ethers.Wallet(adminEOASecret, childProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Admin address is: ", adminAddr);

    // Check duplicates
    if (hasDuplicates([adminAddr, axelarEOA, deployerEOA])) {
        throw("Duplicate address detected!");
    }

    // Execute
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));
    console.log("Deployer EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(deployerEOA)));
    console.log("Fund Axelar and deployer on child chain in...");
    await waitForConfirmation();

    let [priorityFee, maxFee] = await getFee(childProvider);
    console.log("Transfer value to axelar...");
    let resp = await adminWallet.sendTransaction({
        to: axelarEOA,
        value: ethers.utils.parseEther(axelarFund),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    })
    console.log("Transaction submitted: " + JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, childProvider);

    [priorityFee, maxFee] = await getFee(childProvider);
    console.log("Transfer value to deployer...");
    resp = await adminWallet.sendTransaction({
        to: deployerEOA,
        value: ethers.utils.parseEther(deployerFund),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    })
    console.log("Transaction submitted: " + JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, childProvider);

    // Print target balance
    console.log("Axelar EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(axelarEOA)));
    console.log("Deployer EOA now has: ", ethers.utils.formatEther(await childProvider.getBalance(deployerEOA)));

    console.log("=======End Deployer Funding=======");
}
run();