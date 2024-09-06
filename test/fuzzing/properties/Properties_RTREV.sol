// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_RTREV
 * @author 0xScourgedev
 * @notice Contains all RTREV invariants
 */
abstract contract Properties_RTREV is PropertiesBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INVARIANTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @custom:invariant RTREV-01: activateWithdrawalQueue never reverts
     */
    function invariant_RTREV_01(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](0);
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_01);
    }

    /**
     * @custom:invariant RTREV-02: deactivateWithdrawalQueue never reverts
     */
    function invariant_RTREV_02(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](0);
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_02);
    }

    /**
     * @custom:invariant RTREV-03: deposit never reverts unexpectedly
     */
    function invariant_RTREV_03(bytes memory returnData) internal {
        if (states[1].rootBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](3);
        allowedErrors[0] = IRootERC20BridgeErrors.NoGas.selector;
        allowedErrors[1] = IRootERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[2] = IRootERC20BridgeErrors.ImxDepositLimitExceeded.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_03);
    }

    /**
     * @custom:invariant RTREV-04: depositETH never reverts unexpectedly
     */
    function invariant_RTREV_04(bytes memory returnData) internal {
        if (states[1].rootBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](3);
        allowedErrors[0] = IRootERC20BridgeErrors.NoGas.selector;
        allowedErrors[1] = IRootERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[2] = IRootERC20BridgeErrors.InsufficientValue.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_04);
    }

    /**
     * @custom:invariant RTREV-05: depositTo never reverts unexpectedly
     */
    function invariant_RTREV_05(bytes memory returnData) internal {
        if (states[1].rootBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](3);
        allowedErrors[0] = IRootERC20BridgeErrors.NoGas.selector;
        allowedErrors[1] = IRootERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[2] = IRootERC20BridgeErrors.ImxDepositLimitExceeded.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_05);
    }

    /**
     * @custom:invariant RTREV-06: depositToETH never reverts unexpectedly
     */
    function invariant_RTREV_06(bytes memory returnData) internal {
        if (states[1].rootBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](3);
        allowedErrors[0] = IRootERC20BridgeErrors.NoGas.selector;
        allowedErrors[1] = IRootERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[2] = IRootERC20BridgeErrors.InsufficientValue.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_06);
    }

    /**
     * @custom:invariant RTREV-07: finaliseQueuedWithdrawal never reverts unexpectedly
     */
    function invariant_RTREV_07(bytes memory returnData) internal {
        if (states[1].rootBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](3);
        allowedErrors[0] = IFlowRateWithdrawalQueueErrors.IndexOutsideWithdrawalQueue.selector;
        allowedErrors[1] = IFlowRateWithdrawalQueueErrors.WithdrawalAlreadyProcessed.selector;
        allowedErrors[2] = IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_07);
    }

    /**
     * @custom:invariant RTREV-08: finaliseQueuedWithdrawalAggregated never reverts unexpectedly
     */
    function invariant_RTREV_08(bytes memory returnData) internal {
        if (states[1].rootBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](5);
        allowedErrors[0] = IFlowRateWithdrawalQueueErrors.IndexOutsideWithdrawalQueue.selector;
        allowedErrors[1] = IFlowRateWithdrawalQueueErrors.WithdrawalAlreadyProcessed.selector;
        allowedErrors[2] = IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector;
        allowedErrors[3] = IRootERC20BridgeFlowRateErrors.ProvideAtLeastOneIndex.selector;
        allowedErrors[4] = IRootERC20BridgeFlowRateErrors.MixedTokens.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_08);
    }

    /**
     * @custom:invariant RTREV-09: onMessageReceive for the root bridge never reverts unexpectedly
     */
    function invariant_RTREV_09(bytes memory returnData) internal {
        if (states[1].rootBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](1);
        allowedErrors[0] = IRootERC20BridgeErrors.InvalidData.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_09);
    }

    /**
     * @custom:invariant RTREV-10: pause for the root bridge never reverts
     */
    function invariant_RTREV_10(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](0);
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_10);
    }

    /**
     * @custom:invariant RTREV-11: setRateControlThreshold never reverts
     */
    function invariant_RTREV_11(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = FlowRateDetection.InvalidCapacity.selector;
        allowedErrors[1] = FlowRateDetection.InvalidRefillRate.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_11);
    }

    /**
     * @custom:invariant RTREV-12: setWithdrawalDelay never reverts
     */
    function invariant_RTREV_12(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](0);
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_12);
    }

    /**
     * @custom:invariant RTREV-13: unpause for the root bridge never reverts
     */
    function invariant_RTREV_13(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](0);
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_13);
    }

    /**
     * @custom:invariant RTREV-14: updateImxCumulativeDepositLimit never reverts unexpectedly
     */
    function invariant_RTREV_14(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](1);
        allowedErrors[0] = IRootERC20BridgeErrors.ImxDepositLimitTooLow.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, RTREV_14);
    }
}
