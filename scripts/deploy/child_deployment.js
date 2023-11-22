// Deploy child contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')
const fs = require('fs');

exports.deployChildContracts = async () => {
    // Check environment variables
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let childDeployerSecret = helper.requireEnv("CHILD_DEPLOYER_SECRET");
    let childGatewayAddr = helper.requireEnv("CHILD_GATEWAY_ADDRESS");
    let childProxyAdmin = helper.requireEnv("CHILD_PROXY_ADMIN");

    // Get admin address
    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let adminWallet;
    if (childDeployerSecret == "ledger") {
        adminWallet = new LedgerSigner(childProvider);
    } else {
        adminWallet = new ethers.Wallet(childDeployerSecret, childProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Deployer address is: ", adminAddr);

    // Execute 
    console.log("Deploy child contracts in...");
    await helper.waitForConfirmation();

    // Deploy child token template
    let childTokenTemplateObj = JSON.parse(fs.readFileSync('../../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
    console.log("Deploy child token template...");
    let childTokenTemplate = await helper.deployChildContract(childTokenTemplateObj, adminWallet);
    await helper.waitForReceipt(childTokenTemplate.deployTransaction.hash, childProvider);
    // Initialise template
    let [priorityFee, maxFee] = await helper.getFee(adminWallet);
    let resp = await childTokenTemplate.connect(adminWallet).initialize("000000000000000000000000000000000000007B", "TEMPLATE", "TPT", 18, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await helper.waitForReceipt(resp.hash, childProvider);
    console.log("Deployed to CHILD_TOKEN_TEMPLATE: ", childTokenTemplate.address);

    // Deploy wrapped IMX
    let wrappedIMXObj = JSON.parse(fs.readFileSync('../../out/WIMX.sol/WIMX.json', 'utf8'));
    console.log("Deploy wrapped IMX...");
    let wrappedIMX = await helper.deployChildContract(wrappedIMXObj, adminWallet);
    await helper.waitForReceipt(wrappedIMX.deployTransaction.hash, childProvider);
    console.log("Deployed to WRAPPED_IMX_ADDRESS: ", wrappedIMX.address);

    // Deploy proxy admin
    let proxyAdminObj = JSON.parse(fs.readFileSync('../../out/ProxyAdmin.sol/ProxyAdmin.json', 'utf8'));
    console.log("Deploy proxy admin...");
    let proxyAdmin = await helper.deployChildContract(proxyAdminObj, adminWallet);
    await helper.waitForReceipt(proxyAdmin.deployTransaction.hash, childProvider);
    // Change owner
    [priorityFee, maxFee] = await helper.getFee(adminWallet);
    resp = await proxyAdmin.connect(adminWallet).transferOwnership(childProxyAdmin, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await helper.waitForReceipt(resp.hash, childProvider);
    console.log("Deployed to CHILD_PROXY_ADMIN: ", proxyAdmin.address);

    // Deploy child bridge impl
    let childBridgeImplObj = JSON.parse(fs.readFileSync('../../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    console.log("Deploy child bridge impl...");
    let childBridgeImpl = await helper.deployChildContract(childBridgeImplObj, adminWallet);
    await helper.waitForReceipt(childBridgeImpl.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_BRIDGE_IMPL_ADDRESS: ", childBridgeImpl.address);
    
    // Deploy child bridge proxy
    let childBridgeProxyObj = JSON.parse(fs.readFileSync('../../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy child bridge proxy...");
    let childBridgeProxy = await helper.deployChildContract(childBridgeProxyObj, adminWallet, childBridgeImpl.address, proxyAdmin.address, []);
    await helper.waitForReceipt(childBridgeProxy.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_BRIDGE_PROXY_ADDRESS: ", childBridgeProxy.address);
    
    // Deploy child adaptor impl
    let childAdaptorImplObj = JSON.parse(fs.readFileSync('../../out/ChildAxelarBridgeAdaptor.sol/ChildAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Deploy child adaptor impl...");
    let childAdaptorImpl = await helper.deployChildContract(childAdaptorImplObj, adminWallet, childGatewayAddr);
    await helper.waitForReceipt(childAdaptorImpl.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_ADAPTOR_IMPL_ADDRESS: ", childAdaptorImpl.address);
    
    // Deploy child adaptor proxy
    let childAdaptorProxyObj = JSON.parse(fs.readFileSync('../../out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json', 'utf8'));
    console.log("Deploy child adaptor proxy...");
    let childAdaptorProxy = await helper.deployChildContract(childAdaptorProxyObj, adminWallet, childAdaptorImpl.address, proxyAdmin.address, []);
    await helper.waitForReceipt(childAdaptorProxy.deployTransaction.hash, childProvider);
    console.log("Deployed to CHILD_ADAPTOR_PROXY_ADDRESS: ", childAdaptorProxy.address);

    let contractData = {
        CHILD_BRIDGE_ADDRESS: childBridgeProxy.address,
        CHILD_ADAPTOR_ADDRESS: childAdaptorProxy.address,
        WRAPPED_IMX_ADDRESS: wrappedIMX.address,
        CHILD_TOKEN_TEMPLATE: childTokenTemplate.address,
    };
    fs.writeFileSync(".child.bridge.contracts.json", JSON.stringify(contractData, null, 2));
}