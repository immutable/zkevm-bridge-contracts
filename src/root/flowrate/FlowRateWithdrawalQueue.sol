// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    IFlowRateWithdrawalQueueEvents,
    IFlowRateWithdrawalQueueErrors
} from "../../interfaces/root/flowrate/IFlowRateWithdrawalQueue.sol";

/**
 * @title  Flow Rate Withdrawal Queue
 * @author Immutable Pty Ltd (Peter Robinson @drinkcoffee)
 * @notice Queue for withdrawals from the RootERC20BridgeFlowRate.
 * @dev    When withdrawals are delayed, they are put in the queue defined in this contract.
 *         The "queue" is actually a per-user array that gets bigger each time a withdrawal
 *         is added. Users can choose which withdrawals they are interested in and process
 *         just those withdrawals.
 *         Note: This code is part of RootERC20BridgeFlowRate. It has been separated out
 *         to make it easier to understand the functionality.
 *         Note that this contract is upgradeable.
 */
abstract contract FlowRateWithdrawalQueue is IFlowRateWithdrawalQueueEvents, IFlowRateWithdrawalQueueErrors {
    // One day in seconds.
    uint256 private constant DEFAULT_WITHDRAW_DELAY = 1 days;

    // A single token withdrawal for a user.
    struct PendingWithdrawal {
        // The account that initiated the crosschain transfer on the child chain.
        address withdrawer;
        // The token being withdrawn.
        address token;
        // The number of tokens.
        uint256 amount;
        // The time when the withdraw was requested. The pending withdrawal can be
        // withdrawn at time timestamp + withdrawalDelay. Note that it is possible
        // that the withdrawalDelay is updated while the withdrawal is still pending.
        uint256 timestamp;
    }
    // Mapping of user addresses to withdrawal queue.

    mapping(address => PendingWithdrawal[]) private pendingWithdrawals;

    // Information found in a search.
    struct FindPendingWithdrawal {
        // Index into array.
        uint256 index;
        // The number of tokens.
        uint256 amount;
        // The time when the withdraw was requested. The pending withdrawal can be
        // withdrawn at time timestamp + withdrawalDelay. Note that it is possible
        // that the withdrawalDelay is updated while the withdrawal is still pending.
        uint256 timestamp;
    }

    // The amount of time between a withdrawal request and a user being allowed to withdraw.
    uint256 public withdrawalDelay;

    /**
     * @notice Initilization function for FlowRateWithdrawalQueue
     */
    // slither-disable-next-line naming-convention
    function __FlowRateWithdrawalQueue_init() internal {
        _setWithdrawalDelay(DEFAULT_WITHDRAW_DELAY);
    }

    /**
     * @notice Set the delay in seconds between when a withdrawal is requested and
     *         when it can be withdrawn.
     * @param delay Withdrawal delay in seconds.
     */
    function _setWithdrawalDelay(uint256 delay) internal {
        uint256 previousDelay = withdrawalDelay;
        withdrawalDelay = delay;
        emit WithdrawalDelayUpdated(delay, previousDelay);
    }

    /**
     * @notice Add a withdrawal request to the queue.
     * @param receiver The account that the tokens should be transferred to.
     * @param withdrawer The account that initiated the crosschain transfer on the child chain.
     * @param token The token to withdraw.
     * @param amount The amount to withdraw.
     */
    function _enqueueWithdrawal(address receiver, address withdrawer, address token, uint256 amount) internal {
        // @TODO look at using a mapping instead of an array to make the withdraw function simpler
        if (token == address(0)) {
            revert TokenIsZero(receiver);
        }
        // solhint-disable-next-line not-rely-on-time
        PendingWithdrawal memory newPendingWithdrawal = PendingWithdrawal(withdrawer, token, amount, block.timestamp);
        uint256 index = pendingWithdrawals[receiver].length;
        pendingWithdrawals[receiver].push(newPendingWithdrawal);
        // solhint-disable-next-line not-rely-on-time
        emit EnQueuedWithdrawal(token, withdrawer, receiver, amount, block.timestamp, index);
    }

    /**
     * @notice Fetch a withdrawal request from the queue / array.
     * @param receiver The account that the tokens should be transferred to.
     * @return withdrawer The account on the child chain that initiated the crosschain transfer.
     * @return token The token to transfer to the receiver.
     * @return amount The number of tokens to transfer to the receiver.
     */
    function _processWithdrawal(address receiver, uint256 index)
        internal
        returns (address withdrawer, address token, uint256 amount)
    {
        PendingWithdrawal[] storage withdrawals = pendingWithdrawals[receiver];
        // Check if the request is beyond the end of the array.
        uint256 length = pendingWithdrawals[receiver].length;
        if (index >= pendingWithdrawals[receiver].length) {
            revert IndexOutsideWithdrawalQueue(length, index);
        }
        PendingWithdrawal storage withdrawal = withdrawals[index];

        withdrawer = withdrawal.withdrawer;
        token = withdrawal.token;
        amount = withdrawal.amount;

        if (token == address(0)) {
            revert WithdrawalAlreadyProcessed(receiver, index);
        }

        // Note: Add the withdrawal delay here, and not when enqueuing to allow changes
        // to withdrawal delay to have effect on in progress withdrawals.
        uint256 withdrawalTime = withdrawal.timestamp + withdrawalDelay;
        // slither-disable-next-line timestamp
        if (block.timestamp < withdrawalTime) {
            // solhint-disable-next-line not-rely-on-time
            revert WithdrawalRequestTooEarly(block.timestamp, withdrawalTime);
        }

        // Zeroize the old queue item to save some gas.
        delete withdrawals[index];

        emit ProcessedWithdrawal(token, withdrawer, receiver, amount, index);
    }

    /**
     * @notice Fetch the length of the pending withdrawals array for an address.
     * @param receiver The account to fetch the queue for.
     * @return length Length of array of pending withdrawals array.
     */
    function getPendingWithdrawalsLength(address receiver) external view returns (uint256 length) {
        length = pendingWithdrawals[receiver].length;
    }

    /**
     * @notice Fetch the queue of pending withdrawals for an address.
     * @param receiver The account to fetch the queue for.
     * @param indices Offsets into withdrawal queue to fetch information for.
     * @return pending Array of pending withdrawals. Zero fill are returned if the index is beyond the end of the queue.
     */
    function getPendingWithdrawals(address receiver, uint256[] calldata indices)
        external
        view
        returns (PendingWithdrawal[] memory pending)
    {
        PendingWithdrawal[] storage withdrawals = pendingWithdrawals[receiver];
        uint256 withdrawalsLength = withdrawals.length;
        pending = new PendingWithdrawal[](indices.length);
        for (uint256 i = 0; i < pending.length; i++) {
            if (indices[i] >= withdrawalsLength) {
                pending[i] = PendingWithdrawal(address(0), address(0), 0, 0);
            } else {
                pending[i] = withdrawals[indices[i]];
            }
        }
    }

    /**
     * @notice Fetch the queue of pending withdrawals for an address for a token type.
     * @param receiver The account to fetch the queue for.
     * @param token The token to locate withdrawals for.
     * @param startIndex Offset into withdrawal array to start search.
     * @param stopIndex Offset into withdrawal array to stop search.
     * @param maxFind Maximum number of items to locate.
     * @return found Array of information about pending withdrawals for the token.
     */
    function findPendingWithdrawals(
        address receiver,
        address token,
        uint256 startIndex,
        uint256 stopIndex,
        uint256 maxFind
    ) external view returns (FindPendingWithdrawal[] memory found) {
        PendingWithdrawal[] storage withdrawals = pendingWithdrawals[receiver];
        found = new FindPendingWithdrawal[](maxFind);
        uint256 foundIndex = 0;
        uint256 stop = stopIndex > withdrawals.length ? withdrawals.length : stopIndex;
        for (uint256 i = startIndex; i < stop && foundIndex < maxFind; i++) {
            if (withdrawals[i].token == token) {
                found[foundIndex] = FindPendingWithdrawal(i, withdrawals[i].amount, withdrawals[i].timestamp);
                foundIndex++;
            }
        }

        if (foundIndex != maxFind) {
            FindPendingWithdrawal[] memory temp = new FindPendingWithdrawal[](foundIndex);
            for (uint256 i = 0; i < foundIndex; i++) {
                temp[i] = found[i];
            }
            found = temp;
        }
    }

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gapFlowRateWithdrawalQueue;
}
