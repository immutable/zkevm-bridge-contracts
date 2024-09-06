// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title PropertiesDescriptions
 * @author 0xScourgedev
 * @notice Descriptions strings for the invariants
 */
abstract contract PropertiesDescriptions {
    string internal constant FLRT_01 =
        "FLRT-01: If imxCumulativeDepositLimit is not 0, the rootIMX token balance of the root bridge should always be less than or equal to imxCumulativeDepositLimit";
    string internal constant FLRT_02 =
        "FLRT-02: If the withdrawal amount is greater than the largeTransferThreshold, the withdrawal must be added to the user's withdrawal queue";
    string internal constant FLRT_03 =
        "FLRT-03: If the bucket capacity for a token is 0, then any withdrawal of that token must be added to the user's withdrawal queue";
    string internal constant FLRT_04 =
        "FLRT-04: If withdrawalQueueActivated is true, then any withdrawal of any token must be added to the user's withdrawal queue";
    string internal constant FLRT_05 =
        "FLRT-05: If finaliseQueuedWithdrawal is successfully called, then the queued withdrawal initiated timestamp plus the withdrawal delay must be less than or equal to the current block timestamp";
    string internal constant FLRT_06 =
        "FLRT-06: After a successful withdrawal of a non-zero amount on the root bridge, if the bucket capacity is not zero, then the token bucket depth is never equal to the bucket capacity";
    string internal constant FLRT_07 =
        "FLRT-07: After a successful withdraw on the root bridge, if the withdrawn amount is less than the minimum of the refill rate multiplied by the time elapsed since last withdrawal and the bucket capacity minus the prior real bucket depth, then the bucket depth strictly increases";
    string internal constant FLRT_08 =
        "FLRT-08: After a successful withdraw on the root bridge, the bucket depth is always less than or equal to the bucket capacity";
    string internal constant FLRT_09 =
        "FLRT-09: When the withdrawalQueue is not activated, after a successful withdrawal of an amount less than the largeTransferThreshold on the root bridge and a withdrawal was added to the user's withdrawal queue, the bucket depth is always 0";
    string internal constant FLRT_10 =
        "FLRT-10: When the withdrawalQueue is not activated, after a successful withdrawal of an amount less than the largeTransferThreshold on the root bridge, if the withdrawn amount is greater or equal to minimum of the refill rate multiplied by the time elapsed since last withdrawal plus the prior real bucket depth and the bucket capacity, then the withdrawal must be added to the user's withdrawal queue";
    string internal constant FLRT_11 =
        "FLRT-11: If the depth of the token bucket is non-zero before a successful withdrawal on the root bridge and the depth of the token bucket is zero after the withdrawal, then the withdrawal queue must be activated";
    string internal constant FLRT_12 =
        "FLRT-12: After each successful withdrawal on the root bridge for a token with a non-zero capacity, the bucket refillTime is always updated to the current block timestamp";

    string internal constant SPLY_01 =
        "SPLY-01: The sum of the token balances of each user and the bridges should be exactly equal to the token total supply";
    string internal constant SPLY_02 =
        "SPLY-02: The total supply of root WETH must be decreased by the amount of WETH deposited by the user";
    string internal constant SPLY_03 =
        "SPLY-03: The total supply of child ERC20s must be increased by exactly the amount of tokens deposited by the user";
    string internal constant SPLY_04 =
        "SPLY-04: The total supply of child ERC20s must be decreased by exactly the amount of tokens withdrawn by the user";

    string internal constant BAL_01 = "BAL-01: The WETH balance of the root bridge should always be 0";
    string internal constant BAL_02 = "BAL-02: The WIMX balance of the child bridge should always be 0";
    string internal constant BAL_03 =
        "BAL-03: The native balance of the root adaptor increases by exactly the gas fees paid by the users";
    string internal constant BAL_04 =
        "BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users";
    string internal constant BAL_05 =
        "BAL-05: The token balance, excluding WETH, of the root bridge increases by exactly the amount of tokens deposited by the user";
    string internal constant BAL_06 =
        "BAL-06: The native balance of the root bridge increases by exactly the amount of WETH deposited by the user";
    string internal constant BAL_07 =
        "BAL-07: When depositing ETH, the native balance of the root bridge increases by exactly the amount deposited by the user, minus the gas fees";
    string internal constant BAL_08 =
        "BAL-08: When withdrawing IMX, the native balance of the child bridge increases by exactly the amount withdrawn by the user, minus the gas fees";
    string internal constant BAL_09 =
        "BAL-09: The native balance of the child bridge decreases by exactly the amount of root ERC20 IMX deposited by the user";

    string internal constant RTREV_01 = "RTREV-01: activateWithdrawalQueue never reverts";
    string internal constant RTREV_02 = "RTREV-02: deactivateWithdrawalQueue never reverts";
    string internal constant RTREV_03 = "RTREV-03: deposit never reverts unexpectedly";
    string internal constant RTREV_04 = "RTREV-04: depositETH never reverts unexpectedly";
    string internal constant RTREV_05 = "RTREV-05: depositTo never reverts unexpectedly";
    string internal constant RTREV_06 = "RTREV-06: depositToETH never reverts unexpectedly";
    string internal constant RTREV_07 = "RTREV-07: finaliseQueuedWithdrawal never reverts unexpectedly";
    string internal constant RTREV_08 = "RTREV-08: finaliseQueuedWithdrawalAggregated never reverts unexpectedly";
    string internal constant RTREV_09 = "RTREV-09: onMessageReceive for the root bridge never reverts unexpectedly";
    string internal constant RTREV_10 = "RTREV-10: pause for the root bridge never reverts";
    string internal constant RTREV_11 = "RTREV-11: setRateControlThreshold never reverts";
    string internal constant RTREV_12 = "RTREV-12: setWithdrawalDelay never reverts";
    string internal constant RTREV_13 = "RTREV-13: unpause for the root bridge never reverts";
    string internal constant RTREV_14 = "RTREV-14: updateImxCumulativeDepositLimit never reverts unexpectedly";

    string internal constant CLDREV_01 = "CLDREV-01: onMessageReceive for the child bridge never reverts unexpectedly";
    string internal constant CLDREV_02 = "CLDREV-02: pause for the child bridge never reverts";
    string internal constant CLDREV_03 = "CLDREV-03: unpause for the child bridge never reverts";
    string internal constant CLDREV_04 = "CLDREV-04: withdraw never reverts unexpectedly";
    string internal constant CLDREV_05 = "CLDREV-05: withdrawETH never reverts unexpectedly";
    string internal constant CLDREV_06 = "CLDREV-06: withdrawETHTo never reverts unexpectedly";
    string internal constant CLDREV_07 = "CLDREV-07: withdrawIMX never reverts unexpectedly";
    string internal constant CLDREV_08 = "CLDREV-08: withdrawIMXTo never reverts unexpectedly";
    string internal constant CLDREV_09 = "CLDREV-09: withdrawTo never reverts unexpectedly";
    string internal constant CLDREV_10 = "CLDREV-10: withdrawWIMX never reverts unexpectedly";
    string internal constant CLDREV_11 = "CLDREV-11: withdrawWIMXTo never reverts unexpectedly";

    string internal constant PAUSE_01 = "PAUSE-01: deposit always reverts when the root bridge is paused";
    string internal constant PAUSE_02 = "PAUSE-02: depositETH always reverts when the root bridge is paused";
    string internal constant PAUSE_03 = "PAUSE-03: depositTo always reverts when the root bridge is paused";
    string internal constant PAUSE_04 = "PAUSE-04: depositToETH always reverts when the root bridge is paused";
    string internal constant PAUSE_05 =
        "PAUSE-05: finaliseQueuedWithdrawal always reverts when the root bridge is paused";
    string internal constant PAUSE_06 =
        "PAUSE-06: finaliseQueuedWithdrawalAggregated always reverts when the root bridge is paused";
    string internal constant PAUSE_07 =
        "PAUSE-07: onMessageReceive for the root bridge always reverts when the root bridge is paused";
    string internal constant PAUSE_08 = "PAUSE-08: withdraw always reverts when the child bridge is paused";
    string internal constant PAUSE_09 = "PAUSE-09: withdrawETH always reverts when the child bridge is paused";
    string internal constant PAUSE_10 = "PAUSE-10: withdrawETHTo always reverts when the child bridge is paused";
    string internal constant PAUSE_11 = "PAUSE-11: withdrawIMX always reverts when the child bridge is paused";
    string internal constant PAUSE_12 = "PAUSE-12: withdrawIMXTo always reverts when the child bridge is paused";
    string internal constant PAUSE_13 = "PAUSE-13: withdrawTo always reverts when the child bridge is paused";
    string internal constant PAUSE_14 = "PAUSE-14: withdrawWIMX always reverts when the child bridge is paused";
    string internal constant PAUSE_15 = "PAUSE-15: withdrawWIMXTo always reverts when the child bridge is paused";
    string internal constant PAUSE_16 =
        "PAUSE-16: onMessageReceive for the child bridge always reverts when the child bridge is paused";
}
