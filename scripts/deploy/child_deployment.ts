// Deploy child contracts
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, deployChildContract, waitForReceipt, getFee, getChildContracts, getContract, saveChildContracts, verifyChildContract } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";

export async function deployChildContracts() {
    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let nonceReservedDeployerSecret = requireEnv("NONCE_RESERVED_DEPLOYER_SECRET");
    let nonceReserved = Number(requireEnv("NONCE_RESERVED"));
    let childGatewayAddr = requireEnv("CHILD_GATEWAY_ADDRESS");

    // Read from contract file.
    let childContracts = getChildContracts();

    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));

    // Get deployer address
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
    console.log("Deploy child contracts in...");
    await waitForConfirmation();

    // Deploy wrapped IMX
    let wrappedIMX;
    if (childContracts.WRAPPED_IMX_ADDRESS != "") {
        console.log("Wrapped IMX has already been deployed to: " + childContracts.WRAPPED_IMX_ADDRESS + ", skip.");
        wrappedIMX = getContract("WIMX", childContracts.WRAPPED_IMX_ADDRESS, childProvider);
    } else {
        console.log("Deploy wrapped IMX...");
        wrappedIMX = await deployChildContract("WIMX", childDeployerWallet, null);
        console.log("Transaction submitted: ", JSON.stringify(wrappedIMX.deployTransaction, null, 2));
        await waitForReceipt(wrappedIMX.deployTransaction.hash, childProvider);
        verifyChildContract("WIMX", wrappedIMX.address);
    }
    childContracts.WRAPPED_IMX_ADDRESS = wrappedIMX.address;
    saveChildContracts(childContracts);
    console.log("Deployed to WRAPPED_IMX_ADDRESS: ", wrappedIMX.address);

    // Deploy child bridge impl
    let childBridgeImpl;
    if (childContracts.CHILD_BRIDGE_IMPL_ADDRESS != "") {
        console.log("Child bridge impl has already been deployed to: " + childContracts.CHILD_BRIDGE_IMPL_ADDRESS + ", skip.");
        childBridgeImpl = getContract("ChildERC20Bridge", childContracts.CHILD_BRIDGE_IMPL_ADDRESS, childProvider);
    } else {
        console.log("Deploy child bridge impl...");
        childBridgeImpl = await deployChildContract("ChildERC20Bridge", childDeployerWallet, null, deployerAddr);
        console.log("Transaction submitted: ", JSON.stringify(childBridgeImpl.deployTransaction, null, 2));
        await waitForReceipt(childBridgeImpl.deployTransaction.hash, childProvider);
        verifyChildContract("ChildERC20Bridge", childBridgeImpl.address);
    }
    childContracts.CHILD_BRIDGE_IMPL_ADDRESS = childBridgeImpl.address;
    saveChildContracts(childContracts);
    console.log("Deployed to CHILD_BRIDGE_IMPL_ADDRESS: ", childBridgeImpl.address);

    // Deploy child adaptor impl
    let childAdaptorImpl;
    if (childContracts.CHILD_ADAPTOR_IMPL_ADDRESS != "") {
        console.log("Child adaptor impl has already been deployed to: " + childContracts.CHILD_ADAPTOR_IMPL_ADDRESS + ", skip.");
        childAdaptorImpl = getContract("ChildAxelarBridgeAdaptor", childContracts.CHILD_ADAPTOR_IMPL_ADDRESS, childProvider);
    } else {
        console.log("Deploy child adaptor impl...");
        childAdaptorImpl = await deployChildContract("ChildAxelarBridgeAdaptor", childDeployerWallet, null, childGatewayAddr, deployerAddr);
        console.log("Transaction submitted: ", JSON.stringify(childAdaptorImpl.deployTransaction, null, 2));
        await waitForReceipt(childAdaptorImpl.deployTransaction.hash, childProvider);
        verifyChildContract("ChildAxelarBridgeAdaptor", childAdaptorImpl.address);
    }
    childContracts.CHILD_ADAPTOR_IMPL_ADDRESS = childAdaptorImpl.address;
    saveChildContracts(childContracts);
    console.log("Deployed to CHILD_ADAPTOR_IMPL_ADDRESS: ", childAdaptorImpl.address);

    if (childDeployerWallet instanceof LedgerSigner) {
        childDeployerWallet.close();
    }

    // Get reserved wallet
    let reservedDeployerWallet;
    if (nonceReservedDeployerSecret == "ledger") {
        let index = requireEnv("NONCE_RESERVED_DEPLOYER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        reservedDeployerWallet = new LedgerSigner(childProvider, derivationPath);
    } else {
        reservedDeployerWallet = new ethers.Wallet(nonceReservedDeployerSecret, childProvider);
    }
    let reservedDeployerAddr = await reservedDeployerWallet.getAddress();
    console.log("Reserved deployer address is: ", reservedDeployerAddr);

    // Deploy child token template
    let childTokenTemplate;
    if (childContracts.CHILD_TOKEN_TEMPLATE != "") {
        console.log("Child token template has already been deployed to: " + childContracts.CHILD_TOKEN_TEMPLATE + ", skip.");
        childTokenTemplate = getContract("ChildERC20", childContracts.CHILD_TOKEN_TEMPLATE, childProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await childProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved != currentNonce) {
            throw("Nonce mismatch, expected " + nonceReserved + " actual " + currentNonce);
        }
        console.log("Deploy child token template...");
        childTokenTemplate = await deployChildContract("ChildERC20", reservedDeployerWallet, nonceReserved);
        console.log("Transaction submitted: ", JSON.stringify(childTokenTemplate.deployTransaction, null, 2));
        await waitForReceipt(childTokenTemplate.deployTransaction.hash, childProvider);
        verifyChildContract("ChildERC20", childTokenTemplate.address);
    }
    childContracts.CHILD_TOKEN_TEMPLATE = childTokenTemplate.address;
    saveChildContracts(childContracts);
    console.log("Deployed to CHILD_TOKEN_TEMPLATE: ", childTokenTemplate.address);
    
    // Initialise template
    if (await childTokenTemplate.name() == "TEMPLATE") {
        console.log("Child token template has already been initialised, skip.");
    } else {
        console.log("Initialise child token template...");
        let [priorityFee, maxFee] = await getFee(childProvider);
        let resp = await childTokenTemplate.connect(reservedDeployerWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18, {
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
        await waitForReceipt(resp.hash, childProvider);
    }
    console.log("Initialised CHILD_TOKEN_TEMPLATE at: ", childTokenTemplate.address);

    // Deploy proxy admin
    let proxyAdmin;
    if (childContracts.CHILD_PROXY_ADMIN != "") {
        console.log("Proxy admin has already been deployed to: " + childContracts.CHILD_PROXY_ADMIN + ", skip.");
        proxyAdmin = getContract("ProxyAdmin", childContracts.CHILD_PROXY_ADMIN, childProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await childProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved + 2 != currentNonce) {
            throw("Nonce mismatch, expected " + (nonceReserved + 2) + " actual " + currentNonce);
        }
        console.log("Deploy proxy admin...");
        proxyAdmin = await deployChildContract("ProxyAdmin", reservedDeployerWallet, null);
        console.log("Transaction submitted: ", JSON.stringify(proxyAdmin.deployTransaction, null, 2));
        await waitForReceipt(proxyAdmin.deployTransaction.hash, childProvider);
        verifyChildContract("ProxyAdmin", proxyAdmin.address);
    }
    childContracts.CHILD_PROXY_ADMIN = proxyAdmin.address;
    saveChildContracts(childContracts);
    console.log("Deployed to CHILD_PROXY_ADMIN: ", proxyAdmin.address);

    // Deploy child bridge proxy
    let childBridgeProxy;
    if (childContracts.CHILD_BRIDGE_PROXY_ADDRESS != "") {
        console.log("Child bridge proxy has already been deployed to: " + childContracts.CHILD_BRIDGE_PROXY_ADDRESS + ", skip.");
        childBridgeProxy = getContract("TransparentUpgradeableProxy", childContracts.CHILD_BRIDGE_PROXY_ADDRESS, childProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await childProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved + 3 != currentNonce) {
            throw("Nonce mismatch, expected " + (nonceReserved + 3) + " actual " + currentNonce);
        }
        console.log("Deploy child bridge proxy...");
        childBridgeProxy = await deployChildContract("TransparentUpgradeableProxy", reservedDeployerWallet, null, childBridgeImpl.address, proxyAdmin.address, []);
        console.log("Transaction submitted: ", JSON.stringify(childBridgeProxy.deployTransaction, null, 2));
        await waitForReceipt(childBridgeProxy.deployTransaction.hash, childProvider);
        verifyChildContract("TransparentUpgradeableProxy", childBridgeProxy.address);
    }
    childContracts.CHILD_BRIDGE_PROXY_ADDRESS = childBridgeProxy.address;
    saveChildContracts(childContracts);
    console.log("Deployed to CHILD_BRIDGE_PROXY_ADDRESS: ", childBridgeProxy.address);
    
    // Deploy child adaptor proxy
    let childAdaptorProxy;
    if (childContracts.CHILD_ADAPTOR_PROXY_ADDRESS != "") {
        console.log("Child adaptor proxy has already been deployed to: " + childContracts.CHILD_ADAPTOR_PROXY_ADDRESS + ", skip.");
        childAdaptorProxy = getContract("TransparentUpgradeableProxy", childContracts.CHILD_ADAPTOR_PROXY_ADDRESS, childProvider);
    } else {
        // Check the current nonce matches the reserved nonce
        let currentNonce = await childProvider.getTransactionCount(reservedDeployerAddr);
        if (nonceReserved + 4 != currentNonce) {
            throw("Nonce mismatch, expected " + (nonceReserved + 4) + " actual " + currentNonce);
        }
        console.log("Deploy child adaptor proxy...");
        childAdaptorProxy = await deployChildContract("TransparentUpgradeableProxy", reservedDeployerWallet, null, childAdaptorImpl.address, proxyAdmin.address, []);
        console.log("Transaction submitted: ", JSON.stringify(childAdaptorProxy.deployTransaction, null, 2));
        await waitForReceipt(childAdaptorProxy.deployTransaction.hash, childProvider);
        verifyChildContract("TransparentUpgradeableProxy", childAdaptorProxy.address);
    }
    childContracts.CHILD_ADAPTOR_PROXY_ADDRESS = childAdaptorProxy.address;
    saveChildContracts(childContracts);
    console.log("Deployed to CHILD_ADAPTOR_PROXY_ADDRESS: ", childAdaptorProxy.address);

    childContracts.CHILD_BRIDGE_ADDRESS = childBridgeProxy.address;
    childContracts.CHILD_ADAPTOR_ADDRESS = childAdaptorProxy.address,
    saveChildContracts(childContracts);
}