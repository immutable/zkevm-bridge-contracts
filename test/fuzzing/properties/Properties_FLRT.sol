// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_FLRT
 * @author 0xScourgedev
 * @notice Contains all FLRT invariants
 */
abstract contract Properties_FLRT is PropertiesBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INVARIANTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @custom:invariant FLRT-01: If imxCumulativeDepositLimit is not 0, the rootIMX token balance
     * of the root bridge should always be less than or equal to imxCumulativeDepositLimit
     */
    function invariant_FLRT_01() internal {
        if (states[1].imxCumulativeDepositLimit != 0) {
            fl.lte(states[1].rootIMXTokenBalOfRootBridge, states[1].imxCumulativeDepositLimit, FLRT_01);
        }
    }

    /**
     * @custom:invariant FLRT-02: If the withdrawal amount is greater than the largeTransferThreshold,
     * the withdrawal must be added to the user's withdrawal queue
     */
    function invariant_FLRT_02(address token, address recipient, uint256 amount) internal {
        if (amount > states[1].tokenStates[token].largeTransferThresholds) {
            fl.eq(
                states[1].actorStates[recipient].queueLength, states[0].actorStates[recipient].queueLength + 1, FLRT_02
            );
        }
    }

    /**
     * @custom:invariant FLRT-03: If the bucket capacity for a token is 0, then any withdrawal of
     * that token must be added to the user's withdrawal queue
     */
    function invariant_FLRT_03(address token, address recipient) internal {
        if (states[1].tokenStates[token].capacity == 0) {
            fl.eq(
                states[1].actorStates[recipient].queueLength, states[0].actorStates[recipient].queueLength + 1, FLRT_03
            );
        }
    }

    /**
     * @custom:invariant FLRT-04: If withdrawalQueueActivated is true, then any withdrawal of
     * any token must be added to the user's withdrawal queue
     */
    function invariant_FLRT_04(address recipient) internal {
        if (states[0].withdrawalQueueActivated) {
            fl.eq(
                states[1].actorStates[recipient].queueLength, states[0].actorStates[recipient].queueLength + 1, FLRT_04
            );
        }
    }

    /**
     * @custom:invariant FLRT-05: If finaliseQueuedWithdrawal is successfully called, then the
     * queued withdrawal initiated timestamp plus the withdrawal delay must be less than or equal
     * to the current block timestamp
     */
    function invariant_FLRT_05(FlowRateWithdrawalQueue.PendingWithdrawal memory withdrawal) internal {
        fl.lte(withdrawal.timestamp + states[1].withdrawalDelay, block.timestamp, FLRT_05);
    }

    /**
     * @custom:invariant FLRT-06: After a successful withdrawal of a non-zero amount on the root
     * bridge, if the bucket capacity is not zero, then the token bucket depth is never equal to
     * the bucket capacity
     */
    function invariant_FLRT_06(address token, uint256 amount) internal {
        if (amount == 0) return;

        if (states[1].tokenStates[token].capacity == 0) return;

        fl.neq(states[1].tokenStates[token].depth, states[1].tokenStates[token].capacity, FLRT_06);
    }

    /**
     * @custom:invariant FLRT-07: After a successful withdraw on the root bridge, if the
     * withdrawn amount is less than the minimum of the refill rate multiplied by the time
     * elapsed since last withdrawal and the bucket capacity minus the prior real bucket depth,
     * then the bucket depth strictly increases
     */
    function invariant_FLRT_07(address token, uint256 amount) internal {
        uint256 realDepth = fl.min(states[0].tokenStates[token].capacity, states[0].tokenStates[token].depth);

        if (
            amount
                >= fl.min(
                    states[0].tokenStates[token].refillRate * (block.timestamp - states[0].tokenStates[token].refillTime),
                    states[0].tokenStates[token].capacity - realDepth
                )
        ) return;

        fl.gt(states[1].tokenStates[token].depth, states[0].tokenStates[token].depth, FLRT_07);
    }

    /**
     * @custom:invariant FLRT-08: After a successful withdraw on the root bridge, the bucket depth
     * is always less than or equal to the bucket capacity
     */
    function invariant_FLRT_08(address token) internal {
        fl.lte(states[1].tokenStates[token].depth, states[1].tokenStates[token].capacity, FLRT_08);
    }

    /**
     * @custom:invariant FLRT-09: When the withdrawalQueue is not activated, after a successful
     * withdrawal of an amount less than the largeTransferThreshold on the root bridge and a withdrawal
     * was added to the user's withdrawal queue, the bucket depth is always 0
     */
    function invariant_FLRT_09(address token, address recipient, uint256 amount) internal {
        if (states[0].withdrawalQueueActivated) return;

        if (amount >= states[1].tokenStates[token].largeTransferThresholds) {
            return;
        }

        if (states[1].actorStates[recipient].queueLength == states[0].actorStates[recipient].queueLength) return;

        fl.eq(states[1].tokenStates[token].depth, 0, FLRT_09);
    }

    /**
     * @custom:invariant FLRT-10: When the withdrawalQueue is not activated, after a successful
     * withdrawal of an amount less than the largeTransferThreshold on the root bridge, if the
     * withdrawn amount is greater or equal to minimum of the refill rate multiplied by the time
     * elapsed since last withdrawal plus the prior real bucket depth and the bucket capacity,
     * then the withdrawal must be added to the user's withdrawal queue
     */
    function invariant_FLRT_10(address token, address recipient, uint256 amount) internal {
        if (states[0].withdrawalQueueActivated) return;

        if (amount >= states[1].tokenStates[token].largeTransferThresholds) {
            return;
        }

        uint256 realDepth = fl.min(states[0].tokenStates[token].capacity, states[0].tokenStates[token].depth);

        if (
            amount
                < fl.min(
                    states[0].tokenStates[token].refillRate * (block.timestamp - states[0].tokenStates[token].refillTime)
                        + realDepth,
                    states[0].tokenStates[token].capacity
                )
        ) return;

        fl.eq(states[1].actorStates[recipient].queueLength, states[0].actorStates[recipient].queueLength + 1, FLRT_10);
    }

    /**
     * @custom:invariant FLRT-11: If the depth of the token bucket is non-zero before a successful
     * withdrawal on the root bridge and the depth of the token bucket is zero after the withdrawal,
     * then the withdrawal queue must be activated
     */
    function invariant_FLRT_11(address token) internal {
        if (states[0].tokenStates[token].depth == 0 || states[1].tokenStates[token].depth != 0) return;

        fl.t(states[1].withdrawalQueueActivated, FLRT_11);
    }

    /**
     * @custom:invariant FLRT-12: After each successful withdrawal on the root bridge for a token with
     * a non-zero capacity, the bucket refillTime is always updated to the current block timestamp
     */
    function invariant_FLRT_12(address token) internal {
        if (states[1].tokenStates[token].capacity == 0) return;

        fl.eq(states[1].tokenStates[token].refillTime, block.timestamp, FLRT_12);
    }
}
