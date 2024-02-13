// IMX burning
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, hasDuplicates, waitForReceipt, getFee, getContract, getChildContracts } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import { RetryProvider } from "../helpers/retry";

async function run() {
    console.log("=======Start IMX Burning=======");

    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let imxDepositLimit = requireEnv("IMX_DEPOSIT_LIMIT");
    let deployerFund = requireEnv("CHILD_DEPLOYER_FUND");

    // Read from contract file.
    let childContracts = getChildContracts();
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;

    // Get deployer address
    const childProvider = new RetryProvider(childRPCURL, Number(childChainID));
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
    if (hasDuplicates([deployerAddr, childBridgeAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }

    // Execute
    let deployerBal = await childProvider.getBalance(deployerAddr);
    let bridgeBal = await childProvider.getBalance(childBridgeAddr);
    let multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Deployer balance: ", ethers.utils.formatEther(deployerBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    console.log("Burn IMX in...");
    await waitForConfirmation();

    if ((await childProvider.getBalance(childBridgeAddr)).gte(ethers.utils.parseEther(imxDepositLimit))) {
        console.log("Child bridge has already got burned IMX, skip.");
    } else {
        console.log("Transfer " + imxDepositLimit +  " IMX to child bridge...");
        let [priorityFee, maxFee] = await getFee(childProvider);
        let childBridge = getContract("ChildERC20Bridge", childBridgeAddr, childProvider);
        let resp = await childBridge.connect(childDeployerWallet).privilegedDeposit({
            value: ethers.utils.parseEther(imxDepositLimit),
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })
        console.log("Transaction submitted: ", JSON.stringify(resp, null, 2))
        await waitForReceipt(resp.hash, childProvider);
    }

    // Transfer to multisig
    let remain = ethers.utils.parseEther(deployerFund);
    deployerBal = await childProvider.getBalance(deployerAddr);
    if (deployerBal.lte(remain)) {
        console.log("Multisig has already got remaining burned IMX, skip.");
    } else {
        console.log("Transfer remaining to multisig...");
        let toTransfer = deployerBal.sub(remain);
        let [priorityFee, maxFee] = await getFee(childProvider);
        let resp = await childDeployerWallet.sendTransaction({
            to: multisigAddr,
            value: toTransfer,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        console.log("Transaction submitted: ", JSON.stringify(resp, null, 2))
        await waitForReceipt(resp.hash, childProvider);
    }

    deployerBal = await childProvider.getBalance(deployerAddr);
    bridgeBal = await childProvider.getBalance(childBridgeAddr);
    multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Deployer balance: ", ethers.utils.formatEther(deployerBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    console.log("=======End IMX Burning=======");
}
run();