// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {FlowRateWithdrawalQueue} from "../../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";
import {
    IFlowRateWithdrawalQueueEvents,
    IFlowRateWithdrawalQueueErrors
} from "../../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";

contract FlowRateWithdrawalQueueT is FlowRateWithdrawalQueue {  
    uint256 public constant DEFAULT_WITHDRAW_DELAY = 60 * 60 * 24;



    function init() external {
        __FlowRateWithdrawalQueue_init();
    }
    function setWithdrawalDelay(uint256 delay) external {
        _setWithdrawalDelay(delay);
    }
    function enqueueWithdrawal(address receiver, address withdrawer, address token, uint256 amount) external {
        _enqueueWithdrawal(receiver, withdrawer, token, amount);
    }
    function processWithdrawal(
        address receiver, uint256 index
    ) external returns (address withdrawer, address token, uint256 amount) {
        return _processWithdrawal(receiver, index);
    }

}


abstract contract FlowRateWithdrawalQueueTests is Test, IFlowRateWithdrawalQueueErrors {
    // Indicates a withdrawal has been queued.
    event QueuedWithdrawal(address indexed token, address indexed withdrawer, address indexed receiver, uint256 amount, uint256 timestamp, uint256 index);
    // Indicates a withdrawal has been processed.
    event ProcessedWithdrawal(address indexed token, address indexed withdrawer, address indexed receiver, uint256 amount, uint256 index);

    FlowRateWithdrawalQueueT flowRateWithdrawalQueue;

    function setUp() public virtual  {
        flowRateWithdrawalQueue = new FlowRateWithdrawalQueueT();
    }

    function checkValuesZero(FlowRateWithdrawalQueue.PendingWithdrawal memory pending) internal { 
        checkValues(pending, address(0), address(0), 0, 0);
    }

    function checkValues(FlowRateWithdrawalQueue.PendingWithdrawal memory pending, 
            address withdrawer, address token, uint256 amount, uint256 time) internal {
        assertEq(pending.withdrawer, withdrawer, "Withdrawer");
        assertEq(pending.token, token, "Token");
        assertEq(pending.amount, amount, "Amount");
        assertEq(pending.timestamp, time, "Time stamp");
    }

    function checkFindValues(FlowRateWithdrawalQueue.FindPendingWithdrawal memory pending, 
            uint256 index, uint256 amount, uint256 time) internal {
        assertEq(pending.index, index, "Index");
        assertEq(pending.amount, amount, "Amount");
        assertEq(pending.timestamp, time, "Time stamp");
    }

}


contract UninitializedFlowRateWithdrawalQueueTests is FlowRateWithdrawalQueueTests {
    address constant USER = address(125);
    address constant TOKEN = address(126);

    function testUninitWithdrawalQueue() public {
        uint256 delay = flowRateWithdrawalQueue.withdrawalDelay();
        assertEq(delay, 0, "Delay");
    }

    function testEmptyProcessWithdrawal() public {
        vm.expectRevert(abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.IndexOutsideWithdrawalQueue.selector, 0, 0));
        flowRateWithdrawalQueue.processWithdrawal(USER, 0);
    }

    function testEmptyPendingWithdrawalsLength() public {
        uint256 len = flowRateWithdrawalQueue.getPendingWithdrawalsLength(USER);
        assertEq(len, 0, "Length");
    }

    function testEmptyGetPendingWithdrawals1() public {
        uint256[] memory indices = new uint256[](0);
        FlowRateWithdrawalQueue.PendingWithdrawal[] memory pending =
            flowRateWithdrawalQueue.getPendingWithdrawals(USER, indices);
        assertEq(pending.length, 0, "Length");
    }

    function testEmptyGetPendingWithdrawals2() public {
        uint256[] memory indices = new uint256[](1);
        indices[0] = 5;
        FlowRateWithdrawalQueue.PendingWithdrawal[] memory pending =
            flowRateWithdrawalQueue.getPendingWithdrawals(USER, indices);
        assertEq(pending.length, 1, "Length");
        checkValuesZero(pending[0]);
    }

    function testEmptyFindPendingWithdrawals() public {
        FlowRateWithdrawalQueue.FindPendingWithdrawal[] memory pending =
            flowRateWithdrawalQueue.findPendingWithdrawals(USER, TOKEN, 0, 1000, 100);
        assertEq(pending.length, 0, "Length");
    }
}

contract ControlFlowRateWithdrawalQueueTests is FlowRateWithdrawalQueueTests {
    event WithdrawalDelayUpdated(uint256 delay);

    function testInitWithdrawalQueue() public {
        uint256 expectedDelay = flowRateWithdrawalQueue.DEFAULT_WITHDRAW_DELAY();
        vm.expectEmit(false, false, false, true);
        emit WithdrawalDelayUpdated(expectedDelay);
        flowRateWithdrawalQueue.init();
        uint256 delay = flowRateWithdrawalQueue.withdrawalDelay();
        assertEq(delay, expectedDelay, "Delay");
    }

    function testSetWithdrawalDelay() public {
        uint256 expectedDelay = 1999;
        flowRateWithdrawalQueue.init();
        vm.expectEmit(false, false, false, true);
        emit WithdrawalDelayUpdated(expectedDelay);
        flowRateWithdrawalQueue.setWithdrawalDelay(expectedDelay);
        uint256 delay = flowRateWithdrawalQueue.withdrawalDelay();
        assertEq(delay, expectedDelay, "Delay");
    }
}

contract OperationalFlowRateWithdrawalQueueTests is FlowRateWithdrawalQueueTests {
    address constant RUSER1 = address(12345);
    address constant RUSER2 = address(12346);
    address constant WUSER1 = address(12223345);
    address constant WUSER2 = address(11112346);

    address constant TOKEN1 = address(1000012);
    address constant TOKEN2 = address(100123);
    address constant TOKEN3 = address(100456);

    uint256 public withdrawalDelay;

    function setUp() public override {
        super.setUp();
        flowRateWithdrawalQueue.init();

        withdrawalDelay = flowRateWithdrawalQueue.withdrawalDelay();
    }

    function testEnqueueWithdrawal() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount = 123;
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN1, WUSER1, RUSER1, amount, now1, 0);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount);
        uint256 len = flowRateWithdrawalQueue.getPendingWithdrawalsLength(RUSER1);
        assertEq(len, 1, "Pending withdrawal length");
    }

    function testEnqueueTwoWithdrawals() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        uint256 amount2 = 456;
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN1, WUSER1, RUSER1, amount1, now1, 0);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);
        uint256 now2 = 200;
        vm.warp(now2);
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN2, WUSER2, RUSER1, amount2, now2, 1);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER2, TOKEN2, amount2);

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        FlowRateWithdrawalQueue.PendingWithdrawal[] memory pending = flowRateWithdrawalQueue.getPendingWithdrawals(RUSER1, indices);
        assertEq(pending.length, 2, "Pending withdrawal length");
        assertEq(pending[0].withdrawer, WUSER1, "Withdrawer");
        assertEq(pending[0].token, TOKEN1, "Token");
        assertEq(pending[0].amount, amount1, "Amount");
        assertEq(pending[0].timestamp, now1, "Timestamp");
        assertEq(pending[1].withdrawer, WUSER2, "Withdrawer");
        assertEq(pending[1].token, TOKEN2, "Token");
        assertEq(pending[1].amount, amount2, "Amount");
        assertEq(pending[1].timestamp, now2, "Timestamp");
    }

    function testEnqueueZeroToken() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        address zeroToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.TokenIsZero.selector, RUSER1));
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, zeroToken, amount1);
    }

    function testProcessOneEntry() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);

        uint256 now2 = now1 + withdrawalDelay;
        vm.warp(now2);

        vm.expectEmit(true, true, true, true);
        emit ProcessedWithdrawal(TOKEN1, WUSER1, RUSER1, amount1, 0);
        (address withdrawer, address token, uint256 amount) = flowRateWithdrawalQueue.processWithdrawal(RUSER1, 0);
        assertEq(withdrawer, WUSER1, "Withdrawer");
        assertEq(token, TOKEN1, "Token");
        assertEq(amount, amount1, "Amount");
    }

    function testProcessTwoEntries() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);
        uint256 now2 = 200;
        vm.warp(now2);
        uint256 amount2 = 456;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER2, TOKEN2, amount2);

        uint256 now3 = now2 + withdrawalDelay;
        vm.warp(now3);

        vm.expectEmit(true, true, true, true);
        emit ProcessedWithdrawal(TOKEN1, WUSER1, RUSER1, amount1, 0);
        (address withdrawer, address token, uint256 amount) = flowRateWithdrawalQueue.processWithdrawal(RUSER1, 0);
        assertEq(withdrawer, WUSER1, "Withdrawer");
        assertEq(token, TOKEN1, "Token");
        assertEq(amount, amount1, "Amount");
        
        vm.expectEmit(true, true, true, true);
        emit ProcessedWithdrawal(TOKEN2, WUSER2, RUSER1, amount2, 1);
        (withdrawer, token, amount) = flowRateWithdrawalQueue.processWithdrawal(RUSER1, 1);
        assertEq(withdrawer, WUSER2, "Withdrawer");
        assertEq(token, TOKEN2, "Token");
        assertEq(amount, amount2, "Amount");
    }
    
    function testProcessOutOfOrder() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);
        uint256 now2 = 200;
        vm.warp(now2);
        uint256 amount2 = 456;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER2, TOKEN2, amount2);

        uint256 now3 = 300;
        vm.warp(now3);
        uint256 amount3 = 789;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN3, amount3);

        uint256 now4 = now3 + withdrawalDelay;
        vm.warp(now4);

        vm.expectEmit(true, true, true, true);
        emit ProcessedWithdrawal(TOKEN2, WUSER2, RUSER1, amount2, 1);
        (address withdrawer, address token, uint256 amount) = flowRateWithdrawalQueue.processWithdrawal(RUSER1, 1);
        assertEq(withdrawer, WUSER2, "Withdrawer");
        assertEq(token, TOKEN2, "Token");
        assertEq(amount, amount2, "Amount");

        vm.expectEmit(true, true, true, true);
        emit ProcessedWithdrawal(TOKEN3, WUSER1, RUSER1, amount3, 2);
       (withdrawer, token, amount) = flowRateWithdrawalQueue.processWithdrawal(RUSER1, 2);
        assertEq(withdrawer, WUSER1, "Withdrawer");
        assertEq(token, TOKEN3, "Token");
        assertEq(amount, amount3, "Amount");

        vm.expectEmit(true, true, true, true);
        emit ProcessedWithdrawal(TOKEN1, WUSER1, RUSER1, amount1, 0);
        (withdrawer, token, amount) = flowRateWithdrawalQueue.processWithdrawal(RUSER1, 0);
        assertEq(withdrawer, WUSER1, "Withdrawer");
        assertEq(token, TOKEN1, "Token");
        assertEq(amount, amount1, "Amount");
    }
    

    function testProcessOutside() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);

        uint256 now2 = now1 + withdrawalDelay;
        vm.warp(now2);

        uint256 outOfBoundsIndex = 1;

        vm.expectRevert(abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.IndexOutsideWithdrawalQueue.selector, 1, 1));
        flowRateWithdrawalQueue.processWithdrawal(RUSER1, outOfBoundsIndex);
    }

    function testProcessTooEarly() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);

        uint256 tooEarly = now1 + withdrawalDelay - 1;
        vm.warp(tooEarly);
        uint256 okTime = now1 + withdrawalDelay;

        vm.expectRevert(abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector, tooEarly, okTime));
        flowRateWithdrawalQueue.processWithdrawal(RUSER1, 0);
    }

    function testAlreadyProcessed() public {
        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);

        uint256 okTime = now1 + withdrawalDelay;
        vm.warp(okTime);
        flowRateWithdrawalQueue.processWithdrawal(RUSER1, 0);

        vm.expectRevert(abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.WithdrawalAlreadyProcessed.selector, RUSER1, 0));
        flowRateWithdrawalQueue.processWithdrawal(RUSER1, 0);
    }

    function testGetPendingWithdrawals() public {
        uint256[] memory indices = new uint256[](4);
        indices[0] = 2;
        indices[1] = 0;
        indices[2] = 5;
        indices[3] = 1;
        FlowRateWithdrawalQueue.PendingWithdrawal[] memory pending =
            flowRateWithdrawalQueue.getPendingWithdrawals(RUSER1, indices);
        assertEq(pending.length, 4, "Length");
        checkValuesZero(pending[0]);
        checkValuesZero(pending[1]);
        checkValuesZero(pending[2]);
        checkValuesZero(pending[3]);

        uint256 now1 = 100;
        vm.warp(now1);
        uint256 amount1 = 123;
        uint256 amount2 = 456;
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN1, WUSER1, RUSER1, amount1, now1, 0);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);
        uint256 now2 = 200;
        vm.warp(now2);
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN2, WUSER2, RUSER1, amount2, now2, 1);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER2, TOKEN2, amount2);

        pending = flowRateWithdrawalQueue.getPendingWithdrawals(RUSER1, indices);
        assertEq(pending.length, 4, "Length");
        checkValuesZero(pending[0]);
        checkValues(pending[1], WUSER1, TOKEN1, amount1, now1);
        checkValuesZero(pending[2]);
        checkValues(pending[3], WUSER2, TOKEN2, amount2, now2);
    }


    function testFindPendingWithdrawals() public {
        uint256 amount1 = 123;
        uint256 amount2 = 456;
        uint256 amount3 = 777;
        uint256 amount4 = 888;
        uint256 amount5 = 999;
        uint256 now1 = 100;
        vm.warp(now1);
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN1, WUSER1, RUSER1, amount1, now1, 0);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount1);
        uint256 now2 = 200;
        vm.warp(now2);
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN2, WUSER2, RUSER1, amount2, now2, 1);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER2, TOKEN2, amount2);
        uint256 now3 = 300;
        vm.warp(now3);
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN2, WUSER2, RUSER1, amount3, now3, 2);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER2, TOKEN2, amount3);
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN2, WUSER2, RUSER1, amount4, now3, 3);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER2, TOKEN2, amount4);
        vm.expectEmit(true, true, true, true);
        emit QueuedWithdrawal(TOKEN1, WUSER1, RUSER1, amount5, now3, 4);
        flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount5);

        FlowRateWithdrawalQueue.FindPendingWithdrawal[] memory pending =
            flowRateWithdrawalQueue.findPendingWithdrawals(RUSER1, TOKEN1, 0, 100, 100);
        assertEq(pending.length, 2, "Length");
        checkFindValues(pending[0], 0, amount1, now1);
        checkFindValues(pending[1], 4, amount5, now3);

        pending = flowRateWithdrawalQueue.findPendingWithdrawals(RUSER1, TOKEN2, 0, 100, 3);
        assertEq(pending.length, 3, "Length");
        checkFindValues(pending[0], 1, amount2, now2);
        checkFindValues(pending[1], 2, amount3, now3);
        checkFindValues(pending[2], 3, amount4, now3);
    }

    function testEnqueueProcessMultiple() public {
        uint256 timeNow = 100;
        // Loop around some times enqueuing and then dequeuing. 
        for (uint256 i = 0; i < 5; i++) {
            timeNow += 100;
            vm.warp(timeNow);
            uint256 amount = timeNow + 1;
            vm.expectEmit(true, true, true, true);
            emit QueuedWithdrawal(TOKEN1, WUSER1, RUSER1, amount, timeNow, i);
            flowRateWithdrawalQueue.enqueueWithdrawal(RUSER1, WUSER1, TOKEN1, amount);
            uint256 enqueueTime = timeNow;
            timeNow += withdrawalDelay;
            vm.warp(timeNow);

            FlowRateWithdrawalQueue.FindPendingWithdrawal[] memory pending =
                flowRateWithdrawalQueue.findPendingWithdrawals(RUSER1, TOKEN1, 0, 100, 1);
            assertEq(pending.length, 1, "Length");
            checkFindValues(pending[0], i, amount, enqueueTime);

            vm.expectEmit(true, true, true, true);
            emit ProcessedWithdrawal(TOKEN1, WUSER1, RUSER1, amount, i);
            (address withdrawer, address token, uint256 amountOut) = flowRateWithdrawalQueue.processWithdrawal(RUSER1, i);
            assertEq(withdrawer, WUSER1, "Withdrawer");
            assertEq(token, TOKEN1, "Token");
            assertEq(amountOut, amount, "Amount");
        }
    }
}




