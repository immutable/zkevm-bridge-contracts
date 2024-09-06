// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../FuzzSetup.sol";

/**
 * @title BeforeAfter
 * @author 0xScourgedev
 * @notice Contains the states of the system before and after calls
 */
abstract contract BeforeAfter is FuzzSetup {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct State {
        // actor => actorStates
        mapping(address => ActorStates) actorStates;
        // token => tokenState
        mapping(address => TokenState) tokenStates;
        uint256 imxCumulativeDepositLimit;
        uint256 rootIMXTokenBalOfRootBridge;
        uint256 rootWETHBalOfRootBridge;
        uint256 childWIMXBalOfChildBridge;
        uint256 nativeBalanceOfRootAdaptor;
        uint256 nativeBalanceOfChildAdaptor;
        uint256 nativeBalanceOfRootBridge;
        uint256 nativeBalanceOfChildBridge;
        uint256 withdrawalDelay;
        bool rootBridgePaused;
        bool childBridgePaused;
        bool withdrawalQueueActivated;
    }

    struct ActorStates {
        uint256 queueLength;
    }

    struct TokenState {
        // address => balance
        mapping(address => uint256) balances;
        uint256 totalSupply;
        uint256 capacity;
        uint256 depth;
        uint256 refillTime;
        uint256 refillRate;
        uint256 largeTransferThresholds;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         VARIABLES                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // callNum => State
    mapping(uint8 => State) states;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         FUNCTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _before(address[] memory actors, address tokenToUpdate) internal {
        _setStates(0, actors, tokenToUpdate);

        if (DEBUG) debugBefore(actors, tokenToUpdate);
    }

    function _after(address[] memory actors, address tokenToUpdate) internal {
        _setStates(1, actors, tokenToUpdate);

        if (DEBUG) debugAfter(actors, tokenToUpdate);
    }

    function _setStates(uint8 callNum, address[] memory actors, address tokenToUpdate) internal {
        for (uint256 i = 0; i < actors.length; i++) {
            _setActorState(callNum, actors[i], tokenToUpdate);
        }

        _setTokenState(callNum, tokenToUpdate);

        states[callNum].imxCumulativeDepositLimit =
            RootERC20Bridge(payable(rootERC20BridgeFlowRate)).imxCumulativeDepositLimit();
        states[callNum].rootIMXTokenBalOfRootBridge = getBalance(rootIMXToken, rootERC20BridgeFlowRate);
        states[callNum].rootWETHBalOfRootBridge = getBalance(wETH, rootERC20BridgeFlowRate);
        states[callNum].childWIMXBalOfChildBridge = getBalance(wIMX, childERC20Bridge);
        states[callNum].nativeBalanceOfRootAdaptor = mockAdaptorRoot.balance;
        states[callNum].nativeBalanceOfChildAdaptor = mockAdaptorChild.balance;

        states[callNum].nativeBalanceOfRootBridge = rootERC20BridgeFlowRate.balance;
        states[callNum].nativeBalanceOfChildBridge = childERC20Bridge.balance;

        states[callNum].withdrawalDelay = FlowRateWithdrawalQueue(payable(rootERC20BridgeFlowRate)).withdrawalDelay();

        states[callNum].rootBridgePaused = RootERC20Bridge(payable(rootERC20BridgeFlowRate)).paused();
        states[callNum].childBridgePaused = ChildERC20Bridge(payable(childERC20Bridge)).paused();

        states[callNum].withdrawalQueueActivated =
            FlowRateDetection(payable(rootERC20BridgeFlowRate)).withdrawalQueueActivated();
    }

    function _setActorState(uint8 callNum, address actor, address tokenToUpdate) internal {
        states[callNum].actorStates[actor].queueLength =
            FlowRateWithdrawalQueue(payable(rootERC20BridgeFlowRate)).getPendingWithdrawalsLength(actor);
    }

    function _setTokenState(uint8 callNum, address tokenToUpdate) internal {
        if (tokenToUpdate == address(0)) return;

        if (tokenToUpdate != NATIVE_ETH) {
            states[callNum].tokenStates[tokenToUpdate].totalSupply = ChildERC20(tokenToUpdate).totalSupply();
        }

        for (uint256 i = 0; i < USERS.length; i++) {
            states[callNum].tokenStates[tokenToUpdate].balances[USERS[i]] = getBalance(tokenToUpdate, USERS[i]);
        }

        states[callNum].tokenStates[tokenToUpdate].balances[rootERC20BridgeFlowRate] =
            getBalance(tokenToUpdate, rootERC20BridgeFlowRate);
        states[callNum].tokenStates[tokenToUpdate].balances[childERC20Bridge] =
            getBalance(tokenToUpdate, childERC20Bridge);

        (uint256 capacity, uint256 depth, uint256 refillTime, uint256 refillRate) =
            FlowRateDetection(rootERC20BridgeFlowRate).flowRateBuckets(tokenToUpdate);
        states[callNum].tokenStates[tokenToUpdate].capacity = capacity;
        states[callNum].tokenStates[tokenToUpdate].depth = depth;
        states[callNum].tokenStates[tokenToUpdate].refillTime = refillTime;
        states[callNum].tokenStates[tokenToUpdate].refillRate = refillRate;

        states[callNum].tokenStates[tokenToUpdate].largeTransferThresholds =
            RootERC20BridgeFlowRate(payable(rootERC20BridgeFlowRate)).largeTransferThresholds(tokenToUpdate);
    }

    function debugBefore(address[] memory actors, address tokenToUpdate) internal {
        debugState(0, actors, tokenToUpdate);
    }

    function debugAfter(address[] memory actors, address tokenToUpdate) internal {
        debugState(1, actors, tokenToUpdate);
    }

    function debugState(uint8 callNum, address[] memory actors, address tokenToUpdate) internal {
        for (uint256 i = 0; i < actors.length; i++) {
            debugActorState(callNum, actors[i]);
        }

        debugTokenState(callNum, tokenToUpdate);
    }

    function debugActorState(uint8 callNum, address actor) internal {}

    function debugTokenState(uint8 callNum, address tokenToUpdate) internal {
        fl.log("Token address: ", tokenToUpdate);
        if (tokenToUpdate == address(0)) return;

        if (tokenToUpdate != NATIVE_ETH) {
            fl.log("Token: ", ChildERC20(tokenToUpdate).name());
        }
    }

    function getBalance(address token, address user) internal returns (uint256) {
        if (token == NATIVE_ETH) {
            return user.balance;
        } else {
            return ChildERC20(token).balanceOf(user);
        }
    }
}
