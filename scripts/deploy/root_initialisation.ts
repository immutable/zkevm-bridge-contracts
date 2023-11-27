// Initialise root contracts
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, waitForReceipt, getContract } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import * as fs from "fs";

export async function initialiseRootContracts() {
    // Check environment variables
    let childChainName = requireEnv("CHILD_CHAIN_NAME");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let rootDeployerSecret = requireEnv("ROOT_DEPLOYER_SECRET");
    let rootRateAdminSecret = requireEnv("ROOT_BRIDGE_RATE_ADMIN_SECRET");
    let rootBridgeDefaultAdmin = requireEnv("ROOT_BRIDGE_DEFAULT_ADMIN");
    let rootBridgePauser = requireEnv("ROOT_BRIDGE_PAUSER");
    let rootBridgeUnpauser = requireEnv("ROOT_BRIDGE_UNPAUSER");
    let rootBridgeVariableManager = requireEnv("ROOT_BRIDGE_VARIABLE_MANAGER");
    let rootBridgeAdaptorManager = requireEnv("ROOT_BRIDGE_ADAPTOR_MANAGER");
    let rootAdaptorDefaultAdmin = requireEnv("ROOT_ADAPTOR_DEFAULT_ADMIN");
    let rootAdaptorBridgeManager = requireEnv("ROOT_ADAPTOR_BRIDGE_MANAGER");
    let rootAdaptorGasServiceManager = requireEnv("ROOT_ADAPTOR_GAS_SERVICE_MANAGER");
    let rootAdaptorTargetManager = requireEnv("ROOT_ADAPTOR_TARGET_MANAGER");
    let rootGasServiceAddr = requireEnv("ROOT_GAS_SERVICE_ADDRESS");
    let rootIMXAddr = requireEnv("ROOT_IMX_ADDR");
    let rootWETHAddr = requireEnv("ROOT_WETH_ADDR");
    let imxDepositLimit = requireEnv("IMX_DEPOSIT_LIMIT");
    let rateLimitIMXCap = requireEnv("RATE_LIMIT_IMX_CAPACITY");
    let rateLimitIMXRefill = requireEnv("RATE_LIMIT_IMX_REFILL_RATE");
    let rateLimitIMXLargeThreshold = requireEnv("RATE_LIMIT_IMX_LARGE_THRESHOLD");
    let rateLimitETHCap = requireEnv("RATE_LIMIT_ETH_CAPACITY");
    let rateLimitETHRefill = requireEnv("RATE_LIMIT_ETH_REFILL_RATE");
    let rateLimitETHLargeThreshold = requireEnv("RATE_LIMIT_ETH_LARGE_THRESHOLD");
    let rateLimitUSDCAddr = requireEnv("RATE_LIMIT_USDC_ADDR");
    let rateLimitUSDCCap = requireEnv("RATE_LIMIT_USDC_CAPACITY");
    let rateLimitUSDCRefill = requireEnv("RATE_LIMIT_USDC_REFILL_RATE");
    let rateLimitUSDCLargeThreshold = requireEnv("RATE_LIMIT_USDC_LARGE_THRESHOLD");
    let rateLimitGUAddr = requireEnv("RATE_LIMIT_GU_ADDR");
    let rateLimitGUCap = requireEnv("RATE_LIMIT_GU_CAPACITY");
    let rateLimitGURefill = requireEnv("RATE_LIMIT_GU_REFILL_RATE");
    let rateLimitGULargeThreshold = requireEnv("RATE_LIMIT_GU_LARGE_THRESHOLD");
    let rateLimitCheckMateAddr = requireEnv("RATE_LIMIT_CHECKMATE_ADDR");
    let rateLimitCheckMateCap = requireEnv("RATE_LIMIT_CHECKMATE_CAPACITY");
    let rateLimitCheckMateRefill = requireEnv("RATE_LIMIT_CHECKMATE_REFILL_RATE");
    let rateLimitCheckMateLargeThreshold = requireEnv("RATE_LIMIT_CHECKMATE_LARGE_THRESHOLD");
    let rateLimitGOGAddr = requireEnv("RATE_LIMIT_GOG_ADDR");
    let rateLimitGOGCap = requireEnv("RATE_LIMIT_GOG_CAPACITY");
    let rateLimitGOGRefill = requireEnv("RATE_LIMIT_GOG_REFILL_RATE");
    let rateLimitGOGLargeThreshold = requireEnv("RATE_LIMIT_GOG_LARGE_THRESHOLD");

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
        let index = requireEnv("ROOT_DEPLOYER_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        adminWallet = new LedgerSigner(rootProvider, derivationPath);
    } else {
        adminWallet = new ethers.Wallet(rootDeployerSecret, rootProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Deployer address is: ", adminAddr);

    // Get rate admin address
    let rateAdminWallet;
    if (rootRateAdminSecret == "ledger") {
        let index = requireEnv("ROOT_BRIDGE_RATE_ADMIN_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        rateAdminWallet = new LedgerSigner(rootProvider, derivationPath);
    } else {
        rateAdminWallet = new ethers.Wallet(rootRateAdminSecret, rootProvider);
    }
    let rateAdminAddr = await rateAdminWallet.getAddress();
    console.log("Rate admin address is: ", rateAdminAddr);


    // Execute
    console.log("Initialise root contracts in...");
    await waitForConfirmation();

    // Initialise root bridge
    console.log("Initialise root bridge...");
    let rootBridge = getContract("RootERC20BridgeFlowRate", rootBridgeAddr, rootProvider);
    let resp = await rootBridge.connect(adminWallet)["initialize((address,address,address,address,address),address,address,address,address,address,uint256,address)"](
        {
            defaultAdmin: rootBridgeDefaultAdmin,
            pauser: rootBridgePauser,
            unpauser: rootBridgeUnpauser,
            variableManager: rootBridgeVariableManager,
            adaptorManager: rootBridgeAdaptorManager,
        },
        rootAdaptorAddr,
        childBridgeAddr,
        rootTemplateAddr,
        rootIMXAddr,
        rootWETHAddr,
        ethers.utils.parseEther(imxDepositLimit),
        rateAdminAddr);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

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
    await waitForReceipt(resp.hash, rootProvider);

    // ETH
    console.log("Configure rate limiting for ETH...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        await rootBridge.NATIVE_ETH(),
        ethers.utils.parseEther(rateLimitETHCap),
        ethers.utils.parseEther(rateLimitETHRefill),
        ethers.utils.parseEther(rateLimitETHLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // USDC
    console.log("Configure rate limiting for USDC...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitUSDCAddr,
        ethers.utils.parseEther(rateLimitUSDCCap),
        ethers.utils.parseEther(rateLimitUSDCRefill),
        ethers.utils.parseEther(rateLimitUSDCLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // GU
    console.log("Configure rate limiting for GU...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitGUAddr,
        ethers.utils.parseEther(rateLimitGUCap),
        ethers.utils.parseEther(rateLimitGURefill),
        ethers.utils.parseEther(rateLimitGULargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // Checkmate
    console.log("Configure rate limiting for CheckMate...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitCheckMateAddr,
        ethers.utils.parseEther(rateLimitCheckMateCap),
        ethers.utils.parseEther(rateLimitCheckMateRefill),
        ethers.utils.parseEther(rateLimitCheckMateLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // GOG
    console.log("Configure rate limiting for GOG...")
    resp = await rootBridge.connect(rateAdminWallet).setRateControlThreshold(
        rateLimitGOGAddr,
        ethers.utils.parseEther(rateLimitGOGCap),
        ethers.utils.parseEther(rateLimitGOGRefill),
        ethers.utils.parseEther(rateLimitGOGLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // Initialise root adaptor
    console.log("Initialise root adaptor...");
    let rootAdaptor = getContract("RootAxelarBridgeAdaptor", rootAdaptorAddr, rootProvider);
    resp = await rootAdaptor.connect(adminWallet).initialize(
        {
            defaultAdmin: rootAdaptorDefaultAdmin,
            bridgeManager: rootAdaptorBridgeManager,
            gasServiceManager: rootAdaptorGasServiceManager,
            targetManager: rootAdaptorTargetManager,
        },
        rootBridgeAddr, 
        childChainName,
        childAdaptorAddr,
        rootGasServiceAddr);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);
}