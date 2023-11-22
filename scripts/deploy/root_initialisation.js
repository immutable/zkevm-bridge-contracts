// Initialise root contracts
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')
const fs = require('fs');

exports.initialiseRootContracts = async() => {
    // Check environment variables
    let childChainName = helper.requireEnv("CHILD_CHAIN_NAME");
    let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
    let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
    let rootDeployerSecret = helper.requireEnv("ROOT_DEPLOYER_SECRET");
    let rootRateAdminSecret = helper.requireEnv("ROOT_BRIDGE_RATE_ADMIN_SECRET");
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
    let rateLimitIMXCap = helper.requireEnv("RATE_LIMIT_IMX_CAPACITY");
    let rateLimitIMXRefill = helper.requireEnv("RATE_LIMIT_IMX_REFILL_RATE");
    let rateLimitIMXLargeThreshold = helper.requireEnv("RATE_LIMIT_IMX_LARGE_THRESHOLD");
    let rateLimitETHCap = helper.requireEnv("RATE_LIMIT_ETH_CAPACITY");
    let rateLimitETHRefill = helper.requireEnv("RATE_LIMIT_ETH_REFILL_RATE");
    let rateLimitETHLargeThreshold = helper.requireEnv("RATE_LIMIT_ETH_LARGE_THRESHOLD");
    let rateLimitUSDCAddr = helper.requireEnv("RATE_LIMIT_USDC_ADDR");
    let rateLimitUSDCCap = helper.requireEnv("RATE_LIMIT_USDC_CAPACITY");
    let rateLimitUSDCRefill = helper.requireEnv("RATE_LIMIT_USDC_REFILL_RATE");
    let rateLimitUSDCLargeThreshold = helper.requireEnv("RATE_LIMIT_USDC_LARGE_THRESHOLD");
    let rateLimitGUAddr = helper.requireEnv("RATE_LIMIT_GU_ADDR");
    let rateLimitGUCap = helper.requireEnv("RATE_LIMIT_GU_CAPACITY");
    let rateLimitGURefill = helper.requireEnv("RATE_LIMIT_GU_REFILL_RATE");
    let rateLimitGULargeThreshold = helper.requireEnv("RATE_LIMIT_GU_LARGE_THRESHOLD");
    let rateLimitCheckMateAddr = helper.requireEnv("RATE_LIMIT_CHECKMATE_ADDR");
    let rateLimitCheckMateCap = helper.requireEnv("RATE_LIMIT_CHECKMATE_CAPACITY");
    let rateLimitCheckMateRefill = helper.requireEnv("RATE_LIMIT_CHECKMATE_REFILL_RATE");
    let rateLimitCheckMateLargeThreshold = helper.requireEnv("RATE_LIMIT_CHECKMATE_LARGE_THRESHOLD");
    let rateLimitGOGAddr = helper.requireEnv("RATE_LIMIT_GOG_ADDR");
    let rateLimitGOGCap = helper.requireEnv("RATE_LIMIT_GOG_CAPACITY");
    let rateLimitGOGRefill = helper.requireEnv("RATE_LIMIT_GOG_REFILL_RATE");
    let rateLimitGOGLargeThreshold = helper.requireEnv("RATE_LIMIT_GOG_LARGE_THRESHOLD");

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

    // Get rate admin address
    let rateAdminWallet;
    if (rootRateAdminSecret == "ledger") {
        rateAdminWallet = new LedgerSigner(rateAdminWallet);
    } else {
        rateAdminWallet = new ethers.Wallet(rootRateAdminSecret, rootProvider);
    }
    let rateAdminAddr = await rateAdminWallet.getAddress();
    console.log("Rate admin address is: ", rateAdminAddr);


    // Execute
    console.log("Initialise root contracts in...");
    await helper.waitForConfirmation();

    // Initialise root bridge
    let rootBridgeObj = JSON.parse(fs.readFileSync('../../out/RootERC20BridgeFlowRate.sol/RootERC20BridgeFlowRate.json', 'utf8'));
    console.log("Initialise root bridge...");
    let rootBridge = new ethers.Contract(rootBridgeAddr, rootBridgeObj.abi, rootProvider);
    let resp = await rootBridge.connect(adminWallet)["initialize((address,address,address,address,address),address,address,string,address,address,address,string,uint256,address)"](
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
        ethers.utils.parseEther(imxDepositLimit),
        rateAdminAddr);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // Configure rate
    // IMX
    console.log("Configure rate limiting for IMX...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rootIMXAddr,
        ethers.utils.parseEther(rateLimitIMXCap),
        ethers.utils.parseEther(rateLimitIMXRefill),
        ethers.utils.parseEther(rateLimitIMXLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // ETH
    console.log("Configure rate limiting for ETH...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        await rootBridge.NATIVE_ETH(),
        ethers.utils.parseEther(rateLimitETHCap),
        ethers.utils.parseEther(rateLimitETHRefill),
        ethers.utils.parseEther(rateLimitETHLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // USDC
    console.log("Configure rate limiting for USDC...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitUSDCAddr,
        ethers.utils.parseEther(rateLimitUSDCCap),
        ethers.utils.parseEther(rateLimitUSDCRefill),
        ethers.utils.parseEther(rateLimitUSDCLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // GU
    console.log("Configure rate limiting for GU...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitGUAddr,
        ethers.utils.parseEther(rateLimitGUCap),
        ethers.utils.parseEther(rateLimitGURefill),
        ethers.utils.parseEther(rateLimitGULargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // Checkmate
    console.log("Configure rate limiting for CheckMate...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitCheckMateAddr,
        ethers.utils.parseEther(rateLimitCheckMateCap),
        ethers.utils.parseEther(rateLimitCheckMateRefill),
        ethers.utils.parseEther(rateLimitCheckMateLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);

    // GOG
    console.log("Configure rate limiting for GOG...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitGOGAddr,
        ethers.utils.parseEther(rateLimitGOGCap),
        ethers.utils.parseEther(rateLimitGOGRefill),
        ethers.utils.parseEther(rateLimitGOGLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
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
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await helper.waitForReceipt(resp.hash, rootProvider);
}