// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@perimetersec/fuzzlib/src/FuzzBase.sol";

import "../helper/FuzzStorageVariables.sol";

/**
 * @title FunctionCalls
 * @author 0xScourgedev
 * @notice Contains the function calls for all of the handlers
 */
abstract contract FunctionCalls is FuzzBase, FuzzStorageVariables {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           EVENTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Functions from ChildERC20Bridge

    event OnMessageReceiveChildCall(bytes data);
    event PauseChildCall();
    event UnpauseChildCall();
    event WithdrawCall(address childToken, uint256 amount);
    event WithdrawETHCall(uint256 amount);
    event WithdrawETHToCall(address receiver, uint256 amount);
    event WithdrawIMXCall(uint256 amount);
    event WithdrawIMXToCall(address receiver, uint256 amount);
    event WithdrawToCall(address childToken, address receiver, uint256 amount);
    event WithdrawWIMXCall(uint256 amount);
    event WithdrawWIMXToCall(address receiver, uint256 amount);

    // Functions from RootERC20BridgeFlowRate

    event ActivateWithdrawalQueueCall();
    event DeactivateWithdrawalQueueCall();
    event DepositCall(address rootToken, uint256 amount);
    event DepositETHCall(uint256 amount);
    event DepositToCall(address rootToken, address receiver, uint256 amount);
    event DepositToETHCall(address receiver, uint256 amount);
    event FinaliseQueuedWithdrawalCall(address receiver, uint256 index);
    event FinaliseQueuedWithdrawalsAggregatedCall(address receiver, address token, uint256[] indices);
    event OnMessageReceiveRootCall(bytes data);
    event PauseRootCall();
    event SetRateControlThresholdCall(
        address token, uint256 capacity, uint256 refillRate, uint256 largeTransferThreshold
    );
    event SetWithdrawalDelayCall(uint256 delay);
    event UnpauseRootCall();
    event UpdateImxCumulativeDepositLimitCall(uint256 newImxCumulativeDepositLimit);
    event UpdateRootBridgeAdaptorCall(address newRootBridgeAdaptor);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       FUNCTIONS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Functions from ChildERC20Bridge

    function _onMessageReceiveChildCall(bytes memory data) internal returns (bool success, bytes memory returnData) {
        emit OnMessageReceiveChildCall(data);

        vm.prank(currentActor);

        (success, returnData) =
            mockAdaptorChild.call{gas: 1000000}(abi.encodeWithSelector(MockAdaptor.onMessageReceive.selector, data));
    }

    function _pauseChildCall() internal returns (bool success, bytes memory returnData) {
        emit PauseChildCall();

        (success, returnData) = childERC20Bridge.call{gas: 1000000}(abi.encodeWithSelector(BridgeRoles.pause.selector));
    }

    function _unpauseChildCall() internal returns (bool success, bytes memory returnData) {
        emit UnpauseChildCall();

        (success, returnData) =
            childERC20Bridge.call{gas: 1000000}(abi.encodeWithSelector(BridgeRoles.unpause.selector));
    }

    function _withdrawCall(address childToken, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit WithdrawCall(childToken, amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdraw.selector, childToken, amount)
        );
    }

    function _withdrawETHCall(uint256 amount, uint256 value) internal returns (bool success, bytes memory returnData) {
        emit WithdrawETHCall(amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdrawETH.selector, amount)
        );
    }

    function _withdrawETHToCall(address receiver, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit WithdrawETHToCall(receiver, amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdrawETHTo.selector, receiver, amount)
        );
    }

    function _withdrawIMXCall(uint256 amount, uint256 value) internal returns (bool success, bytes memory returnData) {
        emit WithdrawIMXCall(amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdrawIMX.selector, amount)
        );
    }

    function _withdrawIMXToCall(address receiver, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit WithdrawIMXToCall(receiver, amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdrawIMXTo.selector, receiver, amount)
        );
    }

    function _withdrawToCall(address childToken, address receiver, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit WithdrawToCall(childToken, receiver, amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdrawTo.selector, childToken, receiver, amount)
        );
    }

    function _withdrawWIMXCall(uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit WithdrawWIMXCall(amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdrawWIMX.selector, amount)
        );
    }

    function _withdrawWIMXToCall(address receiver, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit WithdrawWIMXToCall(receiver, amount);

        vm.prank(currentActor);

        (success, returnData) = childERC20Bridge.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(ChildERC20Bridge.withdrawWIMXTo.selector, receiver, amount)
        );
    }

    // Functions from RootERC20BridgeFlowRate

    function _activateWithdrawalQueueCall() internal returns (bool success, bytes memory returnData) {
        emit ActivateWithdrawalQueueCall();

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000}(
            abi.encodeWithSelector(RootERC20BridgeFlowRate.activateWithdrawalQueue.selector)
        );
    }

    function _deactivateWithdrawalQueueCall() internal returns (bool success, bytes memory returnData) {
        emit DeactivateWithdrawalQueueCall();

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000}(
            abi.encodeWithSelector(RootERC20BridgeFlowRate.deactivateWithdrawalQueue.selector)
        );
    }

    function _depositCall(address rootToken, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit DepositCall(rootToken, amount);

        vm.prank(currentActor);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(RootERC20Bridge.deposit.selector, rootToken, amount)
        );
    }

    function _depositETHCall(uint256 amount, uint256 value) internal returns (bool success, bytes memory returnData) {
        emit DepositETHCall(amount);

        vm.prank(currentActor);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(RootERC20Bridge.depositETH.selector, amount)
        );
    }

    function _depositToCall(address rootToken, address receiver, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit DepositToCall(rootToken, receiver, amount);

        vm.prank(currentActor);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(RootERC20Bridge.depositTo.selector, rootToken, receiver, amount)
        );
    }

    function _depositToETHCall(address receiver, uint256 amount, uint256 value)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit DepositToETHCall(receiver, amount);

        vm.prank(currentActor);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000, value: value}(
            abi.encodeWithSelector(RootERC20Bridge.depositToETH.selector, receiver, amount)
        );
    }

    function _finaliseQueuedWithdrawalCall(address receiver, uint256 index)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit FinaliseQueuedWithdrawalCall(receiver, index);

        vm.prank(currentActor);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000}(
            abi.encodeWithSelector(RootERC20BridgeFlowRate.finaliseQueuedWithdrawal.selector, receiver, index)
        );
    }

    function _finaliseQueuedWithdrawalsAggregatedCall(address receiver, address token, uint256[] memory indices)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit FinaliseQueuedWithdrawalsAggregatedCall(receiver, token, indices);

        vm.prank(currentActor);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000}(
            abi.encodeWithSelector(
                RootERC20BridgeFlowRate.finaliseQueuedWithdrawalsAggregated.selector, receiver, token, indices
            )
        );
    }

    function _onMessageReceiveRootCall(bytes memory data) internal returns (bool success, bytes memory returnData) {
        emit OnMessageReceiveRootCall(data);

        vm.prank(currentActor);

        (success, returnData) =
            mockAdaptorRoot.call{gas: 1000000}(abi.encodeWithSelector(MockAdaptor.onMessageReceive.selector, data));
    }

    function _pauseRootCall() internal returns (bool success, bytes memory returnData) {
        emit PauseRootCall();

        (success, returnData) =
            rootERC20BridgeFlowRate.call{gas: 1000000}(abi.encodeWithSelector(BridgeRoles.pause.selector));
    }

    function _setRateControlThresholdCall(
        address token,
        uint256 capacity,
        uint256 refillRate,
        uint256 largeTransferThreshold
    ) internal returns (bool success, bytes memory returnData) {
        emit SetRateControlThresholdCall(token, capacity, refillRate, largeTransferThreshold);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000}(
            abi.encodeWithSelector(
                RootERC20BridgeFlowRate.setRateControlThreshold.selector,
                token,
                capacity,
                refillRate,
                largeTransferThreshold
            )
        );
    }

    function _setWithdrawalDelayCall(uint256 delay) internal returns (bool success, bytes memory returnData) {
        emit SetWithdrawalDelayCall(delay);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000}(
            abi.encodeWithSelector(RootERC20BridgeFlowRate.setWithdrawalDelay.selector, delay)
        );
    }

    function _unpauseRootCall() internal returns (bool success, bytes memory returnData) {
        emit UnpauseRootCall();

        (success, returnData) =
            rootERC20BridgeFlowRate.call{gas: 1000000}(abi.encodeWithSelector(BridgeRoles.unpause.selector));
    }

    function _updateImxCumulativeDepositLimitCall(uint256 newImxCumulativeDepositLimit)
        internal
        returns (bool success, bytes memory returnData)
    {
        emit UpdateImxCumulativeDepositLimitCall(newImxCumulativeDepositLimit);

        (success, returnData) = rootERC20BridgeFlowRate.call{gas: 1000000}(
            abi.encodeWithSelector(
                RootERC20Bridge.updateImxCumulativeDepositLimit.selector, newImxCumulativeDepositLimit
            )
        );
    }
}
