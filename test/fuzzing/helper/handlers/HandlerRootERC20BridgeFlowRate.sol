// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../preconditions/PreconditionsRootERC20BridgeFlowRate.sol";
import "../postconditions/PostconditionsRootERC20BridgeFlowRate.sol";

/**
 * @title HandlerRootERC20BridgeFlowRate
 * @author 0xScourgedev
 * @notice Fuzz handlers for RootERC20BridgeFlowRate
 */
contract HandlerRootERC20BridgeFlowRate is
    PreconditionsRootERC20BridgeFlowRate,
    PostconditionsRootERC20BridgeFlowRate
{
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HANDLERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice This handler calls the activateWithdrawalQueue function for the root bridge
     */
    function handler_activateWithdrawalQueue() public setCurrentActor {
        activateWithdrawalQueuePreconditions();

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) = _activateWithdrawalQueueCall();

        activateWithdrawalQueuePostconditions(success, returnData, actorsToUpdate, address(0));
    }

    /**
     * @notice This handler calls the deactivateWithdrawalQueue function for the root bridge
     */
    function handler_deactivateWithdrawalQueue() public setCurrentActor {
        deactivateWithdrawalQueuePreconditions();

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) = _deactivateWithdrawalQueueCall();

        deactivateWithdrawalQueuePostconditions(success, returnData, actorsToUpdate, address(0));
    }

    /**
     * @notice This handler calls the deposit function for the root bridge
     * @param rootTokenSelector The selector for the root token
     * @param amount The amount of tokens to be deposited
     * @param value The native token value of the transaction
     */
    function handler_deposit(uint8 rootTokenSelector, uint256 amount, uint256 value) public setCurrentActor {
        DepositParams memory params = depositPreconditions(rootTokenSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.rootToken);

        (bool success, bytes memory returnData) = _depositCall(params.rootToken, params.amount, params.value);

        depositPostconditions(success, returnData, actorsToUpdate, params.rootToken, params.amount, params.value);
    }

    /**
     * @notice This handler calls the depositETH function for the root bridge
     * @param amount The amount of native tokens to be deposited
     * @param value The native token value of the transaction
     */
    function handler_depositETH(uint256 amount, uint256 value) public setCurrentActor {
        DepositETHParams memory params = depositETHPreconditions(amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, NATIVE_ETH);

        (bool success, bytes memory returnData) = _depositETHCall(params.amount, params.value);

        depositETHPostconditions(success, returnData, actorsToUpdate, NATIVE_ETH, params.amount, params.value);
    }

    /**
     * @notice This handler calls the depositTo function for the root bridge
     * @param rootTokenSelector The selector for the root token to deposit
     * @param receiverSelector The selector for the receiver of the deposit
     * @param amount The amount of tokens to be deposited
     * @param value The native token value of the transaction
     */
    function handler_depositTo(uint8 rootTokenSelector, uint8 receiverSelector, uint256 amount, uint256 value)
        public
        setCurrentActor
    {
        DepositToParams memory params = depositToPreconditions(rootTokenSelector, receiverSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.rootToken);

        (bool success, bytes memory returnData) =
            _depositToCall(params.rootToken, params.receiver, params.amount, params.value);

        depositToPostconditions(success, returnData, actorsToUpdate, params.rootToken, params.amount, params.value);
    }

    /**
     * @notice This handler calls the depositToETH function for the root bridge
     * @param receiverSelector The selector for the receiver of the deposit
     * @param amount The amount of native tokens to be deposited
     * @param value The native token value of the transaction
     */
    function handler_depositToETH(uint8 receiverSelector, uint256 amount, uint256 value) public setCurrentActor {
        DepositToETHParams memory params = depositToETHPreconditions(receiverSelector, amount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, NATIVE_ETH);

        (bool success, bytes memory returnData) = _depositToETHCall(params.receiver, params.amount, params.value);

        depositToETHPostconditions(success, returnData, actorsToUpdate, NATIVE_ETH, params.amount, params.value);
    }

    /**
     * @notice This handler calls the finaliseQueuedWithdrawal function for the root bridge
     * @param receiverSelector The selector for the receiver of the withdrawal
     * @param index The index of the withdrawal to finalize
     */
    function handler_finaliseQueuedWithdrawal(uint8 receiverSelector, uint256 index) public setCurrentActor {
        FinaliseQueuedWithdrawalParams memory params = finaliseQueuedWithdrawalPreconditions(receiverSelector, index);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        uint256[] memory indices = new uint256[](1);
        indices[0] = index;

        // If the withdrawal does not exist, then the before call will just get a zero address, and not do anything
        FlowRateWithdrawalQueue.PendingWithdrawal[] memory withdrawals =
            FlowRateWithdrawalQueue(rootERC20BridgeFlowRate).getPendingWithdrawals(params.receiver, indices);

        _before(actorsToUpdate, withdrawals[0].token);

        (bool success, bytes memory returnData) = _finaliseQueuedWithdrawalCall(params.receiver, params.index);

        finaliseQueuedWithdrawalPostconditions(success, returnData, actorsToUpdate, withdrawals[0]);
    }

    /**
     * @notice This handler calls the finaliseQueuedWithdrawalsAggregated function for the root bridge
     * @param receiverSelector The selector for the receiver of the aggregated withdrawals
     * @param tokenSelector The selector for the root token to finalize the withdrawals for
     * @param length The length of the indices array to finalize for
     * @param entropy The entropy to generate the indices from
     */
    function handler_finaliseQueuedWithdrawalsAggregated(
        uint8 receiverSelector,
        uint8 tokenSelector,
        uint256 length,
        uint256 entropy
    ) public setCurrentActor {
        FinaliseQueuedWithdrawalsAggregatedParams memory params =
            finaliseQueuedWithdrawalsAggregatedPreconditions(receiverSelector, tokenSelector, length, entropy);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.token);

        (bool success, bytes memory returnData) =
            _finaliseQueuedWithdrawalsAggregatedCall(params.receiver, params.token, params.indices);

        finaliseQueuedWithdrawalsAggregatedPostconditions(success, returnData, actorsToUpdate, params.token);
    }

    /**
     * @notice This handler calls the onMessageReceive function for the root bridge
     * @param isWithdraw If this is true, then the signature is for a withdraw, otherwise it is for a invalid signature
     * @param rootTokenSelector The selector for the root token to be withdrawn
     * @param withdrawerSelector The selector for the withdrawer
     * @param receiverSelector The selector for the receiver of the withdrawal
     * @param amount The amount of tokens to be withdrawn
     */
    function handler_onMessageReceiveRoot(
        bool isWithdraw,
        uint8 rootTokenSelector,
        uint8 withdrawerSelector,
        uint8 receiverSelector,
        uint256 amount
    ) public setCurrentActor {
        OnMessageReceiveRootParams memory params = onMessageReceiveRootPreconditions(
            isWithdraw, rootTokenSelector, withdrawerSelector, receiverSelector, amount
        );

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = params.receiver;

        _before(actorsToUpdate, params.rootToken);

        (bool success, bytes memory returnData) = _onMessageReceiveRootCall(params.data);

        onMessageReceiveRootPostconditions(
            success, returnData, actorsToUpdate, params.rootToken, params.amount, params.receiver
        );
    }

    /**
     * @notice This handler calls the pause function for the root bridge
     */
    function handler_pauseRoot() public setCurrentActor {
        pauseRootPreconditions();

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) = _pauseRootCall();

        pauseRootPostconditions(success, returnData, actorsToUpdate, address(0));
    }

    /**
     * @notice This handler calls the setRateControlThreshold function for the root bridge
     * @param tokenSelector The token selector for the token to set the rate control threshold for
     * @param capacity The new capacity of the bucket for the selected token
     * @param refillRate The new refill rate of the bucket for the selected token
     * @param largeTransferThreshold The new large transfer threshold for the selected token
     */
    function handler_setRateControlThreshold(
        uint8 tokenSelector,
        uint256 capacity,
        uint256 refillRate,
        uint256 largeTransferThreshold
    ) public setCurrentActor {
        SetRateControlThresholdParams memory params =
            setRateControlThresholdPreconditions(tokenSelector, capacity, refillRate, largeTransferThreshold);

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, params.token);

        (bool success, bytes memory returnData) = _setRateControlThresholdCall(
            params.token, params.capacity, params.refillRate, params.largeTransferThreshold
        );

        setRateControlThresholdPostconditions(success, returnData, actorsToUpdate, params.token);
    }

    /**
     * @notice This handler calls the setWithdrawalDelay function for the root bridge
     * @param delay The new withdrawal delay
     */
    function handler_setWithdrawalDelay(uint256 delay) public setCurrentActor {
        SetWithdrawalDelayParams memory params = setWithdrawalDelayPreconditions(delay);

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) = _setWithdrawalDelayCall(params.delay);

        setWithdrawalDelayPostconditions(success, returnData, actorsToUpdate, address(0));
    }

    /**
     * @notice This handler calls the unpause function for the root bridge
     */
    function handler_unpauseRoot() public setCurrentActor {
        unpauseRootPreconditions();

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) = _unpauseRootCall();

        unpauseRootPostconditions(success, returnData, actorsToUpdate, address(0));
    }

    /**
     * @notice This handler calls the updateImxCumulativeDepositLimit function for the root bridge
     * @param newImxCumulativeDepositLimit The new cumulative deposit limit for IMX
     */
    function handler_updateImxCumulativeDepositLimit(uint256 newImxCumulativeDepositLimit) public setCurrentActor {
        UpdateImxCumulativeDepositLimitParams memory params =
            updateImxCumulativeDepositLimitPreconditions(newImxCumulativeDepositLimit);

        address[] memory actorsToUpdate = new address[](0);

        _before(actorsToUpdate, address(0));

        (bool success, bytes memory returnData) =
            _updateImxCumulativeDepositLimitCall(params.newImxCumulativeDepositLimit);

        updateImxCumulativeDepositLimitPostconditions(success, returnData, actorsToUpdate, address(0));
    }
}
