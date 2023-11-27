// Initialise child contracts
'use strict';
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, waitForReceipt, getFee, getContract } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import * as fs from "fs";

export async function initialiseChildContracts() {
    let rootChainName = requireEnv("ROOT_CHAIN_NAME");
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let adminEOAAddr = requireEnv("CHILD_ADMIN_ADDR");
    let childBridgeDefaultAdmin = requireEnv("CHILD_BRIDGE_DEFAULT_ADMIN");
    let childBridgePauser = requireEnv("CHILD_BRIDGE_PAUSER");
    let childBridgeUnpauser = requireEnv("CHILD_BRIDGE_UNPAUSER");
    let childBridgeAdaptorManager = requireEnv("CHILD_BRIDGE_ADAPTOR_MANAGER");
    let childAdaptorDefaultAdmin = requireEnv("CHILD_ADAPTOR_DEFAULT_ADMIN");
    let childAdaptorBridgeManager = requireEnv("CHILD_ADAPTOR_BRIDGE_MANAGER");
    let childAdaptorGasServiceManager = requireEnv("CHILD_ADAPTOR_GAS_SERVICE_MANAGER");
    let childAdaptorTargetManager = requireEnv("CHILD_ADAPTOR_TARGET_MANAGER");
    let childDeployerSecret = requireEnv("CHILD_DEPLOYER_SECRET");
    let childGasServiceAddr = requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootIMXAddr = requireEnv("ROOT_IMX_ADDR");

    // Read from contract file.
    let data = fs.readFileSync(".child.bridge.contracts.json", 'utf-8');
    let childContracts = JSON.parse(data);
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
    let childAdaptorAddr = childContracts.CHILD_ADAPTOR_ADDRESS;
    let childWIMXAddr = childContracts.WRAPPED_IMX_ADDRESS;
    let childTemplateAddr = childContracts.CHILD_TOKEN_TEMPLATE;
    data = fs.readFileSync(".root.bridge.contracts.json", 'utf-8');
    let rootContracts = JSON.parse(data);
    let rootAdaptorAddr = rootContracts.ROOT_ADAPTOR_ADDRESS;

    // Get admin address
    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let adminWallet;
    if (childDeployerSecret == "ledger") {
        let index = requireEnv("CHILD_DEPLOYER_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        adminWallet = new LedgerSigner(childProvider, derivationPath);
    } else {
        adminWallet = new ethers.Wallet(childDeployerSecret, childProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Deployer address is: ", adminAddr);

    // Execute
    console.log("Initialise child contracts in...");
    await waitForConfirmation();

    // Initialise child bridge
    console.log("Initialise child bridge...");
    let childBridge = getContract("ChildERC20Bridge", childBridgeAddr, childProvider);
    let [priorityFee, maxFee] = await getFee(childProvider);
    let resp = await childBridge.connect(adminWallet).initialize(
        {
            defaultAdmin: childBridgeDefaultAdmin,
            pauser: childBridgePauser,
            unpauser: childBridgeUnpauser,
            adaptorManager: childBridgeAdaptorManager,
            initialDepositor: adminEOAAddr,
            treasuryManager: multisigAddr,
        },
        childAdaptorAddr,
        childTemplateAddr,
        rootIMXAddr,
        childWIMXAddr,
    {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, childProvider);

    // Initialise child adaptor
    console.log("Initialise child adaptor...");
    let childAdaptor = getContract("ChildAxelarBridgeAdaptor", childAdaptorAddr, childProvider);
    // let childAdaptor = new ethers.Contract(childAdaptorAddr, childAdaptorObj.abi, childProvider);
    [priorityFee, maxFee] = await getFee(childProvider);
    resp = await childAdaptor.connect(adminWallet).initialize(
        {
            defaultAdmin: childAdaptorDefaultAdmin,
            bridgeManager: childAdaptorBridgeManager,
            gasServiceManager: childAdaptorGasServiceManager,
            targetManager: childAdaptorTargetManager,
        },
        childBridgeAddr,
        rootChainName,
        rootAdaptorAddr,
        childGasServiceAddr,
    {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, childProvider);
}