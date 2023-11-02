// Deploy root contracts
'use strict';
require('dotenv').config();
const { ethers, ContractFactory } = require("ethers");
const fs = require('fs');

async function run() {
    // Check environment variables
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let adminEOASecret = requireEnv("ADMIN_EOA_SECRET");
    let rootProxyAdmin = requireEnv("ROOT_PROXY_ADMIN");

    // Get admin address
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let adminWallet;
    if (adminEOASecret == "ledger") {
        adminWallet = new LedgerSigner(rootProvider);
    } else {
        adminWallet = new ethers.Wallet(adminEOASecret, rootProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Admin address is: ", adminAddr);

    // Execute
    console.log("Deploy root contracts in...");
    await wait();

    // Deploy root token template
    let rootTokenTemplateObj = JSON.parse(fs.readFileSync('../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
    console.log("Deploy root token template...");
    let rootTokenTemplate = await deployRootContract(rootTokenTemplateObj, adminWallet);
    await waitForReceipt(rootTokenTemplate.deployTransaction.hash, rootProvider);
    // Initialise template
    let resp = await rootTokenTemplate.connect(adminWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18);
    await waitForReceipt(resp.hash, rootProvider);
    console.log("Deployed to ROOT_TOKEN_TEMPLATE: ", rootTokenTemplate.address);
    let output = "ROOT_TOKEN_TEMPLATE=" + rootTokenTemplate.address + "\n";

    // Deploy proxy admin
    let proxyAdminObj = JSON.parse(fs.readFileSync('../out/ProxyAdmin.sol/ProxyAdmin.json', 'utf8'));
    console.log("Deploy proxy admin...");
    let proxyAdmin = await deployRootContract(proxyAdminObj, adminWallet);
    await waitForReceipt(proxyAdmin.deployTransaction.hash, rootProvider);
    // Change owner
    resp = await proxyAdmin.connect(adminWallet).transferOwnership(rootProxyAdmin);
    await waitForReceipt(resp.hash, rootProvider);
    console.log("Deployed to ROOT_PROXY_ADMIN: ", proxyAdmin.address);
    output += "ROOT_PROXY_ADMIN=" + proxyAdmin.address + "\n";

    // Deploy root bridge impl
    let rootBridgeImplObj = JSON.parse(fs.readFileSync('../out/RootERC20Bridge.sol/RootERC20Bridge.json', 'utf8'));
    console.log("Deploy root bridge impl...");
    let rootBridgeImpl = await deployRootContract(rootBridgeImplObj, adminWallet);
    await waitForReceipt(rootBridgeImpl.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_BRIDGE_IMPL_ADDRESS: ", rootBridgeImpl.address);
    output += "ROOT_BRIDGE_IMPL_ADDRESS=" + rootBridgeImpl.address + "\n";

    // Deploy root bridge proxy
    let rootBridgeProxyObj = JSON.parse(fs.readFileSync('../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy root bridge proxy...");
    let rootBridgeProxy = await deployRootContract(rootBridgeProxyObj, adminWallet, rootBridgeImpl.address, proxyAdmin.address, []);
    await waitForReceipt(rootBridgeProxy.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_BRIDGE_PROXY_ADDRESS: ", rootBridgeProxy.address);
    output += "ROOT_BRIDGE_PROXY_ADDRESS=" + rootBridgeProxy.address + "\n";

    // Deploy root adaptor impl
    let rootAdaptorImplObj = JSON.parse(fs.readFileSync('../out/RootAxelarBridgeAdaptor.sol/RootAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Deploy root adaptor impl...");
    let rootAdaptorImpl = await deployRootContract(rootAdaptorImplObj, adminWallet);
    await waitForReceipt(rootAdaptorImpl.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_ADAPTOR_IMPL_ADDRESS: ", rootAdaptorImpl.address);
    output += "ROOT_ADAPTOR_IMPL_ADDRESS=" + rootAdaptorImpl.address + "\n";

    // Deploy root adaptor proxy
    let rootAdaptorProxyObj = JSON.parse(fs.readFileSync('../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy root adaptor proxy...");
    let rootAdaptorProxy = await deployRootContract(rootAdaptorProxyObj, adminWallet, rootAdaptorImpl.address, proxyAdmin.address, []);
    await waitForReceipt(rootAdaptorProxy.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_ADAPTOR_PROXY_ADDRESS: ", rootAdaptorProxy.address);
    output += "ROOT_ADAPTOR_PROXY_ADDRESS=" + rootAdaptorProxy.address + "\n";

    fs.writeFileSync("./4.out.tmp", output);
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

async function deployRootContract(contractObj, adminWallet, ...args) {
    let factory = new ContractFactory(contractObj.abi, contractObj.bytecode, adminWallet);
    return await factory.deploy(...args);
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