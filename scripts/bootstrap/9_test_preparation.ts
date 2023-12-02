// Prepare for test
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { deployRootContract, getContract, getRootContracts, requireEnv, saveRootContracts, waitForConfirmation, waitForReceipt } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";

async function run() {
    console.log("=======Start Test Preparation=======");

    // Check environment variables
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let testAccountKey = requireEnv("TEST_ACCOUNT_SECRET");

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

    let rootTestWallet = new ethers.Wallet(testAccountKey, rootProvider);

    let rootContracts = getRootContracts();
    let rootBridge = getContract("RootERC20BridgeFlowRate", rootContracts.ROOT_BRIDGE_ADDRESS, rootProvider);

    // Execute
    console.log("Prepare test in...");
    await waitForConfirmation();

    // Deploy a custom token
    let rootCustomToken;
    if (rootContracts.ROOT_TEST_CUSTOM_TOKEN != "") {
        console.log("Root test custom token has already been deployed to: " + rootContracts.ROOT_TEST_CUSTOM_TOKEN + ", skip.");
        rootCustomToken = getContract("ERC20PresetMinterPauser", rootContracts.ROOT_TEST_CUSTOM_TOKEN, rootProvider);
    } else {
        console.log("Deploy root test custom token...");
        rootCustomToken = await deployRootContract("ERC20PresetMinterPauser", rootDeployerWallet, null, "Custom Token", "CTK");
        await waitForReceipt(rootCustomToken.deployTransaction.hash, rootProvider);
        console.log("Custom token deployed to: ", rootCustomToken)
    }
    rootContracts.ROOT_TEST_CUSTOM_TOKEN=rootCustomToken.address;
    saveRootContracts(rootContracts);
    console.log("Deployed to ROOT_TEST_CUSTOM_TOKEN: ", rootCustomToken.address);

    // Mint tokens
    console.log("Mint tokens...");
    let resp = await rootCustomToken.connect(rootDeployerWallet).mint(rootTestWallet.address, ethers.utils.parseEther("1000.0").toBigInt());
    await waitForReceipt(resp.hash, rootProvider);

    console.log("Set rate control...");
    // Set rate control
    resp = await rootBridge.connect(rootDeployerWallet).setRateControlThreshold(
        rootCustomToken.address,
        ethers.utils.parseEther("20016.0"),
        ethers.utils.parseEther("5.56"),
        ethers.utils.parseEther("10008.0")
    );
    await waitForReceipt(resp.hash, rootProvider);

    console.log("=======End Test Preparation=======");
}
run();