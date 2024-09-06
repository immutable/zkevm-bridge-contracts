// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_CLDREV
 * @author 0xScourgedev
 * @notice Contains all CLDREV invariants
 */
abstract contract Properties_CLDREV is PropertiesBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INVARIANTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @custom:invariant CLDREV-01: onMessageReceive for the child bridge never reverts unexpectedly
     */
    function invariant_CLDREV_01(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = IChildERC20BridgeErrors.InvalidData.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.InsufficientIMX.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_01);
    }

    /**
     * @custom:invariant CLDREV-02: pause for the child bridge never reverts
     */
    function invariant_CLDREV_02(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](0);
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_02);
    }

    /**
     * @custom:invariant CLDREV-03: unpause for the child bridge never reverts
     */
    function invariant_CLDREV_03(bytes memory returnData) internal {
        bytes4[] memory allowedErrors = new bytes4[](0);
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_03);
    }

    /**
     * @custom:invariant CLDREV-04: withdraw never reverts unexpectedly
     */
    function invariant_CLDREV_04(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_04);
    }

    /**
     * @custom:invariant CLDREV-05: withdrawETH never reverts unexpectedly
     */
    function invariant_CLDREV_05(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_05);
    }

    /**
     * @custom:invariant CLDREV-06: withdrawETHTo never reverts unexpectedly
     */
    function invariant_CLDREV_06(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_06);
    }

    /**
     * @custom:invariant CLDREV-07: withdrawIMX never reverts unexpectedly
     */
    function invariant_CLDREV_07(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](3);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        allowedErrors[2] = IChildERC20BridgeErrors.InsufficientValue.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_07);
    }

    /**
     * @custom:invariant CLDREV-08: withdrawIMXTo never reverts unexpectedly
     */
    function invariant_CLDREV_08(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](3);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        allowedErrors[2] = IChildERC20BridgeErrors.InsufficientValue.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_08);
    }

    /**
     * @custom:invariant CLDREV-09: withdrawTo never reverts unexpectedly
     */
    function invariant_CLDREV_09(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_09);
    }

    /**
     * @custom:invariant CLDREV-10: withdrawWIMX never reverts unexpectedly
     */
    function invariant_CLDREV_10(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_10);
    }

    /**
     * @custom:invariant CLDREV-11: withdrawWIMXTo never reverts unexpectedly
     */
    function invariant_CLDREV_11(bytes memory returnData) internal {
        if (states[1].childBridgePaused) {
            return;
        }
        bytes4[] memory allowedErrors = new bytes4[](2);
        allowedErrors[0] = IChildERC20BridgeErrors.ZeroAmount.selector;
        allowedErrors[1] = IChildERC20BridgeErrors.NoGas.selector;
        fl.errAllow(bytes4(returnData), allowedErrors, CLDREV_11);
    }
}
