// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {FlowRateDetection} from "../../../src/root/flowrate/FlowRateDetection.sol";

contract FlowRateDetectionTest is Test, FlowRateDetection {
    function activateWithdrawalQueue() external {
        _activateWithdrawalQueue();
    }

    function deactivateWithdrawalQueue() external {
        _deactivateWithdrawalQueue();
    }

    function setFlowRateThreshold(address token, uint256 capacity, uint256 refillRate) external {
        _setFlowRateThreshold(token, capacity, refillRate);
    }

    function updateFlowRateBucket(address token, uint256 amount) external returns (bool delayWithdrawal) {
        return _updateFlowRateBucket(token, amount);
    }

    function setUp() public {}

    function testFuzz_SetFlowRateThreshold(address token, uint256 capacity, uint256 refillRate) public {
        vm.assume(token != address(0));
        vm.assume(capacity > 0);
        vm.assume(refillRate > 0);

        this.setFlowRateThreshold(token, capacity, refillRate);
        (uint256 currentCapacity,,, uint256 currentRefillRate) = this.flowRateBuckets(token);
        assertEq(currentCapacity, capacity, "Capacity should match");
        assertEq(currentRefillRate, refillRate, "Refill rate should match");
    }

    function testFuzz_RateLimit(address token, uint256 capacity, uint256 refillRate) public {
        vm.assume(token != address(0));
        vm.assume(refillRate > 0 && refillRate < type(uint256).max / 86400);
        vm.assume(capacity > 86400 * refillRate && capacity < type(uint256).max / 86400);

        this.setFlowRateThreshold(token, capacity, refillRate);
        (, uint256 depth,,) = this.flowRateBuckets(token);
        assertEq(depth, capacity, "Depth should match capacity");
        assertFalse(this.withdrawalQueueActivated(), "Withdrawal queue should not activate");

        // Use half capacity
        bool delay = this.updateFlowRateBucket(token, capacity / 2);
        assertFalse(delay, "Should not be delayed");
        (, depth,,) = this.flowRateBuckets(token);
        assertEq(depth, capacity - capacity / 2, "Depth should match half capacity");
        assertFalse(this.withdrawalQueueActivated(), "Withdrawal queue should not activate");

        // Use the other half capacity
        delay = this.updateFlowRateBucket(token, capacity / 2 + 2);
        assertFalse(delay, "Should not be delayed");
        (, depth,,) = this.flowRateBuckets(token);
        assertEq(depth, 0, "Depth should be 0");
        assertTrue(this.withdrawalQueueActivated(), "Withdrawal queue should activate");
    }
}
