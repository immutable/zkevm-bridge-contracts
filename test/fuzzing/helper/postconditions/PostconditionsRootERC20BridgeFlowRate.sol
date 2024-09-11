// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

/**
 * @title PostconditionsRootERC20BridgeFlowRate
 * @author 0xScourgedev
 * @notice Contains all postconditions for RootERC20BridgeFlowRate
 */
abstract contract PostconditionsRootERC20BridgeFlowRate is PostconditionsBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POSTCONDITIONS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Postconditions for the activateWithdrawalQueue function for the root bridge
     * @custom:invariant RTREV-01: activateWithdrawalQueue never reverts
     */
    function activateWithdrawalQueuePostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_01(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the deactivateWithdrawalQueue function for the root bridge
     * @custom:invariant RTREV-02: deactivateWithdrawalQueue never reverts
     */
    function deactivateWithdrawalQueuePostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_02(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the deposit function for the root bridge
     * @custom:invariant PAUSE-01: deposit always reverts when the root bridge is paused
     * @custom:invariant BAL-03: The native balance of the root adaptor increases by exactly the
     * gas fees paid by the users
     *
     * @custom:invariant BAL-05: The token balance, excluding WETH, of the root bridge increases
     * by exactly the amount of tokens deposited by the user
     *
     * @custom:invariant BAL-06: The native balance of the root bridge increases by exactly the amount
     * of WETH deposited by the user
     *
     * @custom:invariant SPLY-02: The total supply of root WETH must be decreased by the amount
     * of WETH deposited by the user
     *
     * @custom:invariant RTREV-03: deposit never reverts unexpectedly
     */
    function depositPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_01();
            invariant_BAL_03(value);
            invariant_BAL_05(tokenToUpdate, amount);
            invariant_BAL_06(tokenToUpdate, amount);
            invariant_SPLY_02(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_03(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the depositETH function for the root bridge
     * @custom:invariant PAUSE-02: depositETH always reverts when the root bridge is paused
     * @custom:invariant BAL-03: The native balance of the root adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant BAL-07: When depositing ETH, the native balance of the root bridge increases by
     * exactly the amount deposited by the user, minus the gas fees
     *
     * @custom:invariant RTREV-04: depositETH never reverts unexpectedly
     */
    function depositETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_02();
            invariant_BAL_03(value - amount);
            invariant_BAL_07(amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_04(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the depositTo function for the root bridge
     * @custom:invariant PAUSE-03: depositTo always reverts when the root bridge is paused
     * @custom:invariant BAL-03: The native balance of the root adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant BAL-05: The token balance, excluding WETH, of the root bridge increases by
     * exactly the amount of tokens deposited by the user
     *
     * @custom:invariant BAL-06: The native balance of the root bridge increases by exactly the amount
     * of WETH deposited by the user
     *
     * @custom:invariant SPLY-02: The total supply of root WETH must be decreased by the amount
     * of WETH deposited by the user
     *
     * @custom:invariant RTREV-05: depositTo never reverts unexpectedly
     */
    function depositToPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_03();
            invariant_BAL_03(value);
            invariant_BAL_05(tokenToUpdate, amount);
            invariant_BAL_06(tokenToUpdate, amount);
            invariant_SPLY_02(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_05(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the depositToETH function for the root bridge
     * @custom:invariant PAUSE-04: depositToETH always reverts when the root bridge is paused
     * @custom:invariant BAL-03: The native balance of the root adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant BAL-07: When depositing ETH, the native balance of the root bridge increases by
     * exactly the amount deposited by the user, minus the gas fees
     *
     * @custom:invariant RTREV-06: depositToETH never reverts unexpectedly
     */
    function depositToETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_04();
            invariant_BAL_03(value - amount);
            invariant_BAL_07(amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_06(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the finaliseQueuedWithdrawal function for the root bridge
     * @custom:invariant PAUSE-05: finaliseQueuedWithdrawal always reverts when the root bridge is paused
     * @custom:invariant FLRT-05: If finaliseQueuedWithdrawal is successfully called, then the queued
     * withdrawal initiated timestamp plus the withdrawal delay must be less than or equal to the current block timestamp
     *
     * @custom:invariant RTREV-07: finaliseQueuedWithdrawal never reverts unexpectedly
     */
    function finaliseQueuedWithdrawalPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        FlowRateWithdrawalQueue.PendingWithdrawal memory withdrawal
    ) internal {
        if (success) {
            _after(actorsToUpdate, withdrawal.token);
            invariant_PAUSE_05();
            invariant_FLRT_05(withdrawal);
            onSuccessInvariantsGeneral(returnData, withdrawal.token);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_07(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the finaliseQueuedWithdrawalsAggregated function for the root bridge
     * @custom:invariant PAUSE-06: finaliseQueuedWithdrawalsAggregated always reverts when the root bridge is paused
     * @custom:invariant RTREV-08: finaliseQueuedWithdrawalsAggregated never reverts unexpectedly
     */
    function finaliseQueuedWithdrawalsAggregatedPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_06();
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_08(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the onMessageReceive function for the root bridge
     * @custom:invariant PAUSE-07: onMessageReceive for the root bridge always reverts when the root bridge is paused
     * @custom:invariant FLRT-02: If the withdrawal amount is greater than the largeTransferThreshold,
     * the withdrawal must be added to the user's withdrawal queue
     *
     * @custom:invariant FLRT-03: If the bucket capacity for a token is 0, then any withdrawal of
     * that token must be added to the user's withdrawal queue
     *
     * @custom:invariant FLRT-04: If withdrawalQueueActivated is true, then any withdrawal of
     * any token must be added to the user's withdrawal queue
     *
     * @custom:invariant FLRT-06: After a successful withdrawal of a non-zero amount on the root
     * bridge, if the bucket capacity is not zero, then the token bucket depth is never equal to
     * the bucket capacity
     *
     * @custom:invariant FLRT-07: After a successful withdraw on the root bridge, if the
     * withdrawn amount is less than the minimum of the refill rate multiplied by the time
     * elapsed since last withdrawal and the bucket capacity minus the prior real bucket depth,
     * then the bucket depth strictly increases
     *
     * @custom:invariant FLRT-08: After a successful withdraw on the root bridge, the bucket depth
     * is always less than or equal to the bucket capacity
     *
     * @custom:invariant FLRT-09: When the withdrawalQueue is not activated, after a successful
     * withdrawal of an amount less than the largeTransferThreshold on the root bridge and a withdrawal
     * was added to the user's withdrawal queue, the bucket depth is always 0
     *
     * @custom:invariant FLRT-10: When the withdrawalQueue is not activated, after a successful
     * withdrawal of an amount less than the largeTransferThreshold on the root bridge, if the
     * withdrawn amount is greater or equal to minimum of the refill rate multiplied by the time
     * elapsed since last withdrawal plus the prior real bucket depth and the bucket capacity,
     * then the withdrawal must be added to the user's withdrawal queue
     *
     * @custom:invariant FLRT-11: If the depth of the token bucket is non-zero before a successful
     * withdrawal on the root bridge and the depth of the token bucket is zero after the withdrawal,
     * then the withdrawal queue must be activated
     *
     * @custom:invariant FLRT-12: After each successful withdrawal on the root bridge for a token with
     * a non-zero capacity, the bucket refillTime is always updated to the current block timestamp
     *
     * @custom:invariant RTREV-09: onMessageReceive for the root bridge never reverts unexpectedly
     */
    function onMessageReceiveRootPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        address recipient
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_07();
            invariant_FLRT_02(tokenToUpdate, recipient, amount);
            invariant_FLRT_03(tokenToUpdate, recipient);
            invariant_FLRT_04(recipient);
            invariant_FLRT_06(tokenToUpdate, amount);
            invariant_FLRT_07(tokenToUpdate, amount);
            invariant_FLRT_08(tokenToUpdate);
            invariant_FLRT_09(tokenToUpdate, recipient, amount);
            invariant_FLRT_10(tokenToUpdate, recipient, amount);
            invariant_FLRT_11(tokenToUpdate);
            invariant_FLRT_12(tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_09(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the pause function for the root bridge
     * @custom:invariant RTREV-10: pause for the root bridge never reverts
     */
    function pauseRootPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_10(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the setRateControlThreshold function for the root bridge
     * @custom:invariant RTREV-11: setRateControlThreshold never reverts
     */
    function setRateControlThresholdPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_11(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the setWithdrawalDelay function for the root bridge
     * @custom:invariant RTREV-12: setWithdrawalDelay never reverts
     */
    function setWithdrawalDelayPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_12(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the unpause function for the root bridge
     * @custom:invariant RTREV-13: unpause for the root bridge never reverts
     */
    function unpauseRootPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_13(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice Postconditions for the updateImxCumulativeDepositLimit function for the root bridge
     * @custom:invariant RTREV-14: updateImxCumulativeDepositLimit never reverts unexpectedly
     */
    function updateImxCumulativeDepositLimitPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsRootERC20BridgeFlowRate(returnData);
        } else {
            invariant_RTREV_14(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsRootERC20BridgeFlowRate(returnData);
        }
    }

    /**
     * @notice invariants to run after each successful transaction for the root bridge
     * @custom:invariant FLRT-01: If imxCumulativeDepositLimit is not 0, the rootIMX token balance of
     * the root bridge should always be less than or equal to imxCumulativeDepositLimit
     *
     * @custom:invariant BAL-01: The WETH balance of the root bridge should always be 0
     */
    function onSuccessInvariantsRootERC20BridgeFlowRate(bytes memory returnData) internal {
        invariant_FLRT_01();
        invariant_BAL_01();
    }

    /**
     * @notice invariants to run after each failed transaction for the root bridge
     */
    function onFailInvariantsRootERC20BridgeFlowRate(bytes memory returnData) internal {}
}
