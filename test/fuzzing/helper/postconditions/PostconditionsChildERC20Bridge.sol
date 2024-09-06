// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PostconditionsBase.sol";

/**
 * @title PostconditionsChildERC20Bridge
 * @author 0xScourgedev
 * @notice Contains all postconditions for ChildERC20Bridge
 */
abstract contract PostconditionsChildERC20Bridge is PostconditionsBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POSTCONDITIONS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Postconditions for the onMessageReceive function for the child bridge
     * @custom:invariant PAUSE-16: onMessageReceive for the child bridge always reverts when the child bridge is paused
     * @custom:invariant SPLY-03: The total supply of child ERC20s must be increased by exactly
     * the amount of tokens deposited by the user
     *
     * @custom:invariant BAL-09: The native balance of the child bridge decreases by exactly the
     * amount of root ERC20 IMX deposited by the user
     */
    function onMessageReceiveChildPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_16();
            invariant_SPLY_03(tokenToUpdate, amount);
            invariant_BAL_09(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_01(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the pause function for the child bridge
     * @custom:invariant CLDREV-02: pause for the child bridge never reverts
     */
    function pauseChildPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_02(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the unpause function for the child bridge
     * @custom:invariant CLDREV-03: unpause for the child bridge never reverts
     */
    function unpauseChildPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_03(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdraw function for the child bridge
     * @custom:invariant PAUSE-08: withdraw always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant SPLY-04: The total supply of child ERC20s must be decreased by exactly the
     * amount of tokens withdrawn by the user
     *
     * @custom:invariant CLDREV-04: withdraw never reverts unexpectedly
     */
    function withdrawPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_08();
            invariant_BAL_04(value);
            invariant_SPLY_04(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_04(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdrawETH function for the child bridge
     * @custom:invariant PAUSE-09: withdrawETH always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant SPLY-04: The total supply of child ERC20s must be decreased by exactly the
     * amount of tokens withdrawn by the user
     * @custom:invariant CLDREV-05: withdrawETH never reverts unexpectedly
     */
    function withdrawETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_09();
            invariant_BAL_04(value);
            invariant_SPLY_04(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_05(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdrawETHTo function for the child bridge
     * @custom:invariant PAUSE-10: withdrawETHTo always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant SPLY-04: The total supply of child ERC20s must be decreased by exactly the
     * amount of tokens withdrawn by the user
     * @custom:invariant CLDREV-06: withdrawETHTo never reverts unexpectedly
     */
    function withdrawETHToPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_10();
            invariant_BAL_04(value);
            invariant_SPLY_04(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_06(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdrawIMX function for the child bridge
     * @custom:invariant PAUSE-11: withdrawIMX always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant BAL-08: When withdrawing IMX, the native balance of the child bridge increases
     * by exactly the amount withdrawn by the user, minus the gas fees
     *
     * @custom:invariant CLDREV-07: withdrawIMX never reverts unexpectedly
     */
    function withdrawIMXPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_11();
            invariant_BAL_04(value - amount);
            invariant_BAL_08(amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_07(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdrawIMXTo function for the child bridge
     * @custom:invariant PAUSE-12: withdrawIMXTo always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant CLDREV-08: withdrawIMXTo never reverts unexpectedly
     */
    function withdrawIMXToPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_12();
            invariant_BAL_04(value - amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_08(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdrawTo function for the child bridge
     * @custom:invariant PAUSE-13: withdrawTo always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant SPLY-04: The total supply of child ERC20s must be decreased by exactly the
     * amount of tokens withdrawn by the user
     *
     * @custom:invariant CLDREV-09: withdrawTo never reverts unexpectedly
     */
    function withdrawToPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_13();
            invariant_BAL_04(value);
            invariant_SPLY_04(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_09(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdrawWIMX function for the child bridge
     * @custom:invariant PAUSE-14: withdrawWIMX always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant SPLY-04: The total supply of child ERC20s must be decreased by exactly the
     * amount of tokens withdrawn by the user
     *
     * @custom:invariant CLDREV-10: withdrawWIMX never reverts unexpectedly
     */
    function withdrawWIMXPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_14();
            invariant_BAL_04(value);
            invariant_SPLY_04(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_10(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice Postconditions for the withdrawWIMXTo function for the child bridge
     * @custom:invariant PAUSE-15: withdrawWIMXTo always reverts when the child bridge is paused
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly the gas fees paid by the users
     * @custom:invariant SPLY-04: The total supply of child ERC20s must be decreased by exactly the
     * amount of tokens withdrawn by the user
     *
     * @custom:invariant CLDREV-11: withdrawWIMXTo never reverts unexpectedly
     */
    function withdrawWIMXToPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address tokenToUpdate,
        uint256 amount,
        uint256 value
    ) internal {
        if (success) {
            _after(actorsToUpdate, tokenToUpdate);
            invariant_PAUSE_15();
            invariant_BAL_04(value);
            invariant_SPLY_04(tokenToUpdate, amount);
            onSuccessInvariantsGeneral(returnData, tokenToUpdate);
            onSuccessInvariantsChildERC20Bridge(returnData);
        } else {
            invariant_CLDREV_11(returnData);
            onFailInvariantsGeneral(returnData);
            onFailInvariantsChildERC20Bridge(returnData);
        }
    }

    /**
     * @notice invariants to run after each successful transaction for the child bridge
     * @custom:invariant BAL-02: The WIMX balance of the child bridge should always be 0
     */
    function onSuccessInvariantsChildERC20Bridge(bytes memory returnData) internal {
        invariant_BAL_02();
    }

    /**
     * @notice invariants to run after each failed transaction for the child bridge
     */
    function onFailInvariantsChildERC20Bridge(bytes memory returnData) internal {}
}
