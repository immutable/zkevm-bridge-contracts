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
    address IMX = address(0xF57e7e7C23978C3cAEC3C3548E3D615c346e79fF);
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
        _flowRate(NATIVE_ETH);
    }

    function _flowRate(address token) public {
        uint256 largeThreshold = rootBridgeFlowRate.largeTransferThresholds(token);

        //only need depth returned
        (, uint256 depth, ,) = rootBridgeFlowRate.flowRateBuckets(token); 

        // send 75% of the largeThreshold value
        uint256 txValue = ((largeThreshold / 100) * 75);

        uint256 numTxs = (depth / txValue) + 2;

        if (token == NATIVE_ETH) {
            //deal enough ETH to the bridge to cover all the txs
            vm.deal(rootBridgeAddress, txValue * numTxs);
        } else {
            //@TODO ensure the bridge has enough tokens to cover all the txs
            console2.log('not eth');
        }

        //withdraw until queue is activated
        bool queueActivated = rootBridgeFlowRate.withdrawalQueueActivated();
        while(queueActivated == false) {            
            _sendWithdrawMessage(token, receiver1, receiver1, txValue);
            queueActivated = rootBridgeFlowRate.withdrawalQueueActivated();
        }

        //send one more tx to receiver2 and make sure it gets queued
        _sendWithdrawMessage(token, receiver2, receiver2, txValue);

        //attempt to withdraw for receiver 1
        uint256 okTime1 = _attemptEarlyWithdraw(token, receiver1, txValue);

        //attempt to withdraw for receiver 2
        uint256 okTime2 = _attemptEarlyWithdraw(token, receiver2, txValue);

        //fast forward past withdrawal delay time and withdraw for receiver 1
        vm.warp(okTime1+1);
        rootBridgeFlowRate.finaliseQueuedWithdrawal(receiver1, 0);

        //fast forward past withdrawal delay time and withdraw for receiver 2
        vm.warp(okTime2+1);
        rootBridgeFlowRate.finaliseQueuedWithdrawal(receiver2, 0);

    }

    function _attemptEarlyWithdraw(address token, address receiver, uint256 txValue) 
    public returns (uint256 okTime){

        uint256 pendingLength = rootBridgeFlowRate.getPendingWithdrawalsLength(receiver);

        assertEq(pendingLength, 1);

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        RootERC20BridgeFlowRate.PendingWithdrawal[] memory pending =
            rootBridgeFlowRate.getPendingWithdrawals(receiver, indices);

        assertEq(pending.length, 1);
        assertEq(pending[0].withdrawer, receiver);
        assertEq(pending[0].token, token);
        assertEq(pending[0].amount, txValue);
        uint256 timestamp = pending[0].timestamp;

        okTime = timestamp + withdrawDelay;

         //deal some eth to pay withdraw gas
        vm.deal(address(this), 1 ether);

        //try to process the withdrawal
        vm.expectRevert(
            abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector, timestamp, okTime)
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawal(receiver, 0);
    }

    function _sendWithdrawMessage(address token, address sender, address receiver, uint256 txValue) public {
        //prank as axelar sending a message to the adapter
        vm.startPrank(rootAdapter);
        bytes memory predictedPayload = 
        abi.encode(rootBridgeFlowRate.WITHDRAW_SIG(), token, sender, receiver, txValue);
        rootBridgeFlowRate.onMessageReceive(predictedPayload);
        vm.stopPrank();
    }
}
