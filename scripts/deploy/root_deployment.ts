// Deploy root contracts
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, deployRootContract, waitForReceipt, getRootContracts, getContract, saveRootContracts, verifyRootContract } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import { RetryProvider } from "../helpers/retry";

export async function deployRootContracts() {
    // Check environment variables
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let nonceReservedDeployerSecret = requireEnv("NONCE_RESERVED_DEPLOYER_SECRET");
    let nonceReserved = Number(requireEnv("NONCE_RESERVED"));
    let rootGatewayAddr = requireEnv("ROOT_GATEWAY_ADDRESS");

    // Read from contract file.
    let rootContracts = getRootContracts();

    const rootProvider = new RetryProvider(rootRPCURL, Number(rootChainID));

    // Get deployer address
    let rootDeployerWallet;
    if (deployerSecret == "ledger") {
        let index = requireEnv("DEPLOYER_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        rootDeployerWallet = new LedgerSigner(rootProvider, derivationPath);
    } else {
        rootDeployerWallet = new ethers.Wallet(deployerSecret, rootProvider);
    }
    let deployerAddr = await rootDeployerWallet.getAddress();
    console.log("Deployer address is: ", deployerAddr);

    // Execute
    console.log("Deploy root contracts in...");
    await waitForConfirmation();

    // Deploy root bridge impl
    let rootBridgeImpl;
    if (rootContracts.ROOT_BRIDGE_IMPL_ADDRESS != "") {
        console.log("Root bridge impl has already been deployed to: " + rootContracts.ROOT_BRIDGE_IMPL_ADDRESS + ", skip.");
        rootBridgeImpl = getContract("RootERC20BridgeFlowRate", rootContracts.ROOT_BRIDGE_IMPL_ADDRESS, rootProvider);
    } else {
        console.log("Deploy root bridge impl...");
        rootBridgeImpl = await deployRootContract("RootERC20BridgeFlowRate", rootDeployerWallet, null, deployerAddr);
        console.log("Transaction submitted: ", JSON.stringify(rootBridgeImpl.deployTransaction, null, 2));
        await waitForReceipt(rootBridgeImpl.deployTransaction.hash, rootProvider);
        rootContracts.ROOT_BRIDGE_IMPL_ADDRESS = rootBridgeImpl.address;
        saveRootContracts(rootContracts);
        console.log("Deployed to ROOT_BRIDGE_IMPL_ADDRESS: ", rootBridgeImpl.address);
        await verifyRootContract("RootERC20BridgeFlowRate", rootBridgeImpl.address, `"constructor(address)" "${deployerAddr}"`);
    }

    // Deploy root adaptor impl
    let rootAdaptorImpl;
    if (rootContracts.ROOT_ADAPTOR_IMPL_ADDRESS != "") {
        console.log("Root adaptor impl has already been deployed to: " + rootContracts.ROOT_ADAPTOR_IMPL_ADDRESS + ", skip.");
        rootAdaptorImpl = getContract("RootAxelarBridgeAdaptor", rootContracts.ROOT_ADAPTOR_IMPL_ADDRESS, rootProvider);
    } else {
        console.log("Deploy root adaptor impl...");
        rootAdaptorImpl = await deployRootContract("RootAxelarBridgeAdaptor", rootDeployerWallet, null, rootGatewayAddr, deployerAddr);
        console.log("Transaction submitted: ", JSON.stringify(rootAdaptorImpl.deployTransaction, null, 2));
        await waitForReceipt(rootAdaptorImpl.deployTransaction.hash, rootProvider);
        rootContracts.ROOT_ADAPTOR_IMPL_ADDRESS = rootAdaptorImpl.address;
        saveRootContracts(rootContracts);
        console.log("Deployed to ROOT_ADAPTOR_IMPL_ADDRESS: ", rootAdaptorImpl.address);
        await verifyRootContract("RootAxelarBridgeAdaptor", rootAdaptorImpl.address, `"constructor(address,address)" "${rootGatewayAddr}" "${deployerAddr}"`);
    }

    if (rootDeployerWallet instanceof LedgerSigner) {
        rootDeployerWallet.close();
    }

    // Get reserved wallet
    let reservedDeployerWallet;
    if (nonceReservedDeployerSecret == "ledger") {
        let index = requireEnv("NONCE_RESERVED_DEPLOYER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        reservedDeployerWallet = new LedgerSigner(rootProvider, derivationPath);
    } else {
        reservedDeployerWallet = new ethers.Wallet(nonceReservedDeployerSecret, rootProvider);
    }
    let reservedDeployerAddr = await reservedDeployerWallet.getAddress();
    console.log("Reserved deployer address is: ", reservedDeployerAddr);

    // Deploy root token template
    let rootTokenTemplate;
    if (rootContracts.ROOT_TOKEN_TEMPLATE != "") {
        console.log("Root token template has already been deployed to: " + rootContracts.ROOT_TOKEN_TEMPLATE + ", skip.");
        rootTokenTemplate = getContract("ChildERC20", rootContracts.ROOT_TOKEN_TEMPLATE, rootProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await rootProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved != currentNonce) {
            throw("Nonce mismatch, expected " + nonceReserved + " actual " + currentNonce);
        }
        console.log("Deploy root token template...");
        rootTokenTemplate = await deployRootContract("ChildERC20", reservedDeployerWallet, nonceReserved);
        console.log("Transaction submitted: ", JSON.stringify(rootTokenTemplate.deployTransaction, null, 2));
        await waitForReceipt(rootTokenTemplate.deployTransaction.hash, rootProvider);
        rootContracts.ROOT_TOKEN_TEMPLATE = rootTokenTemplate.address;
        saveRootContracts(rootContracts);
        console.log("Deployed to ROOT_TOKEN_TEMPLATE: ", rootTokenTemplate.address);
        await verifyRootContract("ChildERC20", rootTokenTemplate.address, null);
    }

    // Initialise template
    if (await rootTokenTemplate.name() == "TEMPLATE") {
        console.log("Root token template has already been initialised, skip.");
    } else {
        console.log("Initialise root token template...");
        let resp = await rootTokenTemplate.connect(reservedDeployerWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18);
        console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
        await waitForReceipt(resp.hash, rootProvider);
    }
    console.log("Initialized ROOT_TOKEN_TEMPLATE at: ", rootTokenTemplate.address);

    // Deploy proxy admin
    let proxyAdmin;
    if (rootContracts.ROOT_PROXY_ADMIN != "") {
        console.log("Proxy admin has already been deployed to: " + rootContracts.ROOT_PROXY_ADMIN + ", skip.");
        proxyAdmin = getContract("ProxyAdmin", rootContracts.ROOT_PROXY_ADMIN, rootProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await rootProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved + 2 != currentNonce) {
            throw("Nonce mismatch, expected " + (nonceReserved + 2) + " actual " + currentNonce);
        }
        console.log("Deploy proxy admin...");
        proxyAdmin = await deployRootContract("ProxyAdmin", reservedDeployerWallet, null);
        console.log("Transaction submitted: ", JSON.stringify(proxyAdmin.deployTransaction, null, 2));
        await waitForReceipt(proxyAdmin.deployTransaction.hash, rootProvider);
        rootContracts.ROOT_PROXY_ADMIN = proxyAdmin.address;
        saveRootContracts(rootContracts);
        console.log("Deployed to ROOT_PROXY_ADMIN: ", proxyAdmin.address);
        await verifyRootContract("ProxyAdmin", proxyAdmin.address, null);
    }
    
    // Deploy root bridge proxy
    let rootBridgeProxy;
    if (rootContracts.ROOT_BRIDGE_PROXY_ADDRESS != "") {
        console.log("Root bridge proxy has already been deployed to: " + rootContracts.ROOT_BRIDGE_PROXY_ADDRESS + ", skip.");
        rootBridgeProxy = getContract("TransparentUpgradeableProxy", rootContracts.ROOT_BRIDGE_PROXY_ADDRESS, rootProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await rootProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved + 3 != currentNonce) {
            throw("Nonce mismatch, expected " + (nonceReserved + 3) + " actual " + currentNonce);
        }
        console.log("Deploy root bridge proxy...");
        rootBridgeProxy = await deployRootContract("TransparentUpgradeableProxy", reservedDeployerWallet, null, rootBridgeImpl.address, proxyAdmin.address, []);
        console.log("Transaction submitted: ", JSON.stringify(rootBridgeProxy.deployTransaction, null, 2));
        await waitForReceipt(rootBridgeProxy.deployTransaction.hash, rootProvider);
        rootContracts.ROOT_BRIDGE_PROXY_ADDRESS = rootBridgeProxy.address;
        saveRootContracts(rootContracts);
        console.log("Deployed to ROOT_BRIDGE_PROXY_ADDRESS: ", rootBridgeProxy.address);
        await verifyRootContract("TransparentUpgradeableProxy", rootBridgeProxy.address, `"constructor(address,address,bytes)" "${rootBridgeImpl.address}" "${proxyAdmin.address}" ""`);
    }

    // Deploy root adaptor proxy
    let rootAdaptorProxy;
    if (rootContracts.ROOT_ADAPTOR_PROXY_ADDRESS != "") {
        console.log("Root adaptor proxy has already been deployed to: " + rootContracts.ROOT_ADAPTOR_PROXY_ADDRESS + ", skip.");
        rootAdaptorProxy = getContract("TransparentUpgradeableProxy", rootContracts.ROOT_ADAPTOR_PROXY_ADDRESS, rootProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await rootProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved + 4 != currentNonce) {
            throw("Nonce mismatch, expected " + (nonceReserved + 4) + " actual " + currentNonce);
        }
        console.log("Deploy root adaptor proxy...");
        rootAdaptorProxy = await deployRootContract("TransparentUpgradeableProxy", reservedDeployerWallet, null, rootAdaptorImpl.address, proxyAdmin.address, []);
        console.log("Transaction submitted: ", JSON.stringify(rootAdaptorProxy.deployTransaction, null, 2));
        await waitForReceipt(rootAdaptorProxy.deployTransaction.hash, rootProvider);
        rootContracts.ROOT_ADAPTOR_PROXY_ADDRESS = rootAdaptorProxy.address;
        saveRootContracts(rootContracts);
        console.log("Deployed to ROOT_ADAPTOR_PROXY_ADDRESS: ", rootAdaptorProxy.address);
        await verifyRootContract("TransparentUpgradeableProxy", rootAdaptorProxy.address, `"constructor(address,address,bytes)" "${rootAdaptorImpl.address}" "${proxyAdmin.address}" ""`);
    }

    rootContracts.ROOT_BRIDGE_ADDRESS = rootBridgeProxy.address;
    rootContracts.ROOT_ADAPTOR_ADDRESS = rootAdaptorProxy.address;
    saveRootContracts(rootContracts);
}