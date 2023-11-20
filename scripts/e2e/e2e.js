// End to end tests
'use strict';
require('dotenv').config();
const { ethers } = require("ethers");
const helper = require("../helpers/helpers.js");
const fs = require('fs');
const { expect } = require("chai");

// The contract ABI of IMX on L1.
const IMX_ABI = `[{"inputs":[{"internalType":"address","name":"minter","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"previousAdminRole","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"newAdminRole","type":"bytes32"}],"name":"RoleAdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleGranted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleRevoked","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"DEFAULT_ADMIN_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"MINTER_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"cap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"}],"name":"getRoleAdmin","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"grantRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"renounceRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"revokeRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]`;

describe("Bridge e2e test", () => {
    let rootProvider;
    let childProvider;
    let rootTestWallet;
    let childTestWallet;
    //  TODO. Add e2e tests with different recipient on the other chain.
    let rootTestRecipientWallet;
    let childTestRecipientWallet;
    let rootBridge;
    let rootWETH;
    let rootIMX;
    let childBridge;
    let childETH;
    let childWIMX;
    
    before(async() => {
        let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
        let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
        let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
        let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
        let testAccountKey = helper.requireEnv("TEST_ACCOUNT_SECRET");
        let rootIMXAddr = helper.requireEnv("ROOT_IMX_ADDR");
        let rootWETHAddr = helper.requireEnv("ROOT_WETH_ADDR");

        // Read from contract file.
        let data = fs.readFileSync(".child.bridge.contracts.json", 'utf-8');
        let childContracts = JSON.parse(data);
        let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
        let childWIMXAddr = childContracts.WRAPPED_IMX_ADDRESS;
        data = fs.readFileSync(".root.bridge.contracts.json", 'utf-8');
        let rootContracts = JSON.parse(data);
        let rootBridgeAddr = rootContracts.ROOT_BRIDGE_ADDRESS;

        rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
        childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
        rootTestWallet = new ethers.Wallet(testAccountKey, rootProvider);
        childTestWallet = new ethers.Wallet(testAccountKey, childProvider);

        // Randomly generate a recipient account on root and child chain.
        rootTestRecipientWallet = ethers.Wallet.createRandom().connect(rootProvider);
        childTestRecipientWallet = rootTestRecipientWallet.connect(childProvider);

        let rootBridgeObj = JSON.parse(fs.readFileSync('../../out/RootERC20Bridge.sol/RootERC20Bridge.json', 'utf8'));
        rootBridge = new ethers.Contract(rootBridgeAddr, rootBridgeObj.abi, rootProvider);

        let WETHObj = JSON.parse(fs.readFileSync('../../out/WETH.sol/WETH.json', 'utf8'))
        rootWETH = new ethers.Contract(rootWETHAddr, WETHObj.abi, rootProvider);

        rootIMX = new ethers.Contract(rootIMXAddr, IMX_ABI, rootProvider);

        let childBridgeObj = JSON.parse(fs.readFileSync('../../out/ChildERC20Bridge.sol/ChildERC20Bridge.json', 'utf8'));
        childBridge = new ethers.Contract(childBridgeAddr, childBridgeObj.abi, childProvider);

        let childEthTokenAddr = await childBridge.childETHToken();
        let childTokenTemplateObj = JSON.parse(fs.readFileSync('../../out/ChildERC20.sol/ChildERC20.json', 'utf8'));
        childETH = new ethers.Contract(childEthTokenAddr, childTokenTemplateObj.abi, childProvider);

        let wrappedIMXObj = JSON.parse(fs.readFileSync('../../out/WIMX.sol/WIMX.json', 'utf8'));
        childWIMX = new ethers.Contract(childWIMXAddr, wrappedIMXObj.abi, childProvider);
    })

    it("should successfully deposit IMX to self from L1 to L2", async() => {
        // Get IMX balance on root & child chains before deposit
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childProvider.getBalance(childTestWallet.address);

        let amt = ethers.utils.parseEther("10.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Approve
        let resp = await rootIMX.connect(rootTestWallet).approve(rootBridge.address, amt);
        await helper.waitForReceipt(resp.hash, rootProvider);

        // IMX deposit L1 to L2
        resp = await rootBridge.connect(rootTestWallet).deposit(rootIMX.address, amt, {
            value: bridgeFee,
        });
        await helper.waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2;

        while (true) {
            postBalL2 = await childProvider.getBalance(childTestWallet.address);
            if (!preBalL2.eq(postBalL2)) {
                break;
            }
            await helper.delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(60000)

    it("should successfully withdraw IMX to self from L2 to L1", async() => {
        // TODO.
    }).timeout(120000)

    it("should successfully withdraw wIMX to self from L2 to L1", async() => {
        // TODO.
    }).timeout(120000)

    it("should successfully deposit ETH to self from L1 to L2", async() => {
        // Get ETH balance on root & child chains before deposit
        let preBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("0.001");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // ETH deposit L1 to L2
        let resp = await rootBridge.connect(rootTestWallet).depositETH(amt, {
            value: amt.add(bridgeFee),
        });
        await helper.waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let postBalL2;

        // Get receipt
        let receipt = await rootProvider.getTransactionReceipt(resp.hash);
        while (true) {
            postBalL2 = await childETH.balanceOf(childTestWallet.address);
            if (!preBalL2.eq(postBalL2)) {
                break;
            }
            await helper.delay(1000);
        }

        // Verify
        let txFee = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
        let expectedPostL1 = preBalL1.sub(txFee).sub(amt).sub(bridgeFee);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(60000)

    it("should successfully deposit wETH to self from L1 to L2", async() => {
        // TODO.
    }).timeout(60000)

    it("should successfully withdraw ETH to self from L2 to L1", async() => {
        // TODO.
    }).timeout(120000)

    it("should successfully deposit mapped ERC20 Token to self from L1 to L2", async() => {
        // TODO.
    }).timeout(60000)

    it("should successfully withdraw mapped ERC20 Token to self from L2 to L1", async() => {
        // TODO.
    }).timeout(120000)
})