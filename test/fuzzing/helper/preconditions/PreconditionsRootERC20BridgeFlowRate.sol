// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

/**
 * @title PreconditionsRootERC20BridgeFlowRate
 * @author 0xScourgedev
 * @notice Contains all preconditions for RootERC20BridgeFlowRate
 */
abstract contract PreconditionsRootERC20BridgeFlowRate is PreconditionsBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct DepositParams {
        address rootToken;
        uint256 amount;
        uint256 value;
    }

    struct DepositETHParams {
        uint256 amount;
        uint256 value;
    }

    struct DepositToParams {
        address rootToken;
        address receiver;
        uint256 amount;
        uint256 value;
    }

    struct DepositToETHParams {
        address receiver;
        uint256 amount;
        uint256 value;
    }

    struct FinaliseQueuedWithdrawalParams {
        address receiver;
        uint256 index;
    }

    struct FinaliseQueuedWithdrawalsAggregatedParams {
        address receiver;
        address token;
        uint256[] indices;
    }

    struct OnMessageReceiveRootParams {
        bytes data;
        address rootToken;
        address receiver;
        uint256 amount;
    }

    struct SetRateControlThresholdParams {
        address token;
        uint256 capacity;
        uint256 refillRate;
        uint256 largeTransferThreshold;
    }

    struct SetWithdrawalDelayParams {
        uint256 delay;
    }

    struct UpdateImxCumulativeDepositLimitParams {
        uint256 newImxCumulativeDepositLimit;
    }

    struct UpdateRootBridgeAdaptorParams {
        address newRootBridgeAdaptor;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PRECONDITIONS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Preconditions for the activateWithdrawalQueue function for the root bridge
     * @custom:precondition The withdrawal queue is not already activated
     */
    function activateWithdrawalQueuePreconditions() internal {
        if (RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).withdrawalQueueActivated()) {
            revert ClampFail("Withdrawal queue already activated");
        }
    }

    /**
     * @notice Preconditions for the deactivateWithdrawalQueue function for the root bridge
     * @custom:precondition The withdrawal queue is currently activated
     */
    function deactivateWithdrawalQueuePreconditions() internal {
        if (!RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).withdrawalQueueActivated()) {
            revert ClampFail("Withdrawal queue already deactivated");
        }
    }

    /**
     * @notice Preconditions for the deposit function for the root bridge
     * @custom:precondition Give a small chance for the transaction to go through when the root bridge is paused
     * @custom:precondition Select a valid root token to deposit
     * @custom:precondition The amount is clamped between 0 and the current actor's root token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function depositPreconditions(uint8 rootTokenSelector, uint256 amount, uint256 value)
        internal
        returns (DepositParams memory)
    {
        if (
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()
                && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0
        ) {
            revert ClampFail("Root bridge is paused");
        }
        address rootToken = rootTokens[rootTokenSelector % rootTokens.length];
        return DepositParams({
            rootToken: rootToken,
            amount: fl.clamp(amount, 0, ChildERC20(rootToken).balanceOf(currentActor)),
            value: fl.clamp(value, 0, currentActor.balance)
        });
    }

    /**
     * @notice Preconditions for the depositETH function for the root bridge
     * @custom:precondition Give a small chance for the transaction to go through when the root bridge is paused
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     * @custom:precondition The amount is clamped between 0 and the value plus a small gap for coverage purposes
     */
    function depositETHPreconditions(uint256 amount, uint256 value) internal returns (DepositETHParams memory) {
        if (
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()
                && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0
        ) {
            revert ClampFail("Root bridge is paused");
        }
        value = fl.clamp(value, 0, currentActor.balance);
        amount = fl.clamp(amount, 0, value + COVERAGE_GAP);
        return DepositETHParams({amount: amount, value: value});
    }

    /**
     * @notice Preconditions for the depositTo function for the root bridge
     * @custom:precondition Give a small chance for the transaction to go through when the root bridge is paused
     * @custom:precondition Select a valid root token to deposit
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition The amount is clamped between 0 and the current actor's root token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function depositToPreconditions(uint8 rootTokenSelector, uint8 receiverSelector, uint256 amount, uint256 value)
        internal
        returns (DepositToParams memory)
    {
        if (
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()
                && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0
        ) {
            revert ClampFail("Root bridge is paused");
        }
        address rootToken = rootTokens[rootTokenSelector % rootTokens.length];
        return DepositToParams({
            rootToken: rootToken,
            receiver: USERS[receiverSelector % USERS.length],
            amount: fl.clamp(amount, 0, ChildERC20(rootToken).balanceOf(currentActor)),
            value: fl.clamp(value, 0, currentActor.balance)
        });
    }

    /**
     * @notice Preconditions for the depositToETH function for the root bridge
     * @custom:precondition Give a small chance for the transaction to go through when the root bridge is paused
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     * @custom:precondition The amount is clamped between 0 and the value plus a small gap for coverage purposes
     */
    function depositToETHPreconditions(uint8 receiverSelector, uint256 amount, uint256 value)
        internal
        returns (DepositToETHParams memory)
    {
        if (
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()
                && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0
        ) {
            revert ClampFail("Root bridge is paused");
        }
        value = fl.clamp(value, 0, currentActor.balance);
        amount = fl.clamp(amount, 0, value + COVERAGE_GAP);
        return DepositToETHParams({receiver: USERS[receiverSelector % USERS.length], amount: amount, value: value});
    }

    /**
     * @notice Preconditions for the finaliseQueuedWithdrawal function for the root bridge
     * @custom:precondition Give a small chance for the transaction to go through when the root bridge is paused
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition The index is clamped between 0 and the pending withdrawals length plus 1 for coverage purposes
     */
    function finaliseQueuedWithdrawalPreconditions(uint8 receiverSelector, uint256 index)
        internal
        returns (FinaliseQueuedWithdrawalParams memory)
    {
        if (
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()
                && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0
        ) {
            revert ClampFail("Root bridge is paused");
        }
        address receiver = USERS[receiverSelector % USERS.length];
        index = fl.clamp(
            index,
            0,
            FlowRateWithdrawalQueue(payable(rootERC20BridgeFlowRate)).getPendingWithdrawalsLength(receiver) + 1
        );
        return FinaliseQueuedWithdrawalParams({receiver: receiver, index: index});
    }

    /**
     * @notice Preconditions for the finaliseQueuedWithdrawalsAggregated function for the root bridge
     * @custom:precondition Give a small chance for the transaction to go through when the root bridge is paused
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition Select a valid root token to finalize the withdrawal for
     * @custom:precondition The length is clamped between 0 and the pending withdrawals length for the
     * receiver plus 1 for coverage purposes
     *
     * @custom:precondition Indices values are generated from the entropy value
     */
    function finaliseQueuedWithdrawalsAggregatedPreconditions(
        uint8 receiverSelector,
        uint8 tokenSelector,
        uint256 length,
        uint256 entropy
    ) internal returns (FinaliseQueuedWithdrawalsAggregatedParams memory) {
        if (
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()
                && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0
        ) {
            revert ClampFail("Root bridge is paused");
        }
        address receiver = USERS[receiverSelector % USERS.length];
        address token = rootTokens[tokenSelector % rootTokens.length];
        uint256 maxLength =
            FlowRateWithdrawalQueue(payable(rootERC20BridgeFlowRate)).getPendingWithdrawalsLength(receiver) + 1;
        length = fl.clamp(length, 0, maxLength);
        return FinaliseQueuedWithdrawalsAggregatedParams({
            receiver: receiver,
            token: token,
            indices: getIndicesFromEntropy(entropy, length, maxLength)
        });
    }

    /**
     * @notice Preconditions for the onMessageReceive function for the root bridge
     * @custom:precondition Give a small chance for the transaction to go through when the root bridge is paused
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition Set the withdrawer to a valid user address
     * @custom:precondition Select a valid root token to finalize the withdrawal for
     * @custom:precondition The amount is clamped between 0 and the root bridge balance of the selected token
     * minus the queued amounts
     *
     * @custom:precondition The amount of pending withdrawals cannot exceed the maximum in queue constant
     * @custom:precondition Have a chance for the selector to be an invalid signature
     * @custom:precondition All inputs are encoded into bytes
     */
    function onMessageReceiveRootPreconditions(
        bool isWithdraw,
        uint8 rootTokenSelector,
        uint8 withdrawerSelector,
        uint8 receiverSelector,
        uint256 amount
    ) internal returns (OnMessageReceiveRootParams memory) {
        if (
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()
                && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0
        ) {
            revert ClampFail("Root bridge is paused");
        }
        rootTokens.push(NATIVE_ETH);
        address receiver = USERS[receiverSelector % USERS.length];
        address rootToken = rootTokens[rootTokenSelector % rootTokens.length];
        uint256 rootBridgeBalance = 0;
        if (rootToken == NATIVE_ETH) {
            rootBridgeBalance += rootERC20BridgeFlowRate.balance;
        } else {
            rootBridgeBalance += ChildERC20(rootToken).balanceOf(rootERC20BridgeFlowRate);
        }

        {
            uint256 rootBridgeQueuedAmounts = 0;

            for (uint256 i = 0; i < USERS.length; i++) {
                uint256 pendingLength =
                    FlowRateWithdrawalQueue(payable(rootERC20BridgeFlowRate)).getPendingWithdrawalsLength(USERS[i]);

                if (pendingLength > MAX_IN_QUEUE) {
                    revert ClampFail("Too many pending withdrawals");
                }

                FlowRateWithdrawalQueue.FindPendingWithdrawal[] memory pending = FlowRateWithdrawalQueue(
                    payable(rootERC20BridgeFlowRate)
                ).findPendingWithdrawals(USERS[i], rootToken, 0, pendingLength, MAX_IN_QUEUE);
                for (uint256 j = 0; j < pending.length; j++) {
                    rootBridgeQueuedAmounts += pending[j].amount;
                }
            }

            amount = fl.clamp(amount, 0, rootBridgeBalance - rootBridgeQueuedAmounts);
        }
        bytes32 selector = isWithdraw ? WITHDRAW_SIG : NOTHING_SIG;
        bytes memory data = abi.encode(
            selector,
            rootTokens[rootTokenSelector % rootTokens.length],
            USERS[withdrawerSelector % USERS.length],
            receiver,
            amount
        );

        rootTokens.pop();
        return OnMessageReceiveRootParams({data: data, rootToken: rootToken, receiver: receiver, amount: amount});
    }

    /**
     * @notice Preconditions for the pause function for the root bridge
     * @custom:precondition The root bridge is not already paused
     */
    function pauseRootPreconditions() internal {
        if (RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()) {
            revert ClampFail("Root bridge already paused");
        }
    }

    /**
     * @notice Preconditions for the setRateControlThreshold function for the root bridge
     * @custom:precondition Select a valid root token to set the rate control thresholds for
     * @custom:precondition The capacity is clamped between 0 and the total supply of the token
     * @custom:precondition The refill rate is clamped between 0 and the capacity plus a small gap for coverage purposes
     * @custom:precondition The large transfer threshold is clamped between 0 and the total supply
     * of the token plus a small gap for coverage purposes
     */
    function setRateControlThresholdPreconditions(
        uint8 tokenSelector,
        uint256 capacity,
        uint256 refillRate,
        uint256 largeTransferThreshold
    ) internal returns (SetRateControlThresholdParams memory) {
        address token = rootTokens[tokenSelector % rootTokens.length];
        capacity = fl.clamp(capacity, 0, ChildERC20(token).totalSupply());
        refillRate = fl.clamp(refillRate, 0, capacity + MAX_REFILL_RATE_GAP);
        largeTransferThreshold =
            fl.clamp(largeTransferThreshold, 0, ChildERC20(token).totalSupply() + MAX_REFILL_RATE_GAP);
        return SetRateControlThresholdParams({
            token: token,
            capacity: capacity,
            refillRate: refillRate,
            largeTransferThreshold: largeTransferThreshold
        });
    }

    /**
     * @notice Preconditions for the setWithdrawalDelay function for the root bridge
     * @custom:precondition The delay is clamped between 0 and the maximum withdrawal delay
     */
    function setWithdrawalDelayPreconditions(uint256 delay) internal returns (SetWithdrawalDelayParams memory) {
        return SetWithdrawalDelayParams({delay: fl.clamp(delay, 0, MAX_WITHDRAWAL_DELAY)});
    }

    /**
     * @notice Preconditions for the unpause function for the root bridge
     * @custom:precondition The root bridge is not currently unpaused
     */
    function unpauseRootPreconditions() internal {
        if (!RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).paused()) {
            revert ClampFail("Root bridge already unpaused");
        }
    }

    /**
     * @notice Preconditions for the updateImxCumulativeDepositLimit function for the root bridge
     * @custom:precondition The new IMX cumulative deposit limit is clamped between 0 and the
     * maximum ERC20 balance multiplied by the root IMX token decimals
     */
    function updateImxCumulativeDepositLimitPreconditions(uint256 newImxCumulativeDepositLimit)
        internal
        returns (UpdateImxCumulativeDepositLimitParams memory)
    {
        return UpdateImxCumulativeDepositLimitParams({
            newImxCumulativeDepositLimit: fl.clamp(
                newImxCumulativeDepositLimit, 0, MAX_ERC20_BALANCE * ChildERC20(rootIMXToken).decimals()
            )
        });
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          UTILS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice This function gets an array of indices from an entropy value
     * @param entropy The entropy to generate the indices from
     * @param length The length of the indices array
     * @param maxLength The maximum value of each of the indices
     */
    function getIndicesFromEntropy(uint256 entropy, uint256 length, uint256 maxLength)
        internal
        returns (uint256[] memory)
    {
        uint256[] memory indices = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 index = uint256(keccak256(abi.encode(entropy, i)));
            index = fl.clamp(index, 0, maxLength);
            indices[i] = index;
        }
        return indices;
    }
}
