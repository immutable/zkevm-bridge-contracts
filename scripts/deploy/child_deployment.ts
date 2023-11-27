// Deploy child contracts
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, deployChildContract, waitForReceipt, getFee } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import * as fs from "fs";

export async function deployChildContracts() {
    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let childDeployerSecret = requireEnv("CHILD_DEPLOYER_SECRET");
    let childGatewayAddr = requireEnv("CHILD_GATEWAY_ADDRESS");
    let childProxyAdmin = requireEnv("CHILD_PROXY_ADMIN");

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
    console.log("Deploy child contracts in...");
    await waitForConfirmation();

    // Deploy child token template
    console.log("Deploy child token template...");
    let childTokenTemplate = await deployChildContract("ChildERC20", adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(childTokenTemplate.deployTransaction, null, 2));
    await waitForReceipt(childTokenTemplate.deployTransaction.hash, childProvider);
    // Initialise template
    console.log("Initialise child token template...");
    let [priorityFee, maxFee] = await getFee(childProvider);
    let resp = await childTokenTemplate.connect(adminWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, childProvider);
    console.log("Deployed to CHILD_TOKEN_TEMPLATE: ", childTokenTemplate.address);

    // Deploy wrapped IMX
    console.log("Deploy wrapped IMX...");
    let wrappedIMX = await deployChildContract("WIMX", adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(wrappedIMX.deployTransaction, null, 2));
    await waitForReceipt(wrappedIMX.deployTransaction.hash, childProvider);
    console.log("Deployed to WRAPPED_IMX_ADDRESS: ", wrappedIMX.address);

    // Deploy proxy admin
    console.log("Deploy proxy admin...");
    let proxyAdmin = await deployChildContract("ProxyAdmin", adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(proxyAdmin.deployTransaction, null, 2));
    await waitForReceipt(proxyAdmin.deployTransaction.hash, childProvider);
    // Change owner
    console.log("Change ownership...");
    [priorityFee, maxFee] = await getFee(childProvider);
    resp = await proxyAdmin.connect(adminWallet).transferOwnership(childProxyAdmin, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, childProvider);
    console.log("Deployed to CHILD_PROXY_ADMIN: ", proxyAdmin.address);

    // Deploy child bridge impl
    console.log("Deploy child bridge impl...");
    let childBridgeImpl = await deployChildContract("ChildERC20Bridge", adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(childBridgeImpl.deployTransaction, null, 2));
    await waitForReceipt(childBridgeImpl.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_BRIDGE_IMPL_ADDRESS: ", childBridgeImpl.address);
    
    // Deploy child bridge proxy
    console.log("Deploy child bridge proxy...");
    let childBridgeProxy = await deployChildContract("TransparentUpgradeableProxy", adminWallet, childBridgeImpl.address, proxyAdmin.address, []);
    console.log("Transaction submitted: ", JSON.stringify(childBridgeProxy.deployTransaction, null, 2));
    await waitForReceipt(childBridgeProxy.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_BRIDGE_PROXY_ADDRESS: ", childBridgeProxy.address);
    
    // Deploy child adaptor impl
    console.log("Deploy child adaptor impl...");
    let childAdaptorImpl = await deployChildContract("ChildAxelarBridgeAdaptor", adminWallet, childGatewayAddr);
    console.log("Transaction submitted: ", JSON.stringify(childAdaptorImpl.deployTransaction, null, 2));
    await waitForReceipt(childAdaptorImpl.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_ADAPTOR_IMPL_ADDRESS: ", childAdaptorImpl.address);
    
    // Deploy child adaptor proxy
    console.log("Deploy child adaptor proxy...");
    let childAdaptorProxy = await deployChildContract("TransparentUpgradeableProxy", adminWallet, childAdaptorImpl.address, proxyAdmin.address, []);
    console.log("Transaction submitted: ", JSON.stringify(childAdaptorProxy.deployTransaction, null, 2));
    await waitForReceipt(childAdaptorProxy.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_ADAPTOR_PROXY_ADDRESS: ", childAdaptorProxy.address);

    let contractData = {
        CHILD_PROXY_ADMIN: proxyAdmin.address,
        CHILD_BRIDGE_IMPL_ADDRESS: childBridgeImpl.address,
        CHILD_BRIDGE_PROXY_ADDRESS: childBridgeProxy.address,
        CHILD_BRIDGE_ADDRESS: childBridgeProxy.address,
        CHILD_ADAPTOR_IMPL_ADDRESS: childAdaptorImpl.address,
        CHILD_ADAPTOR_PROXY_ADDRESS: childAdaptorProxy.address,
        CHILD_ADAPTOR_ADDRESS: childAdaptorProxy.address,
        CHILD_TOKEN_TEMPLATE: childTokenTemplate.address,
        WRAPPED_IMX_ADDRESS: wrappedIMX.address,
    };
    fs.writeFileSync(".child.bridge.contracts.json", JSON.stringify(contractData, null, 2));
}