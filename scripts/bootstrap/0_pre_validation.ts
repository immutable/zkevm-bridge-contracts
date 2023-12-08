// Pre validation
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, hasDuplicates } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";

// The total supply of IMX
const TOTAL_SUPPLY = "2000000000";

// The contract ABI of IMX on L1.
const IMX_ABI = `[{"inputs":[{"internalType":"address","name":"minter","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"previousAdminRole","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"newAdminRole","type":"bytes32"}],"name":"RoleAdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleGranted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleRevoked","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"DEFAULT_ADMIN_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"MINTER_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"cap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"}],"name":"getRoleAdmin","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"grantRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"renounceRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"revokeRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]`;

function tryThrow(errorMsg: string) {
    if (process.env["THROW_ON_FAIL"] != null) {
        throw(errorMsg);
    } else {
        console.log(errorMsg);
    }
}

async function run() {
    console.log("=======Start Pre Validation=======");

    // Check environment variables
    requireEnv("CHILD_CHAIN_NAME");
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    requireEnv("ROOT_CHAIN_NAME");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let deployerAddr = requireEnv("DEPLOYER_ADDR");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let reservedDeployerAddr = requireEnv("NONCE_RESERVED_DEPLOYER_ADDR");
    let reservedDeployerSecret = requireEnv("NONCE_RESERVED_DEPLOYER_SECRET");
    Number(requireEnv("NONCE_RESERVED"));
    let rootIMXAddr = requireEnv("ROOT_IMX_ADDR");
    let rootWETHAddr = requireEnv("ROOT_WETH_ADDR");
    let axelarEOA = requireEnv("AXELAR_EOA");
    let passportDeployer = requireEnv("PASSPORT_NONCE_RESERVER_ADDR");
    let axelarFund = requireEnv("AXELAR_FUND");
    let childDeployerFund = requireEnv("CHILD_DEPLOYER_FUND");
    let childReservedDeployerFund = requireEnv("CHILD_NONCE_RESERVED_DEPLOYER_FUND");
    let passportDeployerFund = requireEnv("PASSPORT_NONCE_RESERVER_FUND");
    let imxDepositLimit = requireEnv("IMX_DEPOSIT_LIMIT");
    requireEnv("RATE_LIMIT_IMX_CAPACITY");
    requireEnv("RATE_LIMIT_IMX_REFILL_RATE");
    requireEnv("RATE_LIMIT_IMX_LARGE_THRESHOLD");
    requireEnv("RATE_LIMIT_ETH_CAPACITY");
    requireEnv("RATE_LIMIT_ETH_REFILL_RATE");
    requireEnv("RATE_LIMIT_ETH_LARGE_THRESHOLD");
    requireEnv("RATE_LIMIT_USDC_ADDR");
    requireEnv("RATE_LIMIT_USDC_CAPACITY");
    requireEnv("RATE_LIMIT_USDC_REFILL_RATE");
    requireEnv("RATE_LIMIT_USDC_LARGE_THRESHOLD");
    requireEnv("RATE_LIMIT_GU_ADDR");
    requireEnv("RATE_LIMIT_GU_CAPACITY");
    requireEnv("RATE_LIMIT_GU_REFILL_RATE");
    requireEnv("RATE_LIMIT_GU_LARGE_THRESHOLD");
    requireEnv("RATE_LIMIT_CHECKMATE_ADDR");
    requireEnv("RATE_LIMIT_CHECKMATE_CAPACITY");
    requireEnv("RATE_LIMIT_CHECKMATE_REFILL_RATE");
    requireEnv("RATE_LIMIT_CHECKMATE_LARGE_THRESHOLD");
    requireEnv("RATE_LIMIT_GOG_ADDR");
    requireEnv("RATE_LIMIT_GOG_CAPACITY");
    requireEnv("RATE_LIMIT_GOG_REFILL_RATE");
    requireEnv("RATE_LIMIT_GOG_LARGE_THRESHOLD");

    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let deployerWallet;
    if (deployerSecret == "ledger") {
        let index = requireEnv("DEPLOYER_LEDGER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        deployerWallet = new LedgerSigner(childProvider, derivationPath);
    } else {
        deployerWallet = new ethers.Wallet(deployerSecret, childProvider);
    }
    let actualDeployerAddress = await deployerWallet.getAddress();
    if (deployerWallet instanceof LedgerSigner) {
        deployerWallet.close();
    }
    
    let reservedWallet;
    if (reservedDeployerSecret == "ledger") {
        let index = requireEnv("NONCE_RESERVED_DEPLOYER_INDEX");
        const derivationPath = `m/44'/60'/${parseInt(index)}'/0/0`;
        reservedWallet = new LedgerSigner(childProvider, derivationPath);
    } else {
        reservedWallet = new ethers.Wallet(reservedDeployerSecret, childProvider);
    }
    let actualReservedDeployerAddress = await reservedWallet.getAddress();

    // Check deployer address matches deployer addr
    if (actualDeployerAddress != deployerAddr) {
        tryThrow("Deployer addresses mismatch, expect " + deployerAddr + " actual " + actualDeployerAddress);
    }
    if (actualReservedDeployerAddress != reservedDeployerAddr) {
        tryThrow("Reserved Nonce deployer addresses mismatch, expect " + reservedDeployerAddr + " actual " + actualReservedDeployerAddress);
    }

    // Check duplicates
    if (hasDuplicates([actualDeployerAddress, actualReservedDeployerAddress, axelarEOA, passportDeployer])) {
        throw("Duplicate address detected!");
    }
    if (hasDuplicates([rootIMXAddr, rootWETHAddr])) {
        throw("Duplicate address detected!");
    }

    // Check deployer fund on root chain and child chain.
    let IMX = new ethers.Contract(rootIMXAddr, IMX_ABI, rootProvider);
    let rootDeployerETHBalance = await rootProvider.getBalance(actualDeployerAddress);
    let rootReservedDeployerETHBalance = await rootProvider.getBalance(actualReservedDeployerAddress);
    if (rootDeployerETHBalance.lt(ethers.utils.parseEther("0.1"))) {
        tryThrow("Deployer on root chain needs to have at least 0.1 ETH, got " + ethers.utils.formatEther(rootDeployerETHBalance));
    }
    if (rootReservedDeployerETHBalance.lt(ethers.utils.parseEther("0.1"))) {
        tryThrow("Reserved deployer on root chain needs to have at least 0.1 ETH, got " + ethers.utils.formatEther(rootReservedDeployerETHBalance));
    }
    let rootDeployerIMXBalance = await IMX.balanceOf(actualDeployerAddress);
    let axelarRequiredIMX = ethers.utils.parseEther(axelarFund);
    let deployerRequiredIMX = ethers.utils.parseEther(childDeployerFund);
    let reservedDeployerRequiredIMX = ethers.utils.parseEther(childReservedDeployerFund);
    let passportRequiredIMX = ethers.utils.parseEther(passportDeployerFund);
    if (axelarRequiredIMX.lt(ethers.utils.parseEther("500.0"))) {
        tryThrow("Axelar on child chain should request at least 500 IMX, got" + ethers.utils.formatEther(axelarRequiredIMX));
    }
    if (deployerRequiredIMX.lt(ethers.utils.parseEther("250.0"))) {
        tryThrow("Deployer on child chain should request at least 500 IMX, got" + ethers.utils.formatEther(deployerRequiredIMX));
    }
    if (reservedDeployerRequiredIMX.lt(ethers.utils.parseEther("100.0"))) {
        tryThrow("Reserved deployer on child chain should request at least 100 IMX, got" + ethers.utils.formatEther(reservedDeployerRequiredIMX));
    }
    if (passportRequiredIMX.lt(ethers.utils.parseEther("100.0"))) {
        tryThrow("Passport deployer on child chain should request at least 100 IMX, got" + ethers.utils.formatEther(passportRequiredIMX));
    }
    let extraIMX = ethers.utils.parseEther("100.0");
    let requiredIMX = axelarRequiredIMX.add(deployerRequiredIMX).add(reservedDeployerRequiredIMX).add(extraIMX);
    if (rootDeployerIMXBalance.lt(requiredIMX)) {
        tryThrow("Deployer on root chain needs to have at least " + ethers.utils.formatEther(requiredIMX) + " IMX, got " + ethers.utils.formatEther(rootDeployerIMXBalance));
    }
    let childDeployerIMXBalance = await childProvider.getBalance(actualDeployerAddress);
    if (!childDeployerIMXBalance.eq(ethers.utils.parseEther(TOTAL_SUPPLY))) {
        tryThrow("Deployer on child chain needs to have 2B units of pre-mined IMX, got " + ethers.utils.formatEther(childDeployerIMXBalance));
    }

    // Check IMX deposit limit
    let depositLimit = ethers.utils.parseEther(imxDepositLimit);
    if (depositLimit.gt(ethers.utils.parseEther("200000000"))) {
        tryThrow("Deposit limit should be at most 200m, got " + ethers.utils.formatEther(depositLimit));
    }
    if (depositLimit.lt(ethers.utils.parseEther("2000000"))) {
        tryThrow("Deposit limit should be at least 2m, got " + ethers.utils.formatEther(depositLimit));
    }

    console.log("=======End Pre Validation=======");
}
run();