// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./helper/handlers/HandlerRootERC20BridgeFlowRate.sol";
import "./FuzzIntegrityBase.sol";

/**
 * @title FuzzRootERC20BridgeFlowRateIntegrity
 * @author 0xScourgedev
 * @notice Checks for errors in the handlers for RootERC20BridgeFlowRate
 */
contract FuzzRootERC20BridgeFlowRateIntegrity is HandlerRootERC20BridgeFlowRate, FuzzIntegrityBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         INTEGRITY                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Checks the integrity of handler_activateWithdrawalQueue
     */
    function fuzz_activateWithdrawalQueue() public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerRootERC20BridgeFlowRate.handler_activateWithdrawalQueue.selector);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-12");
        }
    }

    /**
     * @notice Checks the integrity of handler_deactivateWithdrawalQueue
     */
    function fuzz_deactivateWithdrawalQueue() public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerRootERC20BridgeFlowRate.handler_deactivateWithdrawalQueue.selector);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-13");
        }
    }

    /**
     * @notice Checks the integrity of handler_deposit
     */
    function fuzz_deposit(uint8 rootTokenSelector, uint256 amount, uint256 value) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_deposit.selector, rootTokenSelector, amount, value
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-14");
        }
    }

    /**
     * @notice Checks the integrity of handler_depositETH
     */
    function fuzz_depositETH(uint256 amount, uint256 value) public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerRootERC20BridgeFlowRate.handler_depositETH.selector, amount, value);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-15");
        }
    }

    /**
     * @notice Checks the integrity of handler_depositTo
     */
    function fuzz_depositTo(uint8 rootTokenSelector, uint8 receiverSelector, uint256 amount, uint256 value) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_depositTo.selector,
            rootTokenSelector,
            receiverSelector,
            amount,
            value
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-16");
        }
    }

    /**
     * @notice Checks the integrity of handler_depositToETH
     */
    function fuzz_depositToETH(uint8 receiver, uint256 amount, uint256 value) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_depositToETH.selector, receiver, amount, value
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-17");
        }
    }

    /**
     * @notice Checks the integrity of handler_finaliseQueuedWithdrawal
     */
    function fuzz_finaliseQueuedWithdrawal(uint8 receiverSelector, uint256 index) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_finaliseQueuedWithdrawal.selector, receiverSelector, index
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-18");
        }
    }

    /**
     * @notice Checks the integrity of handler_finaliseQueuedWithdrawalsAggregated
     */
    function fuzz_finaliseQueuedWithdrawalsAggregated(
        uint8 receiverSelector,
        uint8 tokenSelector,
        uint256 length,
        uint256 entropy
    ) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_finaliseQueuedWithdrawalsAggregated.selector,
            receiverSelector,
            tokenSelector,
            length,
            entropy
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-19");
        }
    }

    /**
     * @notice Checks the integrity of handler_onMessageReceiveRoot
     */
    function fuzz_onMessageReceiveRoot(
        bool isWithdraw,
        uint8 rootTokenSelector,
        uint8 withdrawerSelector,
        uint8 receiverSelector,
        uint256 amount
    ) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_onMessageReceiveRoot.selector,
            isWithdraw,
            rootTokenSelector,
            withdrawerSelector,
            receiverSelector,
            amount
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-20");
        }
    }

    /**
     * @notice Checks the integrity of handler_pauseRoot
     */
    function fuzz_pauseRoot() public {
        bytes memory callData = abi.encodeWithSelector(HandlerRootERC20BridgeFlowRate.handler_pauseRoot.selector);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-21");
        }
    }

    /**
     * @notice Checks the integrity of handler_setRateControlThreshold
     */
    function fuzz_setRateControlThreshold(
        uint8 tokenSelector,
        uint256 capacity,
        uint256 refillRate,
        uint256 largeTransferThreshold
    ) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_setRateControlThreshold.selector,
            tokenSelector,
            capacity,
            refillRate,
            largeTransferThreshold
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-22");
        }
    }

    /**
     * @notice Checks the integrity of handler_setWithdrawalDelay
     */
    function fuzz_setWithdrawalDelay(uint256 delay) public {
        bytes memory callData =
            abi.encodeWithSelector(HandlerRootERC20BridgeFlowRate.handler_setWithdrawalDelay.selector, delay);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-23");
        }
    }

    /**
     * @notice Checks the integrity of handler_unpauseRoot
     */
    function fuzz_unpauseRoot() public {
        bytes memory callData = abi.encodeWithSelector(HandlerRootERC20BridgeFlowRate.handler_unpauseRoot.selector);

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-24");
        }
    }

    /**
     * @notice Checks the integrity of handler_updateImxCumulativeDepositLimit
     */
    function fuzz_updateImxCumulativeDepositLimit(uint256 newImxCumulativeDepositLimit) public {
        bytes memory callData = abi.encodeWithSelector(
            HandlerRootERC20BridgeFlowRate.handler_updateImxCumulativeDepositLimit.selector,
            newImxCumulativeDepositLimit
        );

        (bool success, bytes4 errorSelector) = _testSelf(callData);
        if (!success) {
            bytes4[] memory allowedErrors = new bytes4[](1);
            allowedErrors[0] = ClampFail.selector;
            fl.errAllow(errorSelector, allowedErrors, "SELF-25");
        }
    }
}
