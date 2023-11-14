// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

interface IRootERC20BridgeFlowRate {}

interface IRootERC20BridgeFlowRateEvents {
    /**
     * @notice Indicates rate control thresholds have been set for a certain token.
     * @param token The token thresholds applied to.
     * @param capacity The size of the bucket in tokens.
     * @param refillRate How quickly the bucket refills in tokens per second.
     * @param largeTransferThreshold Threshold over which a withdrawal is deemed to be large,
     *         and will be put in the withdrawal queue.
     */
    event RateControlThresholdSet(
        address indexed token, uint256 capacity, uint256 refillRate, uint256 largeTransferThreshold
    );

    /**
     * @notice Indicates a withdrawal was queued.
     * @param token Address of token that is being withdrawn.
     * @param withdrawer Child chain sender of tokens.
     * @param receiver Recipient of tokens.
     * @param amount The number of tokens.
     * @param delayWithdrawalLargeAmount is true if the reason for queuing was a large transfer.
     * @param delayWithdrawalUnknownToken is true if the reason for queuing was that the
     *         token had not been configured using the setRateControlThreshold function.
     * @param withdrawalQueueActivated is true if the withdrawal queue has been activated.
     */
    event QueuedWithdrawal(
        address indexed token,
        address indexed withdrawer,
        address indexed receiver,
        uint256 amount,
        bool delayWithdrawalLargeAmount,
        bool delayWithdrawalUnknownToken,
        bool withdrawalQueueActivated
    );
}

interface IRootERC20BridgeFlowRateErrors {
    // Error if the RootERC20Bridge initializer is called, and not the one for this contract.
    error WrongInitializer();
    // finaliseQueuedWithdrawalsAggregated was called with a zero length indices array.
    error ProvideAtLeastOneIndex();
    // The expected and actual token did not match for an aggregated withdrawal.
    error MixedTokens(address token, address actualToken);
}
