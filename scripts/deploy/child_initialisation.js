// Initialise child contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')
const fs = require('fs');

exports.initialiseChildContracts = async () => {
    let rootChainName = helper.requireEnv("ROOT_CHAIN_NAME");
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let adminEOAAddr = helper.requireEnv("CHILD_ADMIN_ADDR");
    let childBridgeDefaultAdmin = helper.requireEnv("CHILD_BRIDGE_DEFAULT_ADMIN");
    let childBridgePauser = helper.requireEnv("CHILD_BRIDGE_PAUSER");
    let childBridgeUnpauser = helper.requireEnv("CHILD_BRIDGE_UNPAUSER");
    let childBridgeAdaptorManager = helper.requireEnv("CHILD_BRIDGE_ADAPTOR_MANAGER");
    let childBridgeTreasuryManager = helper.requireEnv("CHILD_BRIDGE_TREASURY_MANAGER");
    let childAdaptorDefaultAdmin = helper.requireEnv("CHILD_ADAPTOR_DEFAULT_ADMIN");
    let childAdaptorBridgeManager = helper.requireEnv("CHILD_ADAPTOR_BRIDGE_MANAGER");
    let childAdaptorGasServiceManager = helper.requireEnv("CHILD_ADAPTOR_GAS_SERVICE_MANAGER");
    let childAdaptorTargetManager = helper.requireEnv("CHILD_ADAPTOR_TARGET_MANAGER");
    let childDeployerSecret = helper.requireEnv("CHILD_DEPLOYER_SECRET");
    let childGasServiceAddr = helper.requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let multisigAddr = helper.requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootIMXAddr = helper.requireEnv("ROOT_IMX_ADDR");

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
        adminWallet = new LedgerSigner(childProvider);
    } else {
        adminWallet = new ethers.Wallet(childDeployerSecret, childProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Deployer address is: ", adminAddr);

    // Execute
    console.log("Initialise child contracts in...");
    await helper.waitForConfirmation();

    // Initialise child bridge
    let childBridgeObj = JSON.parse(fs.readFileSync('../../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
    console.log("Initialise child bridge...");
    let childBridge = new ethers.Contract(childBridgeAddr, childBridgeObj.abi, childProvider);
    let [priorityFee, maxFee] = await helper.getFee(adminWallet);
    let resp = await childBridge.connect(adminWallet).initialize(
        {
            defaultAdmin: childBridgeDefaultAdmin,
            pauser: childBridgePauser,
            unpauser: childBridgeUnpauser,
            adaptorManager: childBridgeAdaptorManager,
            treasuryManager: childBridgeTreasuryManager,
        },
        childAdaptorAddr, 
        ethers.utils.getAddress(rootAdaptorAddr), 
        childTemplateAddr, 
        rootChainName, 
        rootIMXAddr, 
        childWIMXAddr,
        multisigAddr,
        adminEOAAddr,
    {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await helper.waitForReceipt(resp.hash, childProvider);

    // Initialise child adaptor
    let childAdaptorObj = JSON.parse(fs.readFileSync('../../out/ChildAxelarBridgeAdaptor.sol/ChildAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Initialise child adaptor...");
    let childAdaptor = new ethers.Contract(childAdaptorAddr, childAdaptorObj.abi, childProvider);
    [priorityFee, maxFee] = await helper.getFee(adminWallet);
    resp = await childAdaptor.connect(adminWallet).initialize(
        {
            defaultAdmin: childAdaptorDefaultAdmin,
            bridgeManager: childAdaptorBridgeManager,
            gasServiceManager: childAdaptorGasServiceManager,
            targetManager: childAdaptorTargetManager,
        },
        rootChainName, 
        childBridgeAddr, 
        childGasServiceAddr,
    {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
    await helper.waitForReceipt(resp.hash, childProvider);
}