// Deploy root contracts
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, deployRootContract, waitForReceipt } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import * as fs from "fs";

export async function deployRootContracts() {
    // Check environment variables
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let rootDeployerSecret = requireEnv("ROOT_DEPLOYER_SECRET");
    let rootProxyAdmin = requireEnv("ROOT_PROXY_ADMIN");
    let rootGatewayAddr = requireEnv("ROOT_GATEWAY_ADDRESS");

    // Get admin address
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let adminWallet;
    if (rootDeployerSecret == "ledger") {
        let index = requireEnv("ROOT_DEPLOYER_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        adminWallet = new LedgerSigner(rootProvider, derivationPath);
    } else {
        adminWallet = new ethers.Wallet(rootDeployerSecret, rootProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Deployer address is: ", adminAddr);

    // Execute
    console.log("Deploy root contracts in...");
    await waitForConfirmation();

    // Deploy root token template
    console.log("Deploy root token template...");
    let rootTokenTemplate = await deployRootContract("ChildERC20", adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(rootTokenTemplate.deployTransaction, null, 2));
    await waitForReceipt(rootTokenTemplate.deployTransaction.hash, rootProvider);
    // Initialise template
    console.log("Initialise root token template...");
    let resp = await rootTokenTemplate.connect(adminWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);
    console.log("Deployed to ROOT_TOKEN_TEMPLATE: ", rootTokenTemplate.address);
    
    // Deploy proxy admin
    console.log("Deploy proxy admin...");
    let proxyAdmin = await deployRootContract("ProxyAdmin", adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(proxyAdmin.deployTransaction, null, 2));
    await waitForReceipt(proxyAdmin.deployTransaction.hash, rootProvider);
    // Change owner
    console.log("Change ownership...")
    resp = await proxyAdmin.connect(adminWallet).transferOwnership(rootProxyAdmin);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);
    console.log("Deployed to ROOT_PROXY_ADMIN: ", proxyAdmin.address);
    
    // Deploy root bridge impl
    console.log("Deploy root bridge impl...");
    let rootBridgeImpl = await deployRootContract("RootERC20BridgeFlowRate", adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(rootBridgeImpl.deployTransaction, null, 2));
    await waitForReceipt(rootBridgeImpl.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_BRIDGE_IMPL_ADDRESS: ", rootBridgeImpl.address);
    
    // Deploy root bridge proxy
    console.log("Deploy root bridge proxy...");
    let rootBridgeProxy = await deployRootContract("TransparentUpgradeableProxy", adminWallet, rootBridgeImpl.address, proxyAdmin.address, []);
    console.log("Transaction submitted: ", JSON.stringify(rootBridgeProxy.deployTransaction, null, 2));
    await waitForReceipt(rootBridgeProxy.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_BRIDGE_PROXY_ADDRESS: ", rootBridgeProxy.address);

    // Deploy root adaptor impl
    console.log("Deploy root adaptor impl...");
    let rootAdaptorImpl = await deployRootContract("RootAxelarBridgeAdaptor", adminWallet, rootGatewayAddr);
    console.log("Transaction submitted: ", JSON.stringify(rootAdaptorImpl.deployTransaction, null, 2));
    await waitForReceipt(rootAdaptorImpl.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_ADAPTOR_IMPL_ADDRESS: ", rootAdaptorImpl.address);

    // Deploy root adaptor proxy
    console.log("Deploy root adaptor proxy...");
    let rootAdaptorProxy = await deployRootContract("TransparentUpgradeableProxy", adminWallet, rootAdaptorImpl.address, proxyAdmin.address, []);
    console.log("Transaction submitted: ", JSON.stringify(rootAdaptorProxy.deployTransaction, null, 2));
    await waitForReceipt(rootAdaptorProxy.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_ADAPTOR_PROXY_ADDRESS: ", rootAdaptorProxy.address);

    let contractData = {
        ROOT_PROXY_ADMIN: rootBridgeImpl.address,
        ROOT_BRIDGE_IMPL_ADDRESS: rootBridgeImpl.address,
        ROOT_BRIDGE_PROXY_ADDRESS: rootBridgeProxy.address,
        ROOT_BRIDGE_ADDRESS: rootBridgeProxy.address,
        ROOT_ADAPTOR_IMPL_ADDRESS: rootAdaptorImpl.address,
        ROOT_ADAPTOR_PROXY_ADDRESS: rootAdaptorProxy.address,
        ROOT_ADAPTOR_ADDRESS: rootAdaptorProxy.address,
        ROOT_TOKEN_TEMPLATE: rootTokenTemplate.address,
    };
    fs.writeFileSync(".root.bridge.contracts.json", JSON.stringify(contractData, null, 2));
}