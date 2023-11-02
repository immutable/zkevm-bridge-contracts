// Deploy child contracts
'use strict';
require('dotenv').config();
const { ethers, ContractFactory } = require("ethers");
const fs = require('fs');

async function run() {
    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let childGatewayAddr = requireEnv("CHILD_GATEWAY_ADDRESS");
    let childGasServiceAddr = requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let childProxyAdmin = requireEnv("CHILD_PROXY_ADMIN");

    // Get admin address
    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let adminWallet;
    if (adminEOASecret == "ledger") {
        adminWallet = new LedgerSigner(childProvider);
    } else {
        adminWallet = new ethers.Wallet(adminEOASecret, childProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Admin address is: ", adminAddr);

    // Execute 
    console.log("Deploy child contracts in...")
    await wait();

    // Deploy child token template
    let childTokenTemplateObj = JSON.parse(fs.readFileSync('../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
    console.log("Deploy child token template...");
    let childTokenTemplate = await deployChildContract(childTokenTemplateObj, adminWallet);
    await waitForReceipt(childTokenTemplate.deployTransaction.hash, childProvider);
    // Initialise template
    let [priorityFee, maxFee] = await getFee(adminWallet);
    let resp = await childTokenTemplate.connect(adminWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await waitForReceipt(resp.hash, childProvider);
    console.log("Deployed to CHILD_TOKEN_TEMPLATE: ", childTokenTemplate.address);
    let output = "CHILD_TOKEN_TEMPLATE=" + childTokenTemplate.address + "\n";

    // Deploy wrapped IMX
    let wrappedIMXObj = JSON.parse(fs.readFileSync('../out/WIMX.sol/WIMX.json', 'utf8'));
    console.log("Deploy wrapped IMX...");
    let wrappedIMX = await deployChildContract(wrappedIMXObj, adminWallet);
    await waitForReceipt(wrappedIMX.deployTransaction.hash, childProvider);
    console.log("Deploy to WRAPPED_IMX_ADDRESS: ", wrappedIMX.address);
    output += "WRAPPED_IMX_ADDRESS=" + wrappedIMX.address + "\n";

    // Deploy proxy admin
    let proxyAdminObj = JSON.parse(fs.readFileSync('../out/ProxyAdmin.sol/ProxyAdmin.json', 'utf8'));
    console.log("Deploy proxy admin...");
    let proxyAdmin = await deployChildContract(proxyAdminObj, adminWallet);
    await waitForReceipt(proxyAdmin.deployTransaction.hash, childProvider);
    // Change owner
    [priorityFee, maxFee] = await getFee(adminWallet);
    resp = await proxyAdmin.connect(adminWallet).transferOwnership(childProxyAdmin, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await waitForReceipt(resp.hash, childProvider);
    console.log("Deploy to CHILD_PROXY_ADMIN: ", proxyAdmin.address);
    output += "CHILD_PROXY_ADMIN=" + proxyAdmin.address + "\n";

    // Deploy child bridge impl
    let childBridgeImplObj = JSON.parse(fs.readFileSync('../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    console.log("Deploy child bridge impl...");
    let childBridgeImpl = await deployChildContract(childBridgeImplObj, adminWallet);
    await waitForReceipt(childBridgeImpl.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_BRIDGE_IMPL_ADDRESS: ", childBridgeImpl.address);
    output += "CHILD_BRIDGE_IMPL_ADDRESS=" + childBridgeImpl.address + "\n";

    // Deploy child bridge proxy
    let childBridgeProxyObj = JSON.parse(fs.readFileSync('../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy child bridge proxy...");
    let childBridgeProxy = await deployChildContract(childBridgeProxyObj, adminWallet, childBridgeImpl.address, proxyAdmin.address, []);
    await waitForReceipt(childBridgeProxy.deployTransaction.hash, childProvider);
    console.log("Deploy to CHILD_BRIDGE_PROXY_ADDRESS: ", childBridgeProxy.address);
    output += "CHILD_BRIDGE_PROXY_ADDRESS=" + childBridgeProxy.address + "\n";

    // Deploy child adaptor impl
    let childAdaptorImplObj = JSON.parse(fs.readFileSync('../out/ChildAxelarBridgeAdaptor.sol/ChildAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Deploy child adaptor impl...");
    let childAdaptorImpl = await deployChildContract(childAdaptorImplObj, adminWallet, childGatewayAddr);
    await waitForReceipt(childAdaptorImpl.deployTransaction.hash, childProvider);
    console.log("Deploy to CHILD_ADAPTOR_IMPL_ADDRESS: ", childAdaptorImpl.address);
    output += "CHILD_ADAPTOR_IMPL_ADDRESS=" + childAdaptorImpl.address + "\n";

    // Deploy child adaptor proxy
    let childAdaptorProxyObj = JSON.parse(fs.readFileSync('../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy child adaptor proxy...");
    let childAdaptorProxy = await deployChildContract(childAdaptorProxyObj, adminWallet, childAdaptorImpl.address, proxyAdmin.address, []);
    await waitForReceipt(childAdaptorProxy.deployTransaction.hash, childProvider);
    console.log("Deploy to CHILD_ADAPTOR_PROXY_ADDRESS: ", childAdaptorProxy.address);
    output += "CHILD_ADAPTOR_PROXY_ADDRESS" + childAdaptorProxy.address + "\n";

    fs.writeFileSync("./3.out.tmp", output);
}

run();

// Helper functions
function requireEnv(envName) {
    let val = process.env[envName];
    if (val == null || val == "") {
        throw(envName + " not set!");
    }
    if (!envName.includes("SECRET")) {
        console.log(envName + ": ", val);
    }
    return val
}

function delay(time) {
    return new Promise(resolve => setTimeout(resolve, time));
}

async function wait() {
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
}

async function getFee(adminWallet) {
    let feeData = await adminWallet.getFeeData();
    let baseFee = feeData.lastBaseFeePerGas;
    let gasPrice = feeData.gasPrice;
    let priorityFee = Math.round(gasPrice * 150 / 100);
    let maxFee = Math.round(1.13 * baseFee + priorityFee);
    return [priorityFee, maxFee];
}

async function deployChildContract(contractObj, adminWallet, ...args) {
    let [priorityFee, maxFee] = await getFee(adminWallet);
    let factory = new ContractFactory(contractObj.abi, contractObj.bytecode, adminWallet);
    return await factory.deploy(...args, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
}

async function waitForReceipt(txHash, provider) {
    let receipt;
    while (receipt == null) {
        receipt = await provider.getTransactionReceipt(txHash)
        await delay(1000);
    }
    if (receipt.status != 1) {
        throw("Fail to execute");
    }
    console.log(receipt);
    console.log("Succeed.");
}