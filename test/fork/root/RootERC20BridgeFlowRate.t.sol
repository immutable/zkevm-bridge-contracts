// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {IFlowRateWithdrawalQueueErrors} from "../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";

import {Utils} from "../../utils.t.sol";

contract RootERC20BridgeFlowRateForkTest is Test, Utils {
    uint256 mainnetFork;
    RootERC20BridgeFlowRate public rootBridgeFlowRate;
    string MAINNET_RPC_URL = vm.envString("FORK_MAINNET_RPC_URL");
    address NATIVE_ETH = address(0x0000000000000000000000000000000000000Eee);
    uint256 withdrawDelay;
    
    // move to .env
    address payable rootBridgeAddress = payable(0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6);
    address rootAdapter = address(0x4f49B53928A71E553bB1B0F66a5BcB54Fd4E8932); 
    address receiver1 = address(0x111); 
    address receiver2 = address(0x222); 


    struct Bucket {
        uint256 capacity;
        uint256 depth;
        uint256 refillTime;
        uint256 refillRate;
    }

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        rootBridgeFlowRate = RootERC20BridgeFlowRate(rootBridgeAddress);
        withdrawDelay = rootBridgeFlowRate.withdrawalDelay();
        assertGt(withdrawDelay, 0);
    }

    function test_flowRateETH() public {
        uint256 largeThreshold = rootBridgeFlowRate.largeTransferThresholds(NATIVE_ETH);
        (uint256 capacity, uint256 depth, uint256 refillTime, uint256 refillRate) = rootBridgeFlowRate.flowRateBuckets(NATIVE_ETH); 

        // send 75% of the largeThreshold value
        uint256 txValue = ((largeThreshold / 100) * 75);

        uint256 numTxs = (depth / txValue) + 2;

        uint256 numTxsReceiver1 = 0;

        //deal enough ETH to the bridge to cover all the txs
        vm.deal(rootBridgeAddress, txValue * numTxs);

        while(depth > 0) {            
            //prank as axelar sending a message to the adapter
            vm.startPrank(rootAdapter);

            bytes memory predictedPayload1 = 
            abi.encode(rootBridgeFlowRate.WITHDRAW_SIG(), NATIVE_ETH, receiver1, receiver1, txValue);
            rootBridgeFlowRate.onMessageReceive(predictedPayload1);
            vm.stopPrank();

            (capacity, depth, refillTime, refillRate) = rootBridgeFlowRate.flowRateBuckets(NATIVE_ETH); 

            bool queueActivated = rootBridgeFlowRate.withdrawalQueueActivated();

            if (depth > 0) {
                assertFalse(queueActivated);
            } else {
                assertTrue(queueActivated);
            }

            numTxsReceiver1 += 1;
        }

        //sanity check we dealt the enough eth
        assertEq(numTxsReceiver1+1, numTxs);

        //send one more tx to receiver2 and make sure it gets queued
        vm.startPrank(rootAdapter);
        bytes memory predictedPayload2 = 
        abi.encode(rootBridgeFlowRate.WITHDRAW_SIG(), NATIVE_ETH, receiver2, receiver2, txValue);
        rootBridgeFlowRate.onMessageReceive(predictedPayload2);
        vm.stopPrank();

        uint256 pendingLength1 = rootBridgeFlowRate.getPendingWithdrawalsLength(receiver1);
        uint256 pendingLength2 = rootBridgeFlowRate.getPendingWithdrawalsLength(receiver2);

        //each receiver should have 1 queued tx
        assertEq(pendingLength1, 1);
        assertEq(pendingLength2, 1);

        uint256[] memory indices1 = new uint256[](1);
        indices1[0] = 0;

        RootERC20BridgeFlowRate.PendingWithdrawal[] memory pending1 =
            rootBridgeFlowRate.getPendingWithdrawals(receiver1, indices1);

        assertEq(pending1.length, 1);
        assertEq(pending1[0].withdrawer, receiver1);
        assertEq(pending1[0].token, NATIVE_ETH);
        assertEq(pending1[0].amount, txValue);
        uint256 timestamp1 = pending1[0].timestamp;

        uint256 okTime1 = timestamp1 + withdrawDelay;

         //deal some eth to pay withdraw gas
        vm.deal(address(this), 1 ether);

        //try to process withdraw 1
        vm.expectRevert(
            abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector, timestamp1, okTime1)
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawal(receiver1, 0);

        uint256[] memory indices2 = new uint256[](1);
        indices2[0] = 0;

        RootERC20BridgeFlowRate.PendingWithdrawal[] memory pending2 =
            rootBridgeFlowRate.getPendingWithdrawals(receiver2, indices2);

        assertEq(pending2.length, 1);
        assertEq(pending2[0].withdrawer, receiver2);
        assertEq(pending2[0].token, NATIVE_ETH);
        assertEq(pending2[0].amount, txValue);
        uint256 timestamp2 = pending2[0].timestamp;

        uint256 okTime2 = timestamp2 + withdrawDelay;

        //try to process withdraw 2
        vm.expectRevert(
            abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector, timestamp2, okTime2)
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawal(receiver2, 0);

        vm.warp(okTime1+1);

        rootBridgeFlowRate.finaliseQueuedWithdrawal(receiver1, 0);

        vm.warp(okTime2+1);

        rootBridgeFlowRate.finaliseQueuedWithdrawal(receiver2, 0);

        console2.log('success');

        //warp to time when withdraw can be processed

        //try to withdraw again
    }
}
