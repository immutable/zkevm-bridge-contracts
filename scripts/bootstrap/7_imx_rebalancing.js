// IMX rebalancing
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const { LedgerSigner } = require('@ethersproject/hardware-wallets')
const fs = require('fs');

// The total supply of IMX
const TOTAL_SUPPLY = "2000000000";

// The contract ABI of IMX on L1.
const IMX_ABI = `[{"inputs":[{"internalType":"address","name":"minter","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"previousAdminRole","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"newAdminRole","type":"bytes32"}],"name":"RoleAdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleGranted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleRevoked","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"DEFAULT_ADMIN_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"MINTER_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"cap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"}],"name":"getRoleAdmin","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"grantRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"renounceRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"revokeRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]`;

async function run() {
    // Check environment variables
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
    let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
    let rootDeployerSecret = helper.requireEnv("ROOT_DEPLOYER_SECRET");
    let multisigAddr = helper.requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootIMXAddr = helper.requireEnv("ROOT_IMX_ADDR");

    // Read from contract file.
    let data = fs.readFileSync(".child.bridge.contracts.json", 'utf-8');
    let childContracts = JSON.parse(data);
    let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
    data = fs.readFileSync(".root.bridge.contracts.json", 'utf-8');
    let rootContracts = JSON.parse(data);
    let rootBridgeAddr = rootContracts.ROOT_BRIDGE_ADDRESS;

    // Get admin address
    const childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    const rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let adminWallet;
    if (rootDeployerSecret == "ledger") {
        adminWallet = new LedgerSigner(rootProvider);
    } else {
        adminWallet = new ethers.Wallet(rootDeployerSecret, rootProvider);
    }
    let adminAddr = await adminWallet.getAddress();
    console.log("Deployer address is: ", adminAddr);

    // Check duplicates
    if (helper.hasDuplicates([adminAddr, childBridgeAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }
    if (helper.hasDuplicates([adminAddr, rootBridgeAddr, rootIMXAddr])) {
        throw("Duplicate address detected!");
    }

    // Execute
    // Get amount to balance on L2
    let bridgeBal = await childProvider.getBalance(childBridgeAddr);
    let multisigBal = await childProvider.getBalance(multisigAddr);
    let balanceAmt = ethers.utils.parseEther(TOTAL_SUPPLY).sub(bridgeBal).sub(multisigBal);

    console.log("The amount to balance on L1 is: ", ethers.utils.formatEther(balanceAmt));
    let IMX = new ethers.Contract(rootIMXAddr, IMX_ABI, rootProvider);
    let adminL1Balance = await IMX.balanceOf(adminAddr);
    let rootBridgeBalance = await IMX.balanceOf(rootBridgeAddr);

    console.log("Admin L1 IMX balance: ", ethers.utils.formatEther(adminL1Balance));
    console.log("Root bridge L1 IMX balance: ", ethers.utils.formatEther(rootBridgeBalance));
    
    if (rootBridgeBalance.gt(ethers.utils.parseEther("1.0"))) {
        console.log("IMX Rebalancing has already been done, skip.")
        return;
    }

    console.log("Rebalance in...");
    await helper.waitForConfirmation();

    // Rebalancing
    console.log("Transfer...")
    let resp = await IMX.connect(adminWallet).transfer(rootBridgeAddr, balanceAmt);
    await helper.waitForReceipt(resp.hash, rootProvider);
    adminL1Balance = await IMX.balanceOf(adminAddr);
    rootBridgeBalance = await IMX.balanceOf(rootBridgeAddr);
    console.log("Admin L1 IMX balance: ", ethers.utils.formatEther(adminL1Balance));
    console.log("Root bridge L1 IMX balance: ", ethers.utils.formatEther(rootBridgeBalance));
}
run();