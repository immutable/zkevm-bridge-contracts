// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

/**
 * @title PreconditionsChildERC20Bridge
 * @author 0xScourgedev
 * @notice Contains all preconditions for ChildERC20Bridge
 */
abstract contract PreconditionsChildERC20Bridge is PreconditionsBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct OnMessageReceiveChildParams {
        bytes data;
        address rootToken;
        uint256 amount;
        address sender;
        address receiver;
    }

    struct WithdrawParams {
        address childToken;
        uint256 amount;
        uint256 value;
    }

    struct WithdrawETHParams {
        uint256 amount;
        uint256 value;
    }

    struct WithdrawETHToParams {
        address receiver;
        uint256 amount;
        uint256 value;
    }

    struct WithdrawIMXParams {
        uint256 amount;
        uint256 value;
    }

    struct WithdrawIMXToParams {
        address receiver;
        uint256 amount;
        uint256 value;
    }

    struct WithdrawToParams {
        address childToken;
        address receiver;
        uint256 amount;
        uint256 value;
    }

    struct WithdrawWIMXParams {
        uint256 amount;
        uint256 value;
    }

    struct WithdrawWIMXToParams {
        address receiver;
        uint256 amount;
        uint256 value;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PRECONDITIONS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Preconditions for the onMessageReceive function for the child bridge
     * @custom:precondition Set the root token to a valid root token address
     * @custom:precondition If the root token is WETH, set the root token to NATIVE_ETH
     * @custom:precondition Set the sender and receiver to valid user addresses
     * @custom:precondition Have a chance for the selector to be an invalid signature
     * @custom:precondition The deposit amount is clamped between 0 and the maximum ERC20 balance
     * @custom:precondition All inputs are encoded into bytes
     */
    function onMessageReceiveChildPreconditions(
        bool isDeposit,
        uint8 rootTokenSelector,
        uint8 senderSelector,
        uint8 receiverSelector,
        uint256 amount
    ) internal returns (OnMessageReceiveChildParams memory) {
        address rootToken = rootTokens[rootTokenSelector % rootTokens.length];
        if (rootToken == wETH) {
            rootToken = NATIVE_ETH;
        }
        if (rootToken == rootIMXToken) {
            amount = fl.clamp(amount, 0, childERC20Bridge.balance + COVERAGE_GAP);
        } else {
            amount = fl.clamp(amount, 0, MAX_ERC20_BALANCE);
        }
        bytes32 selector = isDeposit ? DEPOSIT_SIG : NOTHING_SIG;
        address sender = USERS[senderSelector % USERS.length];
        address receiver = USERS[receiverSelector % USERS.length];
        bytes memory data = abi.encode(selector, rootToken, sender, receiver, amount);
        return OnMessageReceiveChildParams({
            data: data,
            rootToken: rootToken,
            amount: amount,
            sender: sender,
            receiver: receiver
        });
    }

    /**
     * @notice Preconditions for the pause function for the child bridge
     * @custom:precondition The child bridge is not already paused
     */
    function pauseChildPreconditions() internal {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused()) {
            revert ClampFail("Child bridge already paused");
        }
    }

    /**
     * @notice Preconditions for the unpause function for the child bridge
     * @custom:precondition The child bridge is currently paused
     */
    function unpauseChildPreconditions() internal {
        if (!ChildERC20Bridge(payable(childERC20Bridge)).paused()) {
            revert ClampFail("Child bridge already unpaused");
        }
    }

    /**
     * @notice Preconditions for the withdraw function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition Select a valid child token to withdraw
     * @custom:precondition The amount is clamped between 0 and the current actor's child token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function withdrawPreconditions(uint8 childTokenSelector, uint256 amount, uint256 value)
        internal
        returns (WithdrawParams memory)
    {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        address childToken = childTokens[childTokenSelector % childTokens.length];
        return WithdrawParams({
            childToken: childToken,
            amount: fl.clamp(amount, 0, ChildERC20(childToken).balanceOf(address(currentActor))),
            value: fl.clamp(value, 0, currentActor.balance)
        });
    }

    /**
     * @notice Preconditions for the withdrawETH function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition The amount is clamped between 0 and the current actor's child ETH token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function withdrawETHPreconditions(uint256 amount, uint256 value) internal returns (WithdrawETHParams memory) {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        return WithdrawETHParams({
            amount: fl.clamp(amount, 0, ChildERC20(childETHToken).balanceOf(address(currentActor))),
            value: fl.clamp(value, 0, currentActor.balance)
        });
    }

    /**
     * @notice Preconditions for the withdrawETHTo function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition The amount is clamped between 0 and the current actor's child ETH token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function withdrawETHToPreconditions(uint8 receiverSelector, uint256 amount, uint256 value)
        internal
        returns (WithdrawETHToParams memory)
    {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        value = fl.clamp(value, 0, currentActor.balance);
        amount = fl.clamp(amount, 0, ChildERC20(childETHToken).balanceOf(address(currentActor)));
        return WithdrawETHToParams({receiver: USERS[receiverSelector % USERS.length], amount: amount, value: value});
    }

    /**
     * @notice Preconditions for the withdrawIMX function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     * @custom:precondition The amount is clamped between 0 and the clamped transaction value plus a small gap for coverage purposes
     */
    function withdrawIMXPreconditions(uint256 amount, uint256 value) internal returns (WithdrawIMXParams memory) {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        value = fl.clamp(value, 0, currentActor.balance);
        amount = fl.clamp(amount, 0, value + COVERAGE_GAP);
        return WithdrawIMXParams({amount: amount, value: value});
    }

    /**
     * @notice Preconditions for the withdrawIMXTo function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     * @custom:precondition The amount is clamped between 0 and the clamped transaction value plus a small gap for coverage purposes
     */
    function withdrawIMXToPreconditions(uint8 receiverSelector, uint256 amount, uint256 value)
        internal
        returns (WithdrawIMXToParams memory)
    {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        value = fl.clamp(value, 0, currentActor.balance);
        amount = fl.clamp(amount, 0, value + COVERAGE_GAP);
        return WithdrawIMXToParams({receiver: USERS[receiverSelector % USERS.length], amount: amount, value: value});
    }

    /**
     * @notice Preconditions for the withdrawTo function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition select a valid child token to withdraw
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition The amount is clamped between 0 and the current actor's child token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function withdrawToPreconditions(uint8 childTokenSelector, uint8 receiverSelector, uint256 amount, uint256 value)
        internal
        returns (WithdrawToParams memory)
    {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        address childToken = childTokens[childTokenSelector % childTokens.length];
        return WithdrawToParams({
            childToken: childToken,
            receiver: USERS[receiverSelector % USERS.length],
            amount: fl.clamp(amount, 0, ChildERC20(childToken).balanceOf(address(currentActor))),
            value: fl.clamp(value, 0, currentActor.balance)
        });
    }

    /**
     * @notice Preconditions for the withdrawWIMX function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition The amount is clamped between 0 and the current actor's WIMX token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function withdrawWIMXPreconditions(uint256 amount, uint256 value) internal returns (WithdrawWIMXParams memory) {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        return WithdrawWIMXParams({
            amount: fl.clamp(amount, 0, ChildERC20(wIMX).balanceOf(address(currentActor))),
            value: fl.clamp(value, 0, currentActor.balance)
        });
    }

    /**
     * @notice Preconditions for the withdrawWIMXTo function for the child bridge
     * @custom:precondition Give a small chance for the transaction to go through when the child bridge is paused
     * @custom:precondition Set the receiver to a valid user address
     * @custom:precondition The amount is clamped between 0 and the current actor's WIMX token balance
     * @custom:precondition The value is clamped between 0 and the current actor's native balance
     */
    function withdrawWIMXToPreconditions(uint8 receiverSelector, uint256 amount, uint256 value)
        internal
        returns (WithdrawWIMXToParams memory)
    {
        if (ChildERC20Bridge(payable(childERC20Bridge)).paused() && block.number % EXECUTE_WHEN_PAUSED_ODDS != 0) {
            revert ClampFail("Child bridge already paused");
        }
        return WithdrawWIMXToParams({
            receiver: USERS[receiverSelector % USERS.length],
            amount: fl.clamp(amount, 0, ChildERC20(wIMX).balanceOf(address(currentActor))),
            value: fl.clamp(value, 0, currentActor.balance)
        });
    }
}
