// End to end tests
import * as dotenv from "dotenv";
dotenv.config();
import { ethers, providers } from "ethers";
import { requireEnv, waitForReceipt, getFee, getContract, delay, getChildContracts, getRootContracts, saveChildContracts, waitUntilSucceed } from "../helpers/helpers";
import * as chai from "chai";
chai.use(require('chai-as-promised'));
const { expect } = chai;

// The contract ABI of IMX on L1.
const IMX_ABI = `[{"inputs":[{"internalType":"address","name":"minter","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"previousAdminRole","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"newAdminRole","type":"bytes32"}],"name":"RoleAdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleGranted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleRevoked","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"DEFAULT_ADMIN_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"MINTER_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"cap","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"}],"name":"getRoleAdmin","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"grantRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"renounceRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"revokeRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]`;

describe("Bridge e2e test", () => {
    let rootProvider: providers.JsonRpcProvider;
    let childProvider: providers.JsonRpcProvider;
    let rootTestWallet: ethers.Wallet;
    let childTestWallet: ethers.Wallet;
    let rootPauserWallet: ethers.Wallet;
    let childPauserWallet: ethers.Wallet;
    let rootPrivilegedWallet: ethers.Wallet;
    let childPrivilegedWallet: ethers.Wallet;
    let rootBridge: ethers.Contract;
    let rootWETH: ethers.Contract;
    let rootIMX: ethers.Contract;
    let childBridge: ethers.Contract;
    let childETH: ethers.Contract;
    let childWIMX: ethers.Contract;
    let rootCustomToken: ethers.Contract;
    let childCustomToken: ethers.Contract;
    let axelarAPI: string;
    
    before(async function () {
        this.timeout(300000);
        let rootRPCURL = requireEnv("ROOT_RPC_URL");
        let rootChainID = requireEnv("ROOT_CHAIN_ID");
        let childRPCURL = requireEnv("CHILD_RPC_URL");
        let childChainID = requireEnv("CHILD_CHAIN_ID");
        let testBreakGlassKey = requireEnv("BREAKGLASS_EOA_SECRET");
        let testPriviledgeKey = requireEnv("PRIVILEGED_EOA_SECRET");
        let testAccountKey = requireEnv("TEST_ACCOUNT_SECRET");
        let rootIMXAddr = requireEnv("ROOT_IMX_ADDR");
        let rootWETHAddr = requireEnv("ROOT_WETH_ADDR");
        axelarAPI = requireEnv("AXELAR_API_URL");

        // Read from contract file.
        let childContracts = getChildContracts();
        let childBridgeAddr = childContracts.CHILD_BRIDGE_ADDRESS;
        let childWIMXAddr = childContracts.WRAPPED_IMX_ADDRESS;
        let rootContracts = getRootContracts();
        let rootBridgeAddr = rootContracts.ROOT_BRIDGE_ADDRESS;
        let rootCustomTokenAddr = rootContracts.ROOT_TEST_CUSTOM_TOKEN;

        rootProvider = new providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
        childProvider = new providers.JsonRpcProvider(childRPCURL, Number(childChainID));
        rootTestWallet = new ethers.Wallet(testAccountKey, rootProvider);
        childTestWallet = new ethers.Wallet(testAccountKey, childProvider);
        rootPauserWallet = new ethers.Wallet(testBreakGlassKey, rootProvider);
        childPauserWallet = new ethers.Wallet(testBreakGlassKey, childProvider);
        rootPrivilegedWallet = new ethers.Wallet(testPriviledgeKey, rootProvider);
        childPrivilegedWallet = new ethers.Wallet(testPriviledgeKey, childProvider);

        rootBridge = getContract("RootERC20BridgeFlowRate", rootBridgeAddr, rootProvider);
        rootWETH = getContract("WETH", rootWETHAddr, rootProvider);
        rootIMX = new ethers.Contract(rootIMXAddr, IMX_ABI, rootProvider);
        rootCustomToken = getContract("ChildERC20", rootCustomTokenAddr, rootProvider);
        childBridge = getContract("ChildERC20Bridge", childBridgeAddr, childProvider);
        childETH = getContract("ChildERC20", await childBridge.childETHToken(), childProvider);
        childWIMX = getContract("WIMX", childWIMXAddr, childProvider);

        // Transfer 0.5 ETH to root pauser
        let resp = await rootTestWallet.sendTransaction({
            to: rootPauserWallet.address,
            value: ethers.utils.parseEther("0.5"),
        })
        await waitForReceipt(resp.hash, rootProvider);

        // Transfer 0.5 ETH to root unpauser
        resp = await rootTestWallet.sendTransaction({
            to: rootPrivilegedWallet.address,
            value: ethers.utils.parseEther("0.5"),
        })
        await waitForReceipt(resp.hash, rootProvider);

        // Transfer 5 IMX to child pauser
        resp = await childTestWallet.sendTransaction({
            to: childPauserWallet.address,
            value: ethers.utils.parseEther("5"),
        })
        await waitForReceipt(resp.hash, childProvider);

        // Transfer 5 IMX to child unpauser
        resp = await childTestWallet.sendTransaction({
            to: childPrivilegedWallet.address,
            value: ethers.utils.parseEther("5"),
        })
        await waitForReceipt(resp.hash, childProvider);
    })

    it("should not deposit IMX if allowance is insufficient", async() => {
        let amt = ethers.utils.parseEther("50.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Approve
        let resp = await rootIMX.connect(rootTestWallet).approve(rootBridge.address, amt.sub(1));
        await waitForReceipt(resp.hash, rootProvider);

        // Fail to deposit on L1
        await expect(rootBridge.connect(rootTestWallet).deposit(rootIMX.address, amt, {
            value: bridgeFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it.only("should not deposit IMX if balance is insufficient", async() => {
        let balance = await rootIMX.balanceOf(rootTestWallet.address);

        let amt = balance.add(1);
        let bridgeFee = ethers.utils.parseEther("0.001");

        await expect(
            depositIMX(rootTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    // Local only
    it("should not deposit IMX if root bridge is paused", async() => {
        let resp;
        // Pause root bridge
        if (!await rootBridge.paused()) {
            resp = await rootBridge.connect(rootPauserWallet).pause();
            await waitForReceipt(resp.hash, rootProvider);
            expect(await rootBridge.paused()).to.true;
        }

        // Try to deposit.
        let amt = ethers.utils.parseEther("10.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        await expect(
            depositIMX(rootTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("Pausable: paused");

        // Unpause root bridge
        resp = await rootBridge.connect(rootPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, rootProvider);
        expect(await rootBridge.paused()).to.false;
    }).timeout(2400000)

    // Local only
    it("should not deposit IMX if deposit limit is reached", async() => {
        let limit = ethers.utils.parseEther("100000000.0");

        let amt = limit.add(1);
        let bridgeFee = ethers.utils.parseEther("0.001");

        await expect(
            depositIMX(rootTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("ImxDepositLimitExceeded()");
    }).timeout(2400000)

    it("should successfully deposit IMX to self from L1 to L2", async() => {
        // Get IMX balance on root & child chains before deposit
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childProvider.getBalance(childTestWallet.address);

        let amt = ethers.utils.parseEther("50.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        let resp = await depositIMX(rootTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childProvider.getBalance(childTestWallet.address);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully deposit IMX to others from L1 to L2", async() => {
        let childRecipient = childPrivilegedWallet.address;
        // Get IMX balance on root & child chains before deposit
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childProvider.getBalance(childRecipient);

        let amt = ethers.utils.parseEther("50.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        let resp = await depositIMX(rootTestWallet, amt, bridgeFee, childRecipient);
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childProvider.getBalance(childRecipient);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    // Local only
    it("should not deposit IMX on L2 if child bridge is paused", async() => {
        // Transfer 0.1 IMX to child pauser
        let resp = await childTestWallet.sendTransaction({
            to: childPauserWallet.address,
            value: ethers.utils.parseEther("0.1"),
        })
        await waitForReceipt(resp.hash, childProvider);

        // Transfer 0.1 IMX to child unpauser
        resp = await childTestWallet.sendTransaction({
            to: childPrivilegedWallet.address,
            value: ethers.utils.parseEther("0.1"),
        })
        await waitForReceipt(resp.hash, childProvider);

        // Pause child bridge
        if (!await childBridge.paused()) {
            resp = await childBridge.connect(childPauserWallet).pause();
            await waitForReceipt(resp.hash, childProvider);
            expect(await childBridge.paused()).to.true;
        }

        // Get IMX balance on root & child chains before deposit
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childProvider.getBalance(childTestWallet.address);

        let amt = ethers.utils.parseEther("10.0");
        let bridgeFee = ethers.utils.parseEther("0.001");
        resp = await depositIMX(rootTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, rootProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        // Balance on L2 should not change.
        await delay(10000);
        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2 = await childProvider.getBalance(childTestWallet.address);

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2;
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Unpause child bridge
        resp = await childBridge.connect(childPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, childProvider);
        expect(await childBridge.paused()).to.false;
    }).timeout(2400000)

    // Local only
    it("should not withdraw IMX if child bridge is paused", async() => {
        let resp;
        // Pause child bridge
        if (!await childBridge.paused()) {
            resp = await childBridge.connect(childPauserWallet).pause();
            await waitForReceipt(resp.hash, childProvider);
            expect(await childBridge.paused()).to.true;
        }

        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // IMX withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        await expect(childBridge.connect(childTestWallet).withdrawIMX(amt, {
            value: amt.add(bridgeFee),
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })).to.be.rejectedWith("Pausable: paused");

        // Unpause child bridge
        resp = await childBridge.connect(childPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, childProvider);
        expect(await childBridge.paused()).to.false;
    }).timeout(2400000)

    it("should not withdraw IMX if balance is insufficient", async() => {
        let balance = await childProvider.getBalance(childTestWallet.address);

        let amt = balance;
        let bridgeFee = ethers.utils.parseEther("1.0");

        // IMX withdraw L2 to L1
        await expect(
            withdrawIMX(childTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("sender doesn't have enough funds to send tx");
    }).timeout(2400000)

    it("should successfully withdraw IMX to self from L2 to L1", async() => {
        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childProvider.getBalance(childTestWallet.address);

        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // IMX withdraw L2 to L1
        let resp = await withdrawIMX(childTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childProvider.getBalance(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
            await delay(1000);
        }

        // Verify
        let receipt = await childProvider.getTransactionReceipt(resp.hash);
        let txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(txFee).sub(amt).sub(bridgeFee);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully withdraw IMX to others from L2 to L1", async() => {
        let rootRecipient = rootPrivilegedWallet.address;
        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootRecipient);
        let preBalL2 = await childProvider.getBalance(childTestWallet.address);

        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // IMX withdraw L2 to L1
        let resp = await withdrawIMX(childTestWallet, amt, bridgeFee, rootRecipient);
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childProvider.getBalance(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootIMX.balanceOf(rootRecipient);
            await delay(1000);
        }

        // Verify
        let receipt = await childProvider.getTransactionReceipt(resp.hash);
        let txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(txFee).sub(amt).sub(bridgeFee);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    // Local only
    it("should not withdraw IMX on L1 if root bridge is paused", async() => {
        let resp;
        // Pause root bridge
        if (!await rootBridge.paused()) {
            resp = await rootBridge.connect(rootPauserWallet).pause();
            await waitForReceipt(resp.hash, rootProvider);
            expect(await rootBridge.paused()).to.true;
        }

        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childProvider.getBalance(childTestWallet.address);

        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // IMX withdraw L2 to L1
        resp = await withdrawIMX(childTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        // Balance on L1 should not change.
        await delay(10000);
        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2 = await childProvider.getBalance(childTestWallet.address);

        // Verify
        let receipt = await childProvider.getTransactionReceipt(resp.hash);
        let txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        let expectedPostL1 = preBalL1;
        let expectedPostL2 = preBalL2.sub(txFee).sub(amt).sub(bridgeFee);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Unpause root bridge
        resp = await rootBridge.connect(rootPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, rootProvider);
        expect(await rootBridge.paused()).to.false;
    }).timeout(2400000)

    // Local only
    it("should put IMX withdrawal in pending when violating rate limit policy", async() => {
        // Set new rate limit
        let resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(rootIMX.address, ethers.utils.parseEther("2.016"), ethers.utils.parseEther("0.00056"), ethers.utils.parseEther("1.008"));
        await waitForReceipt(resp.hash, rootProvider);

        // Withdraw of IMX exceeding large threshold
        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childProvider.getBalance(childTestWallet.address);
        let preLength = await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address);

        let amt1 = ethers.utils.parseEther("1.1");
        let bridgeFee1 = ethers.utils.parseEther("1.0");

        // IMX withdraw L2 to L1
        resp = await withdrawIMX(childTestWallet, amt1, bridgeFee1, null);
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        let receipt = await childProvider.getTransactionReceipt(resp.hash);
        let txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength)) {
            await delay(1000);
        }

        // Withdraw of IMX exceeding rate limit
        let amt2 = ethers.utils.parseEther("1.0");
        let bridgeFee2 = ethers.utils.parseEther("1.0");

        // IMX withdraw L2 to L1
        resp = await withdrawIMX(childTestWallet, amt2, bridgeFee2, null);
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);
        receipt = await childProvider.getTransactionReceipt(resp.hash);
        let txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength.add(1))) {
            await delay(1000);
        }

        // Try to withdraw
        await expect(rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))).to.be.rejectedWith(
            "UNPREDICTABLE_GAS_LIMIT"
        );

        // Fast-forward to 24 hours later.
        await rootProvider.send(
            "hardhat_mine", [
            "0x15181", // 24 hours
        ]);

        // Withdraw again
        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))
        await waitForReceipt(resp.hash, rootProvider);

        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength)
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2 = await childProvider.getBalance(childTestWallet.address);

        // Verify
        let expectedPostL1 = preBalL1.add(amt1).add(amt2);
        let expectedPostL2 = preBalL2.sub(amt1).sub(amt2).sub(txFee1).sub(txFee2).sub(bridgeFee1).sub(bridgeFee2);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Recover rate limit
        resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(rootIMX.address, ethers.utils.parseEther("15516"), ethers.utils.parseEther("4.31"), ethers.utils.parseEther("7758"));
        await waitForReceipt(resp.hash, rootProvider);

        // Deactive withdraw queue
        resp = await rootBridge.connect(rootPrivilegedWallet).deactivateWithdrawalQueue();
        await waitForReceipt(resp.hash, rootProvider);
    }).timeout(2400000)

    // Local only
    it("should not withdraw WIMX if child bridge is paused", async() => {
        let resp;
        // Pause child bridge
        if (!await childBridge.paused()) {
            resp = await childBridge.connect(childPauserWallet).pause();
            await waitForReceipt(resp.hash, childProvider);
            expect(await childBridge.paused()).to.true;
        }

        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        await expect(
            withdrawWIMX(childTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("Pausable: paused");

        // Unpause child bridge
        resp = await childBridge.connect(childPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, childProvider);
        expect(await childBridge.paused()).to.false;
    }).timeout(2400000)

    it("should not withdraw wIMX if allowance is insufficient", async() => {
        // Wrap 1 IMX
        let [priorityFee, maxFee] = await getFee(childProvider);
        let resp = await childWIMX.connect(childTestWallet).deposit({
            value: ethers.utils.parseEther("1.0"),
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);

        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // Approve
        [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childWIMX.connect(childTestWallet).approve(childBridge.address, amt.sub(1), {
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);

        // wIMX withdraw L2 to L1
        [priorityFee, maxFee] = await getFee(childProvider);
        await expect(childBridge.connect(childTestWallet).withdrawWIMX(amt, {
            value: bridgeFee,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it("should not withdraw wIMX if balance is insufficient", async() => {
        let balance = await childWIMX.balanceOf(childTestWallet.address);

        let amt = balance.add(1);
        let bridgeFee = ethers.utils.parseEther("1.0");

        await expect(
            withdrawWIMX(childTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it("should successfully withdraw wIMX to self from L2 to L1", async() => {
        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childWIMX.balanceOf(childTestWallet.address);

        let resp = await withdrawWIMX(rootTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childWIMX.balanceOf(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully withdraw wIMX to others from L2 to L1", async() => {
        let rootRecipient = rootPrivilegedWallet.address;
        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");
        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootRecipient);
        let preBalL2 = await childWIMX.balanceOf(childTestWallet.address);

        let resp = await withdrawWIMX(rootTestWallet, amt, bridgeFee, rootRecipient);
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childWIMX.balanceOf(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootIMX.balanceOf(rootRecipient);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    // Local only
    it("should not withdraw wIMX on L1 if root bridge is paused", async() => {
        let resp;
        // Pause root bridge
        if (!await rootBridge.paused()) {
            resp = await rootBridge.connect(rootPauserWallet).pause();
            await waitForReceipt(resp.hash, rootProvider);
            expect(await rootBridge.paused()).to.true;
        }

        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childWIMX.balanceOf(childTestWallet.address);

        resp = await withdrawWIMX(rootTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        // Balance on L1 should not change.
        await delay(10000);
        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2 = await childWIMX.balanceOf(childTestWallet.address);

        // Verify
        let expectedPostL1 = preBalL1;
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Unpause root bridge
        resp = await rootBridge.connect(rootPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, rootProvider);
        expect(await rootBridge.paused()).to.false;
    }).timeout(2400000)

    // Local only
    it("should put wIMX withdrawal in pending when violating rate limit policy", async() => {
        // Set new rate limit
        let resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(rootIMX.address, ethers.utils.parseEther("2.016"), ethers.utils.parseEther("0.00056"), ethers.utils.parseEther("1.008"));
        await waitForReceipt(resp.hash, rootProvider);

        // Wrap 3 IMX
        let [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childWIMX.connect(childTestWallet).deposit({
            value: ethers.utils.parseEther("3.0"),
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);

        // Withdraw of IMX exceeding large threshold
        // Get IMX balance on root & child chains before withdraw
        let preBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preBalL2 = await childWIMX.balanceOf(childTestWallet.address);
        let preLength = await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address);

        let amt1 = ethers.utils.parseEther("1.1");
        let bridgeFee1 = ethers.utils.parseEther("1.0");

        // Approve
        [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childWIMX.connect(childTestWallet).approve(childBridge.address, amt1, {
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);

        // wIMX withdraw L2 to L1
        [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childBridge.connect(childTestWallet).withdrawWIMX(amt1, {
            value: bridgeFee1,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength)) {
            await delay(1000);
        }

        // Withdraw of IMX exceeding rate limit
        let amt2 = ethers.utils.parseEther("1.0");
        let bridgeFee2 = ethers.utils.parseEther("1.0");

        // Approve
        [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childWIMX.connect(childTestWallet).approve(childBridge.address, amt2, {
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);

        // IMX withdraw L2 to L1
        [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childBridge.connect(childTestWallet).withdrawWIMX(amt2, {
            value: bridgeFee2,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength.add(1))) {
            await delay(1000);
        }

        // Try to withdraw
        await expect(rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))).to.be.rejectedWith(
            "UNPREDICTABLE_GAS_LIMIT"
        );

        // Fast-forward to 24 hours later.
        await rootProvider.send(
            "hardhat_mine", [
            "0x15181", // 24 hours
        ]);

        // Withdraw again
        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))
        await waitForReceipt(resp.hash, rootProvider);

        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength)
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postBalL2 = await childWIMX.balanceOf(childTestWallet.address);

        // Verify
        let expectedPostL1 = preBalL1.add(amt1).add(amt2);
        let expectedPostL2 = preBalL2.sub(amt1).sub(amt2);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Recover rate limit
        resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(rootIMX.address, ethers.utils.parseEther("15516"), ethers.utils.parseEther("4.31"), ethers.utils.parseEther("7758"));
        await waitForReceipt(resp.hash, rootProvider);

        // Deactive withdraw queue
        resp = await rootBridge.connect(rootPrivilegedWallet).deactivateWithdrawalQueue();
        await waitForReceipt(resp.hash, rootProvider);
    }).timeout(2400000)

    it("should not deposit ETH if balance is insufficient", async() => {
        let balance = await rootProvider.getBalance(rootTestWallet.address);

        let amt = balance;
        let bridgeFee = ethers.utils.parseEther("0.001");
        
        await expect(rootBridge.connect(rootTestWallet).depositETH(amt, {
            value: amt.add(bridgeFee),
        })).to.be.rejectedWith("sender doesn't have enough funds to send tx");
    }).timeout(2400000)

    // Local only
    it("should not deposit ETH if root bridge is paused", async() => {
        let resp;
        // Pause root bridge
        if (!await rootBridge.paused()) {
            resp = await rootBridge.connect(rootPauserWallet).pause();
            await waitForReceipt(resp.hash, rootProvider);
            expect(await rootBridge.paused()).to.true;
        }

        let amt = ethers.utils.parseEther("0.001");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Fail to deposit on L1
        await expect(
            depositETH(rootTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("Pausable: paused");

        // Unpause root bridge
        resp = await rootBridge.connect(rootPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, rootProvider);
        expect(await rootBridge.paused()).to.false;
    }).timeout(2400000)

    it("should successfully deposit ETH to self from L1 to L2", async() => {
        // Get ETH balance on root & child chains before deposit
        let preBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // ETH deposit L1 to L2
        let resp = await depositETH(rootTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childETH.balanceOf(childTestWallet.address);
            await delay(1000);
        }

        // Verify
        let receipt = await rootProvider.getTransactionReceipt(resp.hash);
        let txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        let expectedPostL1 = preBalL1.sub(txFee).sub(amt).sub(bridgeFee);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully deposit ETH to others from L1 to L2", async() => {
        let childRecipient = childPrivilegedWallet.address;
        // Get ETH balance on root & child chains before deposit
        let preBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childRecipient);

        let amt = ethers.utils.parseEther("0.001");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // ETH deposit L1 to L2
        let resp = await depositETH(rootTestWallet, amt, bridgeFee, childRecipient);
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childETH.balanceOf(childRecipient);
            await delay(1000);
        }

        // Verify
        let receipt = await rootProvider.getTransactionReceipt(resp.hash);
        let txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        let expectedPostL1 = preBalL1.sub(txFee).sub(amt).sub(bridgeFee);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    // Local only
    it("should not deposit ETH on L2 if child bridge is paused", async() => {
        let resp;
        // Pause child bridge
        if (!await childBridge.paused()) {
            resp = await childBridge.connect(childPauserWallet).pause();
            await waitForReceipt(resp.hash, childProvider);
            expect(await childBridge.paused()).to.true;
        }

        // Get ETH balance on root & child chains before deposit
        let preBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("0.001");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Try to deposit
        resp = await depositETH(rootTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, rootProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        // Balance on L2 should not change.
        await delay(10000);
        let postBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let postBalL2 = await childETH.balanceOf(childTestWallet.address);

        // Verify
        let receipt = await rootProvider.getTransactionReceipt(resp.hash);
        let txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        let expectedPostL1 = preBalL1.sub(txFee).sub(amt).sub(bridgeFee);
        let expectedPostL2 = preBalL2;
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Unpause child bridge
        resp = await childBridge.connect(childPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, childProvider);
        expect(await childBridge.paused()).to.false;
    }).timeout(2400000)

    it("should successfully deposit wETH to self from L1 to L2", async() => {
        let amt = ethers.utils.parseEther("0.001");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Get ETH balance on root & child chains before withdraw
        let preBalL1 = await rootWETH.balanceOf(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);

        let resp = await depositWETH(rootTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootWETH.balanceOf(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childETH.balanceOf(childTestWallet.address);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully deposit wETH to others from L1 to L2", async() => {
        let childRecipient = childPrivilegedWallet.address;
        let amt = ethers.utils.parseEther("0.001");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Get ETH balance on root & child chains before withdraw
        let preBalL1 = await rootWETH.balanceOf(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childRecipient);

        let resp = await depositWETH(rootTestWallet, amt, bridgeFee, childRecipient);
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootWETH.balanceOf(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childETH.balanceOf(childRecipient);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    // Local only
    it("should not withdraw ETH if child bridge is paused", async() => {
        let resp;
        // Pause child bridge
        if (!await childBridge.paused()) {
            resp = await childBridge.connect(childPauserWallet).pause();
            await waitForReceipt(resp.hash, childProvider);
            expect(await childBridge.paused()).to.true;
        }

        let amt = ethers.utils.parseEther("0.0005");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        await expect(
            withdrawETH(childTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("Pausable: paused");

        // Unpause child bridge
        resp = await childBridge.connect(childPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, childProvider);
        expect(await childBridge.paused()).to.false;
    }).timeout(2400000)

    it("should not withdraw ETH if balance is insufficient", async() => {
        let amt = await childETH.balanceOf(childTestWallet.address).add(1);
        let bridgeFee = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        await expect(
            withdrawETH(childTestWallet, amt, bridgeFee, null)
        ).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it("should successfully withdraw ETH to self from L2 to L1", async() => {
        // Get ETH balance on root & child chains before withdraw
        let preBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("0.0005");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        let resp = await withdrawETH(childTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childETH.balanceOf(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootProvider.getBalance(rootTestWallet.address);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully withdraw ETH to others from L2 to L1", async() => {
        let rootRecipient = rootPrivilegedWallet.address;
        // Get ETH balance on root & child chains before withdraw
        let preBalL1 = await rootProvider.getBalance(rootRecipient);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("0.0005");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        let resp = await withdrawETH(childTestWallet, amt, bridgeFee, rootRecipient);
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childETH.balanceOf(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootProvider.getBalance(rootRecipient);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    // Local only
    it("should not withdraw ETH on L1 if root bridge is paused", async() => {
        let resp;
        // Pause root bridge
        if (!await rootBridge.paused()) {
            resp = await rootBridge.connect(rootPauserWallet).pause();
            await waitForReceipt(resp.hash, rootProvider);
            expect(await rootBridge.paused()).to.true;
        }

        // Get ETH balance on root & child chains before withdraw
        let preBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("0.0005");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        resp = await withdrawETH(childTestWallet, amt, bridgeFee, null);
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        // Balance on L1 should not change.
        await delay(10000);
        let postBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let postBalL2 = await childETH.balanceOf(childTestWallet.address);

        // Verify
        let expectedPostL1 = preBalL1;
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Unpause root bridge
        resp = await rootBridge.connect(rootPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, rootProvider);
        expect(await rootBridge.paused()).to.false;
    }).timeout(2400000)

    // Local only
    it("should put ETH withdrawal in pending when violating rate limit policy", async() => {
        // Set new rate limit
        let resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(await rootBridge.NATIVE_ETH(), ethers.utils.parseEther("0.0010008"), ethers.utils.parseEther("0.000000278"), ethers.utils.parseEther("0.0005004"));
        await waitForReceipt(resp.hash, rootProvider);

        // Withdraw of ETH exceeding large threshold
        // Get ETH balance on root & child chains before withdraw
        let preBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preBalL2 = await childETH.balanceOf(childTestWallet.address);
        let preLength = await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address);

        let amt1 = ethers.utils.parseEther("0.0006");
        let bridgeFee1 = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childBridge.connect(childTestWallet).withdrawETH(amt1, {
            value: bridgeFee1,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength)) {
            await delay(1000);
        }

        // Withdraw of ETH exceeding rate limit
        let amt2 = ethers.utils.parseEther("0.0005");
        let bridgeFee2 = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childBridge.connect(childTestWallet).withdrawETH(amt2, {
            value: bridgeFee2,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength.add(1))) {
            await delay(1000);
        }

        // Try to withdraw
        await expect(rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))).to.be.rejectedWith(
            "UNPREDICTABLE_GAS_LIMIT"
        );

        // Fast-forward to 24 hours later.
        await rootProvider.send(
            "hardhat_mine", [
            "0x15181", // 24 hours
        ]);

        // Withdraw again
        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))
        await waitForReceipt(resp.hash, rootProvider);
        let receipt = await rootProvider.getTransactionReceipt(resp.hash);
        let txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength)
        await waitForReceipt(resp.hash, rootProvider);
        receipt = await rootProvider.getTransactionReceipt(resp.hash);
        let txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

        let postBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let postBalL2 = await childETH.balanceOf(childTestWallet.address);

        // Verify
        let expectedPostL1 = preBalL1.sub(txFee1).sub(txFee2).add(amt1).add(amt2);
        let expectedPostL2 = preBalL2.sub(amt1).sub(amt2);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Recover rate limit
        resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(await rootBridge.NATIVE_ETH(), ethers.utils.parseEther("10.08"), ethers.utils.parseEther("0.0028"), ethers.utils.parseEther("5.04"));
        await waitForReceipt(resp.hash, rootProvider);

        // Deactive withdraw queue
        resp = await rootBridge.connect(rootPrivilegedWallet).deactivateWithdrawalQueue();
        await waitForReceipt(resp.hash, rootProvider);
    }).timeout(2400000)

    it("should not deposit unmapped token", async() => {
        let unMappedToken = ethers.utils.getAddress("0xccC8cb5229B0ac8069C51fd58367Fd1e622aFD97");
        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Token deposit L1 to L2
        await expect(rootBridge.connect(rootTestWallet).deposit(unMappedToken, amt, {
            value: bridgeFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it("should successfully map a ERC20 Token", async() => {
        let childContracts = getChildContracts();
        let childCustomTokenAddr = childContracts.CHILD_TEST_CUSTOM_TOKEN;
        if (childCustomTokenAddr != "") {
            childCustomToken = getContract("ChildERC20", childCustomTokenAddr, childProvider);
            console.log("Custom token has already been mapped, skip.");
            return;
        }
        // Map token
        let bridgeFee = ethers.utils.parseEther("0.001");
        let expectedChildTokenAddr = await rootBridge.callStatic.mapToken(rootCustomToken.address, {
            value: bridgeFee,
        });
        let resp = await rootBridge.connect(rootTestWallet).mapToken(rootCustomToken.address, {
            value: bridgeFee,
        })
        await waitForReceipt(resp.hash, rootProvider);
        
        let childTokenAddr = await childBridge.rootTokenToChildToken(rootCustomToken.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (childTokenAddr == ethers.constants.AddressZero) {
            childTokenAddr = await childBridge.rootTokenToChildToken(rootCustomToken.address);
            await delay(1000);
        }
        childCustomToken = getContract("ChildERC20", childTokenAddr, childProvider);
        childContracts.CHILD_TEST_CUSTOM_TOKEN = childTokenAddr;
        saveChildContracts(childContracts);

        // Verify
        expect(childTokenAddr).to.equal(expectedChildTokenAddr);
    }).timeout(2400000)

    it("should not map a mapped ERC20 Token", async() => {
        let childContracts = getChildContracts();
        let childCustomTokenAddr = childContracts.CHILD_TEST_CUSTOM_TOKEN;
        if (childCustomTokenAddr == "") {
            childCustomToken = getContract("ChildERC20", childCustomTokenAddr, childProvider);
            console.log("Custom token has not been mapped yet, skip.");
            return;
        }
        // Map token
        let bridgeFee = ethers.utils.parseEther("0.001");
        await expect(rootBridge.connect(rootTestWallet).mapToken(rootCustomToken.address, {
            value: bridgeFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it("should not deposit mapped ERC20 Token if allowance is insufficient", async() => {
        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Approve
        let resp = await rootCustomToken.connect(rootTestWallet).approve(rootBridge.address, amt.sub(1));
        await waitForReceipt(resp.hash, rootProvider);

        // Fail to deposit on L1
        await expect(rootBridge.connect(rootTestWallet).deposit(rootCustomToken.address, amt, {
            value: bridgeFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it("should not deposit mapped ERC20 Token if balance is insufficient", async() => {
        let balance = await rootCustomToken.balanceOf(rootTestWallet.address);

        let amt = balance.add(1);
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Approve
        let resp = await rootCustomToken.connect(rootTestWallet).approve(rootBridge.address, amt);
        await waitForReceipt(resp.hash, rootProvider);
        
        await expect(rootBridge.connect(rootTestWallet).deposit(rootCustomToken.address, amt, {
            value: bridgeFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    // Local only
    it("should not deposit mapped ERC20 Token if root bridge is paused", async() => {
        // Transfer 0.1 ETH to root pauser
        let resp = await rootTestWallet.sendTransaction({
            to: rootPauserWallet.address,
            value: ethers.utils.parseEther("0.1"),
        })
        await waitForReceipt(resp.hash, rootProvider);

        // Transfer 0.1 ETH to root unpauser
        resp = await rootTestWallet.sendTransaction({
            to: rootPrivilegedWallet.address,
            value: ethers.utils.parseEther("0.1"),
        })
        await waitForReceipt(resp.hash, rootProvider);

        // Pause root bridge
        if (!await rootBridge.paused()) {
            resp = await rootBridge.connect(rootPauserWallet).pause();
            await waitForReceipt(resp.hash, rootProvider);
            expect(await rootBridge.paused()).to.true;
        }

        // Try to deposit.
        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Approve
        resp = await rootCustomToken.connect(rootTestWallet).approve(rootBridge.address, amt);
        await waitForReceipt(resp.hash, rootProvider);

        // Fail to deposit on L1
        await expect(rootBridge.connect(rootTestWallet).deposit(rootCustomToken.address, amt, {
            value: bridgeFee,
        })).to.be.rejectedWith("Pausable: paused");

        // Unpause root bridge
        resp = await rootBridge.connect(rootPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, rootProvider);
        expect(await rootBridge.paused()).to.false;
    }).timeout(2400000)

    it("should successfully deposit mapped ERC20 Token to self from L1 to L2", async() => {
        // Get token balance on root & child chains before deposit
        let preBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let preBalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("10.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Approve
        let resp = await rootCustomToken.connect(rootTestWallet).approve(rootBridge.address, amt);
        await waitForReceipt(resp.hash, rootProvider);

        // Token deposit L1 to L2
        resp = await rootBridge.connect(rootTestWallet).deposit(rootCustomToken.address, amt, {
            value: bridgeFee,
        })
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childCustomToken.balanceOf(childTestWallet.address);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully deposit mapped ERC20 Token to others from L1 to L2", async() => {
        let childRecipient = childPrivilegedWallet.address;
        // Get token balance on root & child chains before deposit
        let preBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let preBalL2 = await childCustomToken.balanceOf(childRecipient);

        let amt = ethers.utils.parseEther("1.0");
        let bridgeFee = ethers.utils.parseEther("0.001");

        // Approve
        let resp = await rootCustomToken.connect(rootTestWallet).approve(rootBridge.address, amt);
        await waitForReceipt(resp.hash, rootProvider);

        // Token deposit L1 to L2
        resp = await rootBridge.connect(rootTestWallet).depositTo(rootCustomToken.address, childRecipient, amt, {
            value: bridgeFee,
        })
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let postBalL2 = preBalL2;

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL2.eq(preBalL2)) {
            postBalL2 = await childCustomToken.balanceOf(childRecipient);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.sub(amt);
        let expectedPostL2 = preBalL2.add(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should not withdraw unmapped token", async() => {
        let unMappedToken = ethers.utils.getAddress("0xccC8cb5229B0ac8069C51fd58367Fd1e622aFD97");
        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // Token withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        await expect(childBridge.connect(childTestWallet).withdraw(unMappedToken, amt, {
            value: bridgeFee,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    // Local only
    it("should not withdraw mapped ERC20 Token if child bridge is paused", async() => {
        // Transfer 0.1 IMX to child pauser
        let resp = await childTestWallet.sendTransaction({
            to: childPauserWallet.address,
            value: ethers.utils.parseEther("0.1"),
        })
        await waitForReceipt(resp.hash, childProvider);

        // Transfer 0.1 IMX to child unpauser
        resp = await childTestWallet.sendTransaction({
            to: childPrivilegedWallet.address,
            value: ethers.utils.parseEther("0.1"),
        })
        await waitForReceipt(resp.hash, childProvider);

        // Pause child bridge
        if (!await childBridge.paused()) {
            resp = await childBridge.connect(childPauserWallet).pause();
            await waitForReceipt(resp.hash, childProvider);
            expect(await childBridge.paused()).to.true;
        }

        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // Token withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        await expect(childBridge.connect(childTestWallet).withdraw(childCustomToken.address, amt, {
            value: bridgeFee,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })).to.be.rejectedWith("Pausable: paused");

        // Unpause child bridge
        resp = await childBridge.connect(childPrivilegedWallet).unpause();
        await waitForReceipt(resp.hash, childProvider);
        expect(await childBridge.paused()).to.false;
    }).timeout(2400000)

    it("should not withdraw mapped ERC20 Token if balance is insufficient", async() => {
        let amt = await childCustomToken.balanceOf(childTestWallet.address);
        let bridgeFee = ethers.utils.parseEther("1.0");

        // ETH withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        await expect(childBridge.connect(childTestWallet).withdraw(childCustomToken.address, amt.add(1), {
            value: bridgeFee,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })).to.be.rejectedWith("UNPREDICTABLE_GAS_LIMIT");
    }).timeout(2400000)

    it("should successfully withdraw mapped ERC20 Token to self from L2 to L1", async() => {
        // Get token balance on root & child chains before deposit
        let preBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let preBalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // Token withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        let resp = await childBridge.connect(childTestWallet).withdraw(childCustomToken.address, amt, {
            value: bridgeFee,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    it("should successfully withdraw mapped ERC20 Token to others from L2 to L1", async() => {
        let rootRecipient = rootPrivilegedWallet.address;
        // Get token balance on root & child chains before deposit
        let preBalL1 = await rootCustomToken.balanceOf(rootRecipient);
        let preBalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        let amt = ethers.utils.parseEther("0.5");
        let bridgeFee = ethers.utils.parseEther("1.0");

        // Token withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        let resp = await childBridge.connect(childTestWallet).withdrawTo(childCustomToken.address, rootRecipient, amt, {
            value: bridgeFee,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        })
        await waitForReceipt(resp.hash, childProvider);

        let postBalL1 = preBalL1;
        let postBalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        await waitUntilSucceed(axelarAPI, resp.hash);

        while (postBalL1.eq(preBalL1)) {
            postBalL1 = await rootCustomToken.balanceOf(rootRecipient);
            await delay(1000);
        }

        // Verify
        let expectedPostL1 = preBalL1.add(amt);
        let expectedPostL2 = preBalL2.sub(amt);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());
    }).timeout(2400000)

    // Local only
    it("should put mapped ERC20 Token withdrawal in pending when violating rate limit policy", async() => {
        // Set new rate limit
        let resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(rootCustomToken.address, ethers.utils.parseEther("1.0008"), ethers.utils.parseEther("0.000278"), ethers.utils.parseEther("0.5004"));
        await waitForReceipt(resp.hash, rootProvider);

        // Withdraw of ERC20 exceeding large threshold
        // Get ERC20 balance on root & child chains before withdraw
        let preBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let preBalL2 = await childCustomToken.balanceOf(childTestWallet.address);
        let preLength = await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address);

        let amt1 = ethers.utils.parseEther("0.6");
        let bridgeFee1 = ethers.utils.parseEther("1.0");

        // ERC20 withdraw L2 to L1
        let [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childBridge.connect(childTestWallet).withdraw(childCustomToken.address, amt1, {
            value: bridgeFee1,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength)) {
            await delay(1000);
        }

        // Withdraw of ERC20 exceeding rate limit
        let amt2 = ethers.utils.parseEther("0.5");
        let bridgeFee2 = ethers.utils.parseEther("1.0");

        // ERC20 withdraw L2 to L1
        [priorityFee, maxFee] = await getFee(childProvider);
        resp = await childBridge.connect(childTestWallet).withdraw(childCustomToken.address, amt2, {
            value: bridgeFee2,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);
        await waitUntilSucceed(axelarAPI, resp.hash);

        while ((await rootBridge.getPendingWithdrawalsLength(rootTestWallet.address)).eq(preLength.add(1))) {
            await delay(1000);
        }

        // Try to withdraw
        await expect(rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))).to.be.rejectedWith(
            "UNPREDICTABLE_GAS_LIMIT"
        );

        // Fast-forward to 24 hours later.
        await rootProvider.send(
            "hardhat_mine", [
            "0x15181", // 24 hours
        ]);

        // Withdraw again
        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength.add(1))
        await waitForReceipt(resp.hash, rootProvider);

        resp = await rootBridge.connect(rootTestWallet).finaliseQueuedWithdrawal(rootTestWallet.address, preLength)
        await waitForReceipt(resp.hash, rootProvider);

        let postBalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let postBalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        // Verify
        let expectedPostL1 = preBalL1.add(amt1).add(amt2);
        let expectedPostL2 = preBalL2.sub(amt1).sub(amt2);
        expect(postBalL1.toBigInt()).to.equal(expectedPostL1.toBigInt());
        expect(postBalL2.toBigInt()).to.equal(expectedPostL2.toBigInt());

        // Recover rate limit
        resp = await rootBridge.connect(rootPrivilegedWallet).setRateControlThreshold(rootCustomToken.address, ethers.utils.parseEther("20016.0"), ethers.utils.parseEther("5.56"), ethers.utils.parseEther("10008.0"));
        await waitForReceipt(resp.hash, rootProvider);

        // Deactive withdraw queue
        resp = await rootBridge.connect(rootPrivilegedWallet).deactivateWithdrawalQueue();
        await waitForReceipt(resp.hash, rootProvider);
    }).timeout(2400000)

    // Local only
    it("should successfully process multiple deposit and withdrawal requests in parallel", async() => {
        // Deposit & withdrawal amount
        let amtL1 = ethers.utils.parseEther("1.0");
        let bridgeFeeL1 = ethers.utils.parseEther("0.001");
        let amtL2 = ethers.utils.parseEther("0.5");
        let bridgeFeeL2 = ethers.utils.parseEther("1.0");

        // Wrap & Approval
        let resp = await rootIMX.connect(rootTestWallet).approve(rootBridge.address, amtL1);
        await waitForReceipt(resp.hash, rootProvider);

        resp = await rootWETH.connect(rootTestWallet).deposit({ value: amtL1 });
        await waitForReceipt(resp.hash, rootProvider);
        resp = await rootWETH.connect(rootTestWallet).approve(rootBridge.address, amtL1);
        await waitForReceipt(resp.hash, rootProvider);

        resp = await rootCustomToken.connect(rootTestWallet).approve(rootBridge.address, amtL1);
        await waitForReceipt(resp.hash, rootProvider);

        resp = await childWIMX.connect(childTestWallet).deposit( {value: amtL2 });
        await waitForReceipt(resp.hash, childProvider);
        resp = await childWIMX.connect(childTestWallet).approve(childBridge.address, amtL2);
        await waitForReceipt(resp.hash, childProvider);

        // Deposit IMX, ETH, WETH, ERC20, and withdraw IMX, WIMX, ETH, ERC20
        let preIMXBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let preETHBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let preWETHBalL1 = await rootWETH.balanceOf(rootTestWallet.address);
        let preERC20BalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let preIMXBalL2 = await childProvider.getBalance(childTestWallet.address);
        let preWIMXBalL2 = await childWIMX.balanceOf(childTestWallet.address);
        let preETHBalL2 = await childETH.balanceOf(childTestWallet.address);
        let preERC20BalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        // Stop mining
        await rootProvider.send(
            "evm_setIntervalMining", [
            0,
        ]);
        await childProvider.send(
            "evm_setIntervalMining", [
            0,
        ]);

        // Calls on L1 & L2
        let resp1 = await rootBridge.connect(rootTestWallet).deposit(rootIMX.address, amtL1, {
            value: bridgeFeeL1,
        });
        let resp2 = await rootBridge.connect(rootTestWallet).depositETH(amtL1, {
            value: bridgeFeeL1.add(amtL1),
        });
        let resp3 = await rootBridge.connect(rootTestWallet).deposit(rootWETH.address, amtL1, {
            value: bridgeFeeL1,
        });
        let resp4 = await rootBridge.connect(rootTestWallet).deposit(rootCustomToken.address, amtL1, {
            value: bridgeFeeL1,
        });
        let resp5 = await childBridge.connect(childTestWallet).withdrawIMX(amtL2, {
            value: bridgeFeeL2.add(amtL2),
        });
        let resp6 = await childBridge.connect(childTestWallet).withdrawWIMX(amtL2, {
            value: bridgeFeeL2,
        });
        let resp7 = await childBridge.connect(childTestWallet).withdrawETH(amtL2, {
            value: bridgeFeeL2,
        });
        let resp8 = await childBridge.connect(childTestWallet).withdraw(childCustomToken.address, amtL2, {
            value: bridgeFeeL2,
        });


        // Enable mining
        await rootProvider.send(
            "evm_setIntervalMining", [
            1200,
        ]);
        await childProvider.send(
            "evm_setIntervalMining", [
            200,
        ]);

        // Wait for transactions to be mined.
        await waitForReceipt(resp1.hash, rootProvider);
        await waitForReceipt(resp2.hash, rootProvider);
        await waitForReceipt(resp3.hash, rootProvider);
        await waitForReceipt(resp4.hash, rootProvider);
        await waitForReceipt(resp5.hash, childProvider);
        await waitForReceipt(resp6.hash, childProvider);
        await waitForReceipt(resp7.hash, childProvider);
        await waitForReceipt(resp8.hash, childProvider);

        // Wait for 30 seconds
        await delay(30000);
        let receipt = await rootProvider.getTransactionReceipt(resp1.hash);
        let txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        receipt = await rootProvider.getTransactionReceipt(resp2.hash);
        let txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        receipt = await rootProvider.getTransactionReceipt(resp3.hash);
        let txFee3 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        receipt = await rootProvider.getTransactionReceipt(resp4.hash);
        let txFee4 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        receipt = await childProvider.getTransactionReceipt(resp5.hash);
        let txFee5 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        receipt = await childProvider.getTransactionReceipt(resp6.hash);
        let txFee6 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        receipt = await childProvider.getTransactionReceipt(resp7.hash);
        let txFee7 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        receipt = await childProvider.getTransactionReceipt(resp8.hash);
        let txFee8 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

        let postIMXBalL1 = await rootIMX.balanceOf(rootTestWallet.address);
        let postETHBalL1 = await rootProvider.getBalance(rootTestWallet.address);
        let postWETHBalL1 = await rootWETH.balanceOf(rootTestWallet.address);
        let postERC20BalL1 = await rootCustomToken.balanceOf(rootTestWallet.address);
        let postIMXBalL2 = await childProvider.getBalance(childTestWallet.address);
        let postWIMXBalL2 = await childWIMX.balanceOf(childTestWallet.address);
        let postETHBalL2 = await childETH.balanceOf(childTestWallet.address);
        let postERC20BalL2 = await childCustomToken.balanceOf(childTestWallet.address);

        // Verify
        let expectedIMXBalL1 = preIMXBalL1.sub(amtL1).add(amtL2.mul(2));
        let expectedETHBalL1 = preETHBalL1.sub(amtL1).add(amtL2).sub(bridgeFeeL1.mul(4)).sub(txFee1).sub(txFee2).sub(txFee3).sub(txFee4);
        let expectedWETHBalL1 = preWETHBalL1.sub(amtL1);
        let expectedERC20BalL1 = preERC20BalL1.sub(amtL1).add(amtL2);
        let expectedIMXBalL2 = preIMXBalL2.add(amtL1).sub(amtL2).sub(bridgeFeeL2.mul(4)).sub(txFee5).sub(txFee6).sub(txFee7).sub(txFee8);
        let expectedWIMXBalL2 = preWIMXBalL2.sub(amtL2);
        let expectedETHBalL2 = preETHBalL2.add(amtL1.mul(2)).sub(amtL2);
        let expectedERC20BalL2 = preERC20BalL2.add(amtL1).sub(amtL2);
        expect(postIMXBalL1.toBigInt()).to.equal(expectedIMXBalL1.toBigInt());
        expect(postETHBalL1.toBigInt()).to.equal(expectedETHBalL1.toBigInt());
        expect(postWETHBalL1.toBigInt()).to.equal(expectedWETHBalL1.toBigInt());
        expect(postERC20BalL1.toBigInt()).to.equal(expectedERC20BalL1.toBigInt());
        expect(postIMXBalL2.toBigInt()).to.equal(expectedIMXBalL2.toBigInt());
        expect(postWIMXBalL2.toBigInt()).to.equal(expectedWIMXBalL2.toBigInt());
        expect(postETHBalL2.toBigInt()).to.equal(expectedETHBalL2.toBigInt());
        expect(postERC20BalL2.toBigInt()).to.equal(expectedERC20BalL2.toBigInt());

        // Test balance.
    }).timeout(2400000)

    async function depositIMX(sender: ethers.Wallet, amt: ethers.BigNumber, bridgeFee: ethers.BigNumber, recipient: string | null) {
        // Approve
        let resp = await rootIMX.connect(rootTestWallet).approve(rootBridge.address, amt);
        await waitForReceipt(resp.hash, rootProvider);

        if (recipient == null) {
            return rootBridge.connect(sender).deposit(rootIMX.address, amt, {
                value: bridgeFee,
            });
        } else {
            return rootBridge.connect(sender).depositTo(rootIMX.address, recipient, amt, {
                value: bridgeFee,
            });
        }
    }

    async function withdrawIMX(sender: ethers.Wallet, amt: ethers.BigNumber, bridgeFee: ethers.BigNumber, recipient: string | null) {
        let [priorityFee, maxFee] = await getFee(childProvider);
        
        if (recipient == null) {
            return childBridge.connect(sender).withdrawIMX(amt, {
                value: amt.add(bridgeFee),
                maxPriorityFeePerGas: priorityFee,
                maxFeePerGas: maxFee,
            });
        } else {
            return childBridge.connect(sender).withdrawIMXTo(recipient, amt, {
                value: amt.add(bridgeFee),
                maxPriorityFeePerGas: priorityFee,
                maxFeePerGas: maxFee,
            });
        }
    }

    async function withdrawWIMX(sender: ethers.Wallet, amt: ethers.BigNumber, bridgeFee: ethers.BigNumber, recipient: string | null) {
        let [priorityFee, maxFee] = await getFee(childProvider);

        // Wrap IMX
        let resp = await childWIMX.connect(sender).deposit({
            value: amt,
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);

        // Approve
        resp = await childWIMX.connect(sender).approve(childBridge.address, amt, {
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: maxFee,
        });
        await waitForReceipt(resp.hash, childProvider);

        if (recipient == null) {
            return childBridge.connect(sender).withdrawWIMX(amt, {
                value: bridgeFee,
                maxPriorityFeePerGas: priorityFee,
                maxFeePerGas: maxFee,
            });
        } else {
            return childBridge.connect(sender).withdrawWIMXTo(recipient, amt, {
                value: bridgeFee,
                maxPriorityFeePerGas: priorityFee,
                maxFeePerGas: maxFee,
            });
        }
    }

    async function depositETH(sender: ethers.Wallet, amt: ethers.BigNumber, bridgeFee: ethers.BigNumber, recipient: string | null) {
        if (recipient == null) {
            return rootBridge.connect(sender).depositETH(amt, {
                value: amt.add(bridgeFee),
            });
        } else {
            return rootBridge.connect(sender).depositToETH(recipient, amt, {
                value: amt.add(bridgeFee),
            });
        }
    }

    async function depositWETH(sender: ethers.Wallet, amt: ethers.BigNumber, bridgeFee: ethers.BigNumber, recipient: string | null) {
        // Wrap ETH
        let resp = await rootWETH.connect(sender).deposit({
            value: amt,
        })
        await waitForReceipt(resp.hash, rootProvider);

        // Approve
        resp = await rootBridge.connect(sender).approve(rootBridge.address, amt);
        await waitForReceipt(resp.hash, rootProvider);

        if (recipient == null) {
            return rootBridge.connect(sender).deposit(rootWETH.address, amt, {
                value: bridgeFee,
            });
        } else {
            return rootBridge.connect(sender).depositTo(rootWETH.address, recipient, amt, {
                value: bridgeFee,
            });
        }
    }

    async function withdrawETH(sender: ethers.Wallet, amt: ethers.BigNumber, bridgeFee: ethers.BigNumber, recipient: string | null) {
        let [priorityFee, maxFee] = await getFee(childProvider);

        if (recipient == null) {
            return childBridge.connect(sender).withdrawETH(amt, {
                value: bridgeFee,
                maxPriorityFeePerGas: priorityFee,
                maxFeePerGas: maxFee,
            });
        } else {
            return childBridge.connect(sender).withdrawETHTo(recipient, amt, {
                value: bridgeFee,
                maxPriorityFeePerGas: priorityFee,
                maxFeePerGas: maxFee,
            })
        }
    }
})