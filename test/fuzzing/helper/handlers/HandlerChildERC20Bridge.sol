// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../preconditions/PreconditionsChildERC20Bridge.sol";
import "../postconditions/PostconditionsChildERC20Bridge.sol";

/**
 * @title HandlerChildERC20Bridge
 * @author 0xScourgedev
 * @notice Fuzz handlers for ChildERC20Bridge
 */
contract HandlerChildERC20Bridge is PreconditionsChildERC20Bridge, PostconditionsChildERC20Bridge {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HANDLERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice This handler calls the onMessageReceive function for the child bridge
     * @param isDeposit If this is true, then the signature is for a deposit, otherwise it is for a invalid signature
     * @param rootTokenSelector The selector for the root token to be deposited
     * @param senderSelector The selector for the sender
     * @param receiverSelector The selector for the receiver of the deposit
     * @param amount The amount of tokens to be deposited
     */
    function handler_onMessageReceiveChild(
        bool isDeposit,
        uint8 rootTokenSelector,
        uint8 senderSelector,
        uint8 receiverSelector,
        uint256 amount
    ) public setCurrentActor {
        OnMessageReceiveChildParams memory params =
            onMessageReceiveChildPreconditions(isDeposit, rootTokenSelector, senderSelector, receiverSelector, amount);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = params.receiver;

        address childToken = ChildERC20Bridge(payable(childERC20Bridge)).rootTokenToChildToken(params.rootToken);

        _before(actorsToUpdate, childToken);

        (bool success, bytes memory returnData) = _onMessageReceiveChildCall(params.data);

        onMessageReceiveChildPostconditions(success, returnData, actorsToUpdate, childToken, params.amount);
    }

    /**
     * @notice This handler calls the pause function for the child bridge
     */
    function handler_pauseChild() public setCurrentActor {
        pauseChildPreconditions();

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) = _pauseChildCall();

        pauseChildPostconditions(success, returnData, actorsToUpdate, address(0));
    }

    /**
     * @notice This handler calls the unpause function for the child bridge
     */
    function handler_unpauseChild() public setCurrentActor {
        unpauseChildPreconditions();

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) = _unpauseChildCall();

        unpauseChildPostconditions(success, returnData, actorsToUpdate, address(0));
    }

    /**
     * @notice This handler calls the withdraw function for the child bridge
     * @param childTokenSelector The selector for the child token to be withdrawn
     * @param amount The amount of tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdraw(uint8 childTokenSelector, uint256 amount, uint256 value) public setCurrentActor {
        WithdrawParams memory params = withdrawPreconditions(childTokenSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.childToken);

        (bool success, bytes memory returnData) = _withdrawCall(params.childToken, params.amount, params.value);

        withdrawPostconditions(success, returnData, actorsToUpdate, params.childToken, params.amount, params.value);
    }

    /**
     * @notice This handler calls the withdrawETH function for the child bridge
     * @param amount The amount of child ETH tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdrawETH(uint256 amount, uint256 value) public setCurrentActor {
        WithdrawETHParams memory params = withdrawETHPreconditions(amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, childETHToken);

        (bool success, bytes memory returnData) = _withdrawETHCall(params.amount, params.value);

        withdrawETHPostconditions(success, returnData, actorsToUpdate, childETHToken, params.amount, params.value);
    }

    /**
     * @notice This handler calls the withdrawETHTo function for the child bridge
     * @param receiverSelector The selector for the receiver of the withdrawal
     * @param amount The amount of child ETH tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdrawETHTo(uint8 receiverSelector, uint256 amount, uint256 value) public setCurrentActor {
        WithdrawETHToParams memory params = withdrawETHToPreconditions(receiverSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, childETHToken);

        (bool success, bytes memory returnData) = _withdrawETHToCall(params.receiver, params.amount, params.value);

        withdrawETHToPostconditions(success, returnData, actorsToUpdate, childETHToken, params.amount, params.value);
    }

    /**
     * @notice This handler calls the withdrawIMX function for the child bridge
     * @param amount The amount of native tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdrawIMX(uint256 amount, uint256 value) public setCurrentActor {
        WithdrawIMXParams memory params = withdrawIMXPreconditions(amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, NATIVE_ETH);

        (bool success, bytes memory returnData) = _withdrawIMXCall(params.amount, params.value);

        withdrawIMXPostconditions(success, returnData, actorsToUpdate, NATIVE_ETH, params.amount, params.value);
    }

    /**
     * @notice This handler calls the withdrawIMXTo function for the child bridge
     * @param receiverSelector The selector for the receiver of the withdrawal
     * @param amount The amount of native tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdrawIMXTo(uint8 receiverSelector, uint256 amount, uint256 value) public setCurrentActor {
        WithdrawIMXToParams memory params = withdrawIMXToPreconditions(receiverSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, NATIVE_ETH);

        (bool success, bytes memory returnData) = _withdrawIMXToCall(params.receiver, params.amount, params.value);

        withdrawIMXToPostconditions(success, returnData, actorsToUpdate, NATIVE_ETH, params.amount, params.value);
    }

    /**
     * @notice This handler calls the withdrawTo function for the child bridge
     * @param childTokenSelector The selector for the child token to be withdrawn
     * @param receiverSelector The selector for the receiver of the withdrawal
     * @param amount The amount of tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdrawTo(uint8 childTokenSelector, uint8 receiverSelector, uint256 amount, uint256 value)
        public
        setCurrentActor
    {
        WithdrawToParams memory params = withdrawToPreconditions(childTokenSelector, receiverSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.childToken);

        (bool success, bytes memory returnData) =
            _withdrawToCall(params.childToken, params.receiver, params.amount, params.value);

        withdrawToPostconditions(success, returnData, actorsToUpdate, params.childToken, params.amount, params.value);
    }

    /**
     * @notice This handler calls the withdrawWIMX function for the child bridge
     * @param amount The amount of wIMX tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdrawWIMX(uint256 amount, uint256 value) public setCurrentActor {
        WithdrawWIMXParams memory params = withdrawWIMXPreconditions(amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, wIMX);

        (bool success, bytes memory returnData) = _withdrawWIMXCall(params.amount, params.value);

        withdrawWIMXPostconditions(success, returnData, actorsToUpdate, wIMX, params.amount, params.value);
    }

    /**
     * @notice This handler calls the withdrawWIMXTo function for the child bridge
     * @param receiverSelector The selector for the receiver of the withdrawal
     * @param amount The amount of wIMX tokens to be withdrawn
     * @param value The native token value of the transaction
     */
    function handler_withdrawWIMXTo(uint8 receiverSelector, uint256 amount, uint256 value) public setCurrentActor {
        WithdrawWIMXToParams memory params = withdrawWIMXToPreconditions(receiverSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, wIMX);

        (bool success, bytes memory returnData) = _withdrawWIMXToCall(params.receiver, params.amount, params.value);

        withdrawWIMXToPostconditions(success, returnData, actorsToUpdate, wIMX, params.amount, params.value);
    }
}
