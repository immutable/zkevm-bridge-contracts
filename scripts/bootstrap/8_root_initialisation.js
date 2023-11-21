// Initialise root contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')
const fs = require('fs');

async function run() {
    // Check environment variables
    let childChainName = helper.requireEnv("CHILD_CHAIN_NAME");
    let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
    let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
    let rootDeployerSecret = helper.requireEnv("ROOT_DEPLOYER_SECRET");
    let rootBridgeDefaultAdmin = helper.requireEnv("ROOT_BRIDGE_DEFAULT_ADMIN");
    let rootBridgePauser = helper.requireEnv("ROOT_BRIDGE_PAUSER");
    let rootBridgeUnpauser = helper.requireEnv("ROOT_BRIDGE_UNPAUSER");
    let rootBridgeVariableManager = helper.requireEnv("ROOT_BRIDGE_VARIABLE_MANAGER");
    let rootBridgeAdaptorManager = helper.requireEnv("ROOT_BRIDGE_ADAPTOR_MANAGER");
    let rootAdaptorDefaultAdmin = helper.requireEnv("ROOT_ADAPTOR_DEFAULT_ADMIN");
    let rootAdaptorBridgeManager = helper.requireEnv("ROOT_ADAPTOR_BRIDGE_MANAGER");
    let rootAdaptorGasServiceManager = helper.requireEnv("ROOT_ADAPTOR_GAS_SERVICE_MANAGER");
    let rootAdaptorTargetManager = helper.requireEnv("ROOT_ADAPTOR_TARGET_MANAGER");
    let rootGasServiceAddr = helper.requireEnv("ROOT_GAS_SERVICE_ADDRESS");
    let rootIMXAddr = helper.requireEnv("ROOT_IMX_ADDR");
    let rootWETHAddr = helper.requireEnv("ROOT_WETH_ADDR");
    let imxDepositLimit = helper.requireEnv("IMX_DEPOSIT_LIMIT");

    // Read from contract file.
    let data = fs.readFileSync(".child.bridge.contracts.json", 'utf-8');
    let childContracts = JSON.parse(data);
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
    let childAdaptorAddr = childContracts.CHILD_ADAPTOR_ADDRESS;
    data = fs.readFileSync(".root.bridge.contracts.json", 'utf-8');
    let rootContracts = JSON.parse(data);
    let rootBridgeAddr = rootContracts.ROOT_BRIDGE_ADDRESS;
    let rootAdaptorAddr = rootContracts.ROOT_ADAPTOR_ADDRESS;
    let rootTemplateAddr = rootContracts.ROOT_TOKEN_TEMPLATE;

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
    console.log("Initialise root contracts in...");
    await helper.waitForConfirmation();

    // Initialise root bridge
    let rootBridgeObj = JSON.parse(fs.readFileSync('../../out/RootERC20Bridge.sol/RootERC20Bridge.json', 'utf8'));
    console.log("Initialise root bridge...");
    let rootBridge = new ethers.Contract(rootBridgeAddr, rootBridgeObj.abi, rootProvider);
    let resp = await rootBridge.connect(adminWallet).initialize(
        {
            defaultAdmin: rootBridgeDefaultAdmin,
            pauser: rootBridgePauser,
            unpauser: rootBridgeUnpauser,
            variableManager: rootBridgeVariableManager,
            adaptorManager: rootBridgeAdaptorManager,
        },
        rootAdaptorAddr,
        childBridgeAddr,
        ethers.utils.getAddress(childAdaptorAddr),
        rootTemplateAddr,
        rootIMXAddr,
        rootWETHAddr,
        childChainName,
        ethers.utils.parseEther(imxDepositLimit));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // Initialise root adaptor
    let rootAdaptorObj = JSON.parse(fs.readFileSync('../../out/RootAxelarBridgeAdaptor.sol/RootAxelarBridgeAdaptor.json', 'utf8'));
    console.log("Initialise root adaptor...");
    let rootAdaptor = new ethers.Contract(rootAdaptorAddr, rootAdaptorObj.abi, rootProvider);
    resp = await rootAdaptor.connect(adminWallet).initialize(
        {
            defaultAdmin: rootAdaptorDefaultAdmin,
            bridgeManager: rootAdaptorBridgeManager,
            gasServiceManager: rootAdaptorGasServiceManager,
            targetManager: rootAdaptorTargetManager,
        },
        rootBridgeAddr, 
        childChainName, 
        rootGasServiceAddr);
    await helper.waitForReceipt(resp.hash, rootProvider);
}
run();