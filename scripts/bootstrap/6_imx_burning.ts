// IMX burning
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, hasDuplicates, waitForReceipt, getFee } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import * as fs from "fs";

async function run() {
    console.log("=======Start IMX Burning=======");

    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = requireEnv("CHILD_ADMIN_EOA_SECRET");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let imxDepositLimit = requireEnv("IMX_DEPOSIT_LIMIT");

    // Read from contract file.
    let data = fs.readFileSync(".child.bridge.contracts.json", 'utf-8');
    let childContracts = JSON.parse(data);
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;

    // Get admin address
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
    if (hasDuplicates([adminAddr, childBridgeAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }

    // Execute
    let adminBal = await childProvider.getBalance(adminAddr);
    let bridgeBal = await childProvider.getBalance(childBridgeAddr);
    let multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    if (adminBal.lt(ethers.utils.parseEther("0.01"))) {
        console.log("IMX Burning has already been done, skip.")
        return;
    }

    console.log("Burn IMX in...");
    await waitForConfirmation();

    let childBridgeObj = JSON.parse(fs.readFileSync('../../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    let childBridge = new ethers.Contract(childBridgeAddr, childBridgeObj.abi, childProvider);

    console.log("Transfer " + imxDepositLimit +  " IMX to child bridge...");
    let [priorityFee, maxFee] = await getFee(childProvider);
    let resp = await childBridge.connect(adminWallet).privilegedDeposit({
        value: ethers.utils.parseEther(imxDepositLimit),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    })
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2))
    await waitForReceipt(resp.hash, childProvider);

    adminBal = await childProvider.getBalance(adminAddr);
    bridgeBal = await childProvider.getBalance(childBridgeAddr);
    multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    // Transfer to multisig
    console.log("Transfer remaining to multisig...");
    [priorityFee, maxFee] = await getFee(childProvider);
    resp = await adminWallet.sendTransaction({
        to: multisigAddr,
        value: adminBal.sub(ethers.utils.parseEther("0.01")),
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2))
    await waitForReceipt(resp.hash, childProvider);

    adminBal = await childProvider.getBalance(adminAddr);
    bridgeBal = await childProvider.getBalance(childBridgeAddr);
    multisigBal = await childProvider.getBalance(multisigAddr);
    console.log("Admin balance: ", ethers.utils.formatEther(adminBal));
    console.log("Bridge balance: ", ethers.utils.formatEther(bridgeBal));
    console.log("Multisig balance: ", ethers.utils.formatEther(multisigBal));

    console.log("=======End IMX Burning=======");
}
run();