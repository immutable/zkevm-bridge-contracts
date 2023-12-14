// Initialise child contracts
'use strict';
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, waitForReceipt, getFee, getContract, getChildContracts, getRootContracts } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";

export async function initialiseChildContracts() {
    let rootChainName = requireEnv("ROOT_CHAIN_NAME");
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let childGasServiceAddr = requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootIMXAddr = requireEnv("ROOT_IMX_ADDR");
    let childPrivilegedMultisig = requireEnv("CHILD_PRIVILEGED_MULTISIG_ADDR");
    let childBreakglass = requireEnv("CHILD_BREAKGLASS_ADDR");

    // Read from contract file.
    let childContracts = getChildContracts();
    let rootContracts = getRootContracts();
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
    let childAdaptorAddr = childContracts.CHILD_ADAPTOR_ADDRESS;
    let childWIMXAddr = childContracts.WRAPPED_IMX_ADDRESS;
    let childTemplateAddr = childContracts.CHILD_TOKEN_TEMPLATE;
    let rootAdaptorAddr = rootContracts.ROOT_ADAPTOR_ADDRESS;
    let rootTemplateAddr = rootContracts.ROOT_TOKEN_TEMPLATE;

    // Root token template must have the same address as child token template
    if (childTemplateAddr != rootTemplateAddr) {
        throw("Token template contract address mismatch: root " + rootTemplateAddr + " child " + childTemplateAddr);
    }

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

    // Execute
    console.log("Initialise child contracts in...");
    await waitForConfirmation();

    // Initialise child bridge
    let childBridge = getContract("ChildERC20Bridge", childBridgeAddr, childProvider);
    if (await childBridge.rootIMXToken() != "0x0000000000000000000000000000000000000000") {
        console.log("Child bridge has already been initialised, skip.");
    } else {
        console.log("Initialise child bridge...");
        let [priorityFee, maxFee] = await getFee(childProvider);
        let resp = await childBridge.connect(childDeployerWallet).initialize(
            {
                defaultAdmin: childPrivilegedMultisig,
                pauser: childBreakglass,
                unpauser: childPrivilegedMultisig,
                adaptorManager: childPrivilegedMultisig,
                initialDepositor: deployerAddr,
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
    }
    
    // Initialise child adaptor
    let childAdaptor = getContract("ChildAxelarBridgeAdaptor", childAdaptorAddr, childProvider);
    if (await childAdaptor.gasService() != "0x0000000000000000000000000000000000000000") {
        console.log("Child adaptor has already been initialized, skip.");
    } else {
        console.log("Initialise child adaptor...");
        let [priorityFee, maxFee] = await getFee(childProvider);
        let resp = await childAdaptor.connect(childDeployerWallet).initialize(
            {
                defaultAdmin: childPrivilegedMultisig,
                bridgeManager: childPrivilegedMultisig,
                gasServiceManager: childPrivilegedMultisig,
                targetManager: childPrivilegedMultisig,
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
}