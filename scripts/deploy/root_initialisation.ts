// Initialise root contracts
import * as dotenv from "dotenv";
dotenv.config();
import { ethers, utils } from "ethers";
import { requireEnv, waitForConfirmation, waitForReceipt, getContract, getChildContracts, getRootContracts } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";

export async function initialiseRootContracts() {
    // Check environment variables
    let childChainName = requireEnv("CHILD_CHAIN_NAME");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let rootGasServiceAddr = requireEnv("ROOT_GAS_SERVICE_ADDRESS");
    let rootIMXAddr = requireEnv("ROOT_IMX_ADDR");
    let rootWETHAddr = requireEnv("ROOT_WETH_ADDR");
    let imxDepositLimit = requireEnv("IMX_DEPOSIT_LIMIT");
    let rootPrivilegedMultisig = requireEnv("ROOT_PRIVILEGED_MULTISIG_ADDR");
    let rootBreakglass = requireEnv("ROOT_BREAKGLASS_ADDR");
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
    let childContracts = getChildContracts();
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
    let childAdaptorAddr = childContracts.CHILD_ADAPTOR_ADDRESS;
    let rootContracts = getRootContracts();
    let rootBridgeAddr = rootContracts.ROOT_BRIDGE_ADDRESS;
    let rootAdaptorAddr = rootContracts.ROOT_ADAPTOR_ADDRESS;
    let rootTemplateAddr = rootContracts.ROOT_TOKEN_TEMPLATE;

    // Get deployer address
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
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
    console.log("Initialise root contracts in...");
    await waitForConfirmation();

    // Initialise root bridge
    console.log("Initialise root bridge...");
    let rootBridge = getContract("RootERC20BridgeFlowRate", rootBridgeAddr, rootProvider);
    let resp = await rootBridge.connect(rootDeployerWallet)["initialize((address,address,address,address,address),address,address,address,address,address,uint256,address)"](
        {
            defaultAdmin: deployerAddr,
            pauser: rootBreakglass,
            unpauser: rootPrivilegedMultisig,
            variableManager: rootPrivilegedMultisig,
            adaptorManager: rootPrivilegedMultisig,
        },
        rootAdaptorAddr,
        childBridgeAddr,
        rootTemplateAddr,
        rootIMXAddr,
        rootWETHAddr,
        ethers.utils.parseEther(imxDepositLimit),
        deployerAddr);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // Configure rate
    // IMX
    console.log("Configure rate limiting for IMX...")
    resp = await rootBridge.connect(rootDeployerWallet).setRateControlThreshold(
        rootIMXAddr,
        ethers.utils.parseEther(rateLimitIMXCap),
        ethers.utils.parseEther(rateLimitIMXRefill),
        ethers.utils.parseEther(rateLimitIMXLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // ETH
    console.log("Configure rate limiting for ETH...")
    resp = await rootBridge.connect(rootDeployerWallet).setRateControlThreshold(
        await rootBridge.NATIVE_ETH(),
        ethers.utils.parseEther(rateLimitETHCap),
        ethers.utils.parseEther(rateLimitETHRefill),
        ethers.utils.parseEther(rateLimitETHLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // USDC
    console.log("Configure rate limiting for USDC...")
    resp = await rootBridge.connect(rootDeployerWallet).setRateControlThreshold(
        rateLimitUSDCAddr,
        ethers.utils.parseEther(rateLimitUSDCCap),
        ethers.utils.parseEther(rateLimitUSDCRefill),
        ethers.utils.parseEther(rateLimitUSDCLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // GU
    console.log("Configure rate limiting for GU...")
    resp = await rootBridge.connect(rootDeployerWallet).setRateControlThreshold(
        rateLimitGUAddr,
        ethers.utils.parseEther(rateLimitGUCap),
        ethers.utils.parseEther(rateLimitGURefill),
        ethers.utils.parseEther(rateLimitGULargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // Checkmate
    console.log("Configure rate limiting for CheckMate...")
    resp = await rootBridge.connect(rootDeployerWallet).setRateControlThreshold(
        rateLimitCheckMateAddr,
        ethers.utils.parseEther(rateLimitCheckMateCap),
        ethers.utils.parseEther(rateLimitCheckMateRefill),
        ethers.utils.parseEther(rateLimitCheckMateLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // GOG
    console.log("Configure rate limiting for GOG...")
    resp = await rootBridge.connect(rootDeployerWallet).setRateControlThreshold(
        rateLimitGOGAddr,
        ethers.utils.parseEther(rateLimitGOGCap),
        ethers.utils.parseEther(rateLimitGOGRefill),
        ethers.utils.parseEther(rateLimitGOGLargeThreshold)
    );
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // Grant roles
    console.log("Grant RATE_CONTROL_ROLE to multisig...")
    resp = await rootBridge.connect(rootDeployerWallet).grantRole(utils.keccak256(utils.toUtf8Bytes("RATE")), rootPrivilegedMultisig);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    console.log("Grant DEFAULT_ADMIN to multisig...")
    resp = await rootBridge.connect(rootDeployerWallet).grantRole(await rootBridge.DEFAULT_ADMIN_ROLE(), rootPrivilegedMultisig);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);

    // Print summary
    console.log("Does multisig have DEFAULT_ADMIN: ", await rootBridge.hasRole(await rootBridge.DEFAULT_ADMIN_ROLE(), rootPrivilegedMultisig));
    console.log("Does deployer have DEFAULT_ADMIN: ", await rootBridge.hasRole(await rootBridge.DEFAULT_ADMIN_ROLE(), deployerAddr));
    console.log("Does multisig have RATE_ADMIN: ", await rootBridge.hasRole(utils.keccak256(utils.toUtf8Bytes("RATE")), rootPrivilegedMultisig));
    console.log("Does deployer have RATE_ADMIN: ", await rootBridge.hasRole(utils.keccak256(utils.toUtf8Bytes("RATE")), deployerAddr));

    // Initialise root adaptor
    console.log("Initialise root adaptor...");
    let rootAdaptor = getContract("RootAxelarBridgeAdaptor", rootAdaptorAddr, rootProvider);
    resp = await rootAdaptor.connect(rootDeployerWallet).initialize(
        {
            defaultAdmin: rootPrivilegedMultisig,
            bridgeManager: rootPrivilegedMultisig,
            gasServiceManager: rootPrivilegedMultisig,
            targetManager: rootPrivilegedMultisig,
        },
        rootBridgeAddr, 
        childChainName,
        childAdaptorAddr,
        rootGasServiceAddr);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2));
    await waitForReceipt(resp.hash, rootProvider);
}