// IMX rebalancing
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, waitForConfirmation, waitForReceipt, getFee, hasDuplicates, getChildContracts, getRootContracts } from "../helpers/helpers";
import { LedgerSigner } from "../helpers/ledger_signer";
import { RetryProvider } from "../helpers/retry";

// The total supply of IMX
const TOTAL_SUPPLY = "2000000000";

// The contract ABI of IMX on L1.
const IMX_ABI = `[{"inputs":[{"internalType":"address","name":"minter","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"previousAdminRole","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"newAdminRole","type":"bytes32"}],"name":"RoleAdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleGranted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleRevoked","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"DEFAULT_ADMIN_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"MINTER_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"cap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"}],"name":"getRoleAdmin","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"grantRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"renounceRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"revokeRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]`;

async function run() {
    console.log("=======Start IMX Rebalancing=======");

    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let deployerSecret = requireEnv("DEPLOYER_SECRET");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootIMXAddr = requireEnv("ROOT_IMX_ADDR");

    // Read from contract file.
    let childContracts = getChildContracts();
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
    let rootContracts = getRootContracts();
    let rootBridgeAddr = rootContracts.ROOT_BRIDGE_ADDRESS;

    // Get deployer address
    const childProvider = new RetryProvider(childRPCURL, Number(childChainID));
    const rootProvider = new RetryProvider(rootRPCURL, Number(rootChainID));
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

    // Check duplicates
    if (hasDuplicates([deployerAddr, childBridgeAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }
    if (hasDuplicates([deployerAddr, rootBridgeAddr, rootIMXAddr])) {
        throw("Duplicate address detected!");
    }

    // Execute
    // Get amount to balance on L2
    let bridgeBal = await childProvider.getBalance(childBridgeAddr);
    let multisigBal = await childProvider.getBalance(multisigAddr);
    let balanceAmt = ethers.utils.parseEther(TOTAL_SUPPLY).sub(bridgeBal).sub(multisigBal);

    console.log("The amount to balance on L1 is: ", ethers.utils.formatEther(balanceAmt));
    let IMX = new ethers.Contract(rootIMXAddr, IMX_ABI, rootProvider);
    let deployerL1Balance = await IMX.balanceOf(deployerAddr);
    let rootBridgeBalance = await IMX.balanceOf(rootBridgeAddr);

    console.log("Deployer L1 IMX balance: ", ethers.utils.formatEther(deployerL1Balance));
    console.log("Root bridge L1 IMX balance: ", ethers.utils.formatEther(rootBridgeBalance));

    console.log("Rebalance in...");
    await waitForConfirmation();

    if (deployerL1Balance.lt(balanceAmt)) {
        console.log("Insufficient balance to rebalance (already balanced?), skip.");
        return;
    }

    // Rebalancing
    console.log("Rebalancing...")
    let resp = await IMX.connect(rootDeployerWallet).transfer(rootBridgeAddr, balanceAmt);
    console.log("Transaction submitted: ", JSON.stringify(resp, null, 2))
    await waitForReceipt(resp.hash, rootProvider);

    deployerL1Balance = await IMX.balanceOf(deployerAddr);
    rootBridgeBalance = await IMX.balanceOf(rootBridgeAddr);
    console.log("Deployer L1 IMX balance: ", ethers.utils.formatEther(deployerL1Balance));
    console.log("Root bridge L1 IMX balance: ", ethers.utils.formatEther(rootBridgeBalance));

    console.log("=======End IMX Rebalancing=======");
}
run();