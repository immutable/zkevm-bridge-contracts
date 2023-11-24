// Deploy root contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')
const fs = require('fs');

exports.deployRootContracts = async () => {
    // Check environment variables
    let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
    let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
    let rootDeployerSecret = helper.requireEnv("ROOT_DEPLOYER_SECRET");
    let rootProxyAdmin = helper.requireEnv("ROOT_PROXY_ADMIN");
    let rootGatewayAddr = helper.requireEnv("ROOT_GATEWAY_ADDRESS");

    // Get admin address
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let adminWallet;
    if (rootDeployerSecret == "ledger") {
        adminWallet = new LedgerSigner(rootProvider);
    } else {
        adminWallet = new ethers.Wallet(rootDeployerSecret, rootProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Deployer address is: ", adminAddr);

    // Execute
    console.log("Deploy root contracts in...");
    await helper.waitForConfirmation();

    // Deploy root token template
    let rootTokenTemplateObj = JSON.parse(fs.readFileSync('../../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
    console.log("Deploy root token template...");
    let rootTokenTemplate = await helper.deployRootContract(rootTokenTemplateObj, adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(rootTokenTemplate.deployTransaction, null, 2));
    await helper.waitForReceipt(rootTokenTemplate.deployTransaction.hash, rootProvider);
    // Initialise template
    console.log("Initialise root token template...");
    let resp = await rootTokenTemplate.connect(adminWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);
    console.log("Deployed to ROOT_TOKEN_TEMPLATE: ", rootTokenTemplate.address);
    
    // Deploy proxy admin
    let proxyAdminObj = JSON.parse(fs.readFileSync('../../out/ProxyAdmin.sol/ProxyAdmin.json', 'utf8'));
    console.log("Deploy proxy admin...");
    let proxyAdmin = await helper.deployRootContract(proxyAdminObj, adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(proxyAdmin.deployTransaction, null, 2));
    await helper.waitForReceipt(proxyAdmin.deployTransaction.hash, rootProvider);
    // Change owner
    console.log("Change ownership...")
    resp = await proxyAdmin.connect(adminWallet).transferOwnership(rootProxyAdmin);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);
    console.log("Deployed to ROOT_PROXY_ADMIN: ", proxyAdmin.address);
    
    // Deploy root bridge impl
    let rootBridgeImplObj = JSON.parse(fs.readFileSync('../../out/RootERC20BridgeFlowRate.sol/RootERC20BridgeFlowRate.json', 'utf8'));
    console.log("Deploy root bridge impl...");
    let rootBridgeImpl = await helper.deployRootContract(rootBridgeImplObj, adminWallet);
    console.log("Transaction submitted: ", JSON.stringify(rootBridgeImpl.deployTransaction, null, 2));
    await helper.waitForReceipt(rootBridgeImpl.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_BRIDGE_IMPL_ADDRESS: ", rootBridgeImpl.address);
    
    // Deploy root bridge proxy
    let rootBridgeProxyObj = JSON.parse(fs.readFileSync('../../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy root bridge proxy...");
    let rootBridgeProxy = await helper.deployRootContract(rootBridgeProxyObj, adminWallet, rootBridgeImpl.address, proxyAdmin.address, []);
    console.log("Transaction submitted: ", JSON.stringify(rootBridgeProxy.deployTransaction, null, 2));
    await helper.waitForReceipt(rootBridgeProxy.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_BRIDGE_PROXY_ADDRESS: ", rootBridgeProxy.address);

    // Deploy root adaptor impl
    let rootAdaptorImplObj = JSON.parse(fs.readFileSync('../../out/RootAxelarBridgeAdaptor.sol/RootAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Deploy root adaptor impl...");
    let rootAdaptorImpl = await helper.deployRootContract(rootAdaptorImplObj, adminWallet, rootGatewayAddr);
    console.log("Transaction submitted: ", JSON.stringify(rootAdaptorImpl.deployTransaction, null, 2));
    await helper.waitForReceipt(rootAdaptorImpl.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_ADAPTOR_IMPL_ADDRESS: ", rootAdaptorImpl.address);

    // Deploy root adaptor proxy
    let rootAdaptorProxyObj = JSON.parse(fs.readFileSync('../../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy root adaptor proxy...");
    let rootAdaptorProxy = await helper.deployRootContract(rootAdaptorProxyObj, adminWallet, rootAdaptorImpl.address, proxyAdmin.address, []);
    console.log("Transaction submitted: ", JSON.stringify(rootAdaptorProxy.deployTransaction, null, 2));
    await helper.waitForReceipt(rootAdaptorProxy.deployTransaction.hash, rootProvider);
    console.log("Deployed to ROOT_ADAPTOR_PROXY_ADDRESS: ", rootAdaptorProxy.address);

    let contractData = {
        ROOT_BRIDGE_ADDRESS: rootBridgeProxy.address,
        ROOT_ADAPTOR_ADDRESS: rootAdaptorProxy.address,
        ROOT_TOKEN_TEMPLATE: rootTokenTemplate.address,
    };
    fs.writeFileSync(".root.bridge.contracts.json", JSON.stringify(contractData, null, 2));
}