// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./helper/handlers/HandlerChildERC20Bridge.sol";
import "./FuzzIntegrityBase.sol";

/**
 * @title FuzzChildERC20BridgeIntegrity
 * @author 0xScourgedev
 * @notice Checks for errors in the handlers for ChildERC20Bridge
 */
contract FuzzChildERC20BridgeIntegrity is HandlerChildERC20Bridge, FuzzIntegrityBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         INTEGRITY                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Checks the integrity of handler_onMessageReceiveChild
     */
    function fuzz_onMessageReceiveChild(
        bool isDeposit,
        uint8 rootTokenSelector,
        uint8 senderSelector,
        uint8 receiverSelector,
        uint256 amount
    ) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerChildERC20Bridge.handler_onMessageReceiveChild.selector,
            isDeposit,
            rootTokenSelector,
            senderSelector,
            receiverSelector,
            amount
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-01");
        }
    }

    /**
     * @notice Checks the integrity of handler_pauseChild
     */
    function fuzz_pauseChild() public {
        bytes memory callData = abi.encodeWithSelector(HandlerChildERC20Bridge.handler_pauseChild.selector);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-02");
        }
    }

    /**
     * @notice Checks the integrity of handler_unpauseChild
     */
    function fuzz_unpauseChild() public {
        bytes memory callData = abi.encodeWithSelector(HandlerChildERC20Bridge.handler_unpauseChild.selector);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-03");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdraw
     */
    function fuzz_withdraw(uint8 childTokenSelector, uint256 amount, uint256 value) public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerChildERC20Bridge.handler_withdraw.selector, childTokenSelector, amount, value);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-04");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdrawETH
     */
    function fuzz_withdrawETH(uint256 amount, uint256 value) public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerChildERC20Bridge.handler_withdrawETH.selector, amount, value);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-05");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdrawETHTo
     */
    function fuzz_withdrawETHTo(uint8 receiverSelector, uint256 amount, uint256 value) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerChildERC20Bridge.handler_withdrawETHTo.selector, receiverSelector, amount, value
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-06");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdrawIMX
     */
    function fuzz_withdrawIMX(uint256 amount, uint256 value) public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerChildERC20Bridge.handler_withdrawIMX.selector, amount, value);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-07");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdrawIMXTo
     */
    function fuzz_withdrawIMXTo(uint8 receiverSelector, uint256 amount, uint256 value) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerChildERC20Bridge.handler_withdrawIMXTo.selector, receiverSelector, amount, value
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-08");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdrawTo
     */
    function fuzz_withdrawTo(uint8 childTokenSelector, uint8 receiverSelector, uint256 amount, uint256 value) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerChildERC20Bridge.handler_withdrawTo.selector, childTokenSelector, receiverSelector, amount, value
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-09");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdrawWIMX
     */
    function fuzz_withdrawWIMX(uint256 amount, uint256 value) public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerChildERC20Bridge.handler_withdrawWIMX.selector, amount, value);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-10");
        }
    }

    /**
     * @notice Checks the integrity of handler_withdrawWIMXTo
     */
    function fuzz_withdrawWIMXTo(uint8 receiverSelector, uint256 amount, uint256 value) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerChildERC20Bridge.handler_withdrawWIMXTo.selector, receiverSelector, amount, value
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-11");
        }
    }
}
