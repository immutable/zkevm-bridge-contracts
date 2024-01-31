// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {IFlowRateWithdrawalQueueErrors} from "../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Utils} from "../../utils.t.sol";

contract RootERC20BridgeFlowRateForkTest is Test, Utils {
    address public constant NATIVE_ETH = address(0xeee);

    string[] private deployments = vm.envString("DEPLOYMENTS", ",");
    mapping(string => string) private rpcURLForEnv;
    mapping(string => uint256) private forkOfEnv;
    mapping(string => RootERC20BridgeFlowRate) private bridgeForEnv;
    mapping(string => address[]) private tokensForEnv;

    string private deployment;
    modifier forEachDeployment() {
        for (uint256 i; i < deployments.length; i++) {
            deployment = deployments[i];
            vm.selectFork(forkOfEnv[deployment]);
            _;
        }
    }

    function setUp() public {
        for (uint256 i; i < deployments.length; i++) {
            string memory dep = deployments[i];
            rpcURLForEnv[dep] = vm.envString(string.concat(dep, "_RPC_URL"));
            bridgeForEnv[dep] = RootERC20BridgeFlowRate(payable(vm.envAddress(string.concat(dep, "_BRIDGE_ADDRESS"))));
            tokensForEnv[dep] = vm.envAddress(string.concat(dep, "_FLOW_RATED_TOKENS"), ",");
            forkOfEnv[dep] = vm.createFork(rpcURLForEnv[dep]);
        }
    }

    function test_withdrawalQueueEnforcedWhenFlowRateExceeded() public forEachDeployment {
        console.log("Testing deployment: ", deployment);
        vm.selectFork(forkOfEnv[deployment]);
        _verifyWithdrawalQueueEnforcedForAllTokens(bridgeForEnv[deployment], tokensForEnv[deployment]);
    }

    function test_nonFlowRatedTokenIsQueued() public forEachDeployment {
        vm.selectFork(forkOfEnv[deployment]);
        RootERC20BridgeFlowRate bridge = bridgeForEnv[deployment];

        // preconditions
        assertFalse(bridge.withdrawalQueueActivated());

        // deploy and map a token
        ERC20 erc20 = new ERC20("Test Token", "TEST");
        bridge.mapToken{value: 100 gwei}(erc20);
        _giveBridgeFunds(address(erc20), address(erc20), 1 ether);

        // ensure withdrawals for the token, which does not have flow rate configured, is queued
        _sendWithdrawalMessage(bridge, address(erc20), address(1), 1 ether);
        _verifyWithdrawalWasQueued(bridge, address(erc20), address(1), 1 ether);

        // The queue should only affect the specific token
        assertFalse(bridge.withdrawalQueueActivated());
    }

    function test_withdrawalQueueDelayEnforced() public {}

    function test_withdrawalQueuedIfTransferIsTooLarge() public {

    }

    function test_queuedWithdrawalsCanBeFinalised() public {}

    function _verifyWithdrawalQueueEnforcedForAllTokens(RootERC20BridgeFlowRate bridge, address[] memory tokens)
    private
    {
        // preconditions
        assertFalse(bridge.withdrawalQueueActivated());
        assertGt(bridge.withdrawalDelay(), 0);

        uint256 snapshotId = vm.snapshot();
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            console.log("Testing flow rate for token: ", token);
            // exceed flow rate for any token
            _exceedFlowRateParameters(bridge, token, address(11));

            // Verify that any subsequent withdrawal by other users for other tokens gets queued
            address otherToken = tokens[(i + 1) % tokens.length];
            _sendWithdrawalMessage(bridge, otherToken, address(12), 1 ether);
            _verifyWithdrawalWasQueued(bridge, otherToken, address(12), 1 ether);

            // roll back state for subsequent test
            vm.revertTo(snapshotId);
        }
    }

    function _exceedFlowRateParameters(RootERC20BridgeFlowRate bridge, address token, address receiver) private {
        (uint256 capacity, uint256 depth,, uint256 refillRate) = bridge.flowRateBuckets(token);
        // check preconditions
        assertGt(bridge.largeTransferThresholds(token), 0);
        assertGt(capacity, 0);
        assertGt(refillRate, 0);
        assertEq(bridge.getPendingWithdrawalsLength(receiver), 0);

        uint256 txValue = bridge.largeTransferThresholds(token) - 1;
        uint256 numTxs = depth > txValue ? (depth / txValue) + 2 : 1;

        _giveBridgeFunds(address(bridge), token, numTxs * txValue * 2);

        // withdraw until flow rate is exceeded
        for (uint256 i = 0; i < numTxs; i++) {
            (, depth,,) = bridge.flowRateBuckets(token);
            _sendWithdrawalMessage(bridge, token, receiver, txValue);
        }

        assertTrue(bridge.withdrawalQueueActivated());
        _verifyWithdrawalWasQueued(bridge, token, receiver, txValue);
    }

    function _giveBridgeFunds(address bridge, address token, uint256 amount) private {
        if (token == NATIVE_ETH) {
            deal(bridge, amount);
        } else {
            deal(token, bridge, amount);
        }
    }

    function _verifyWithdrawalWasQueued(
        RootERC20BridgeFlowRate bridge,
        address token,
        address receiver,
        uint256 txValue
    ) private {
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        assertEq(bridge.getPendingWithdrawalsLength(receiver), 1, "Expected 1 pending withdrawal");
        RootERC20BridgeFlowRate.PendingWithdrawal[] memory pending = bridge.getPendingWithdrawals(receiver, indices);
        assertEq(pending[0].withdrawer, receiver, "Unexpected withdrawer");
        assertEq(pending[0].token, token, "Unexpected token");
        assertEq(pending[0].amount, txValue, "Unexpected amount");
    }

    // ensure subsequent withdrawals for any token, by any entity are queued
    //        _sendWithdrawMessage(NATIVE_ETH, receiver, receiver, txValue);

    /*
    Check that the withdrawal queue has been activated
    Check that the user has a pending withdrawal for the specified token
    */
    //
    //        assertEq(bridge.getPendingWithdrawalsLength(receiver1), 0);
    //
    //        //send one more tx to receiver2 and make sure it gets queued
    //        _sendWithdrawMessage(token, receiver2, receiver2, txValue);
    //
    //        //attempt to withdraw for receiver 1
    //        uint256 okTime1 = _attemptEarlyWithdraw(token, receiver1, txValue);
    //
    //        //attempt to withdraw for receiver 2
    //        uint256 okTime2 = _attemptEarlyWithdraw(token, receiver2, txValue);
    //
    //        //fast forward past withdrawal delay time and withdraw for receiver 1
    //        vm.warp(okTime1 + 1);
    //        bridge.finaliseQueuedWithdrawal(receiver1, 0);
    //
    //        //fast forward past withdrawal delay time and withdraw for receiver 2
    //        vm.warp(okTime2 + 1);
    //        bridge.finaliseQueuedWithdrawal(receiver2, 0);

    //    function _attemptEarlyWithdraw(address token, address receiver, uint256 txValue) public returns (uint256 okTime) {
    //        uint withdrawDelay = bridge.withdrawalDelay();
    //        uint256 pendingLength = bridge.getPendingWithdrawalsLength(receiver);
    //
    //        assertEq(pendingLength, 1);
    //
    //        uint256[] memory indices = new uint256[](1);
    //        indices[0] = 0;
    //
    //        RootERC20BridgeFlowRate.PendingWithdrawal[] memory pending =
    //                            bridge.getPendingWithdrawals(receiver, indices);
    //
    //        assertEq(pending.length, 1);
    //        assertEq(pending[0].withdrawer, receiver);
    //        assertEq(pending[0].token, token);
    //        assertEq(pending[0].amount, txValue);
    //        uint256 timestamp = pending[0].timestamp;
    //
    //        okTime = timestamp + withdrawDelay;
    //
    //        //deal some eth to pay withdraw gas
    //        vm.deal(address(this), 1 ether);
    //
    //        //try to process the withdrawal
    //        vm.expectRevert(
    //            abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector, timestamp, okTime)
    //        );
    //        bridge.finaliseQueuedWithdrawal(receiver, 0);
    //    }

    function _sendWithdrawalMessage(RootERC20BridgeFlowRate bridge, address token, address sender, uint256 txValue)
    private
    {
        _sendWithdrawMessage(bridge, token, sender, sender, txValue);
    }

    function _sendWithdrawMessage(
        RootERC20BridgeFlowRate bridge,
        address token,
        address sender,
        address receiver,
        uint256 txValue
    ) private {
        //prank as axelar sending a message to the adapter
        vm.startPrank(address(bridge.rootBridgeAdaptor()));
        bytes memory predictedPayload = abi.encode(bridge.WITHDRAW_SIG(), token, sender, receiver, txValue);
        bridge.onMessageReceive(predictedPayload);
        vm.stopPrank();
    }
}
