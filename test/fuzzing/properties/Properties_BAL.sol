// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_BAL
 * @author 0xScourgedev
 * @notice Contains all BAL invariants
 */
abstract contract Properties_BAL is PropertiesBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INVARIANTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @custom:invariant BAL-01: The WETH balance of the root bridge should always be 0
     */
    function invariant_BAL_01() internal {
        fl.eq(states[1].rootWETHBalOfRootBridge, 0, BAL_01);
    }

    /**
     * @custom:invariant BAL-02: The WIMX balance of the child bridge should always be 0
     */
    function invariant_BAL_02() internal {
        fl.eq(states[1].childWIMXBalOfChildBridge, 0, BAL_02);
    }

    /**
     * @custom:invariant BAL-03: The native balance of the root adaptor increases by exactly the
     * gas fees paid by the users
     */
    function invariant_BAL_03(uint256 gas) internal {
        fl.eq(states[1].nativeBalanceOfRootAdaptor, states[0].nativeBalanceOfRootAdaptor + gas, BAL_03);
    }

    /**
     * @custom:invariant BAL-04: The native balance of the child adaptor increases by exactly
     * the gas fees paid by the users
     */
    function invariant_BAL_04(uint256 gas) internal {
        fl.eq(states[1].nativeBalanceOfChildAdaptor, states[0].nativeBalanceOfChildAdaptor + gas, BAL_04);
    }

    /**
     * @custom:invariant BAL-05: The token balance, excluding WETH, of the root bridge increases
     * by exactly the amount of tokens deposited by the user
     */
    function invariant_BAL_05(address token, uint256 amount) internal {
        if (token == wETH) return;
        fl.eq(
            states[1].tokenStates[token].balances[rootERC20BridgeFlowRate],
            states[0].tokenStates[token].balances[rootERC20BridgeFlowRate] + amount,
            BAL_05
        );
    }

    /**
     * @custom:invariant BAL-06: The native balance of the root bridge increases by exactly the
     * amount of WETH deposited by the user
     */
    function invariant_BAL_06(address token, uint256 amount) internal {
        if (token != wETH) return;
        fl.eq(states[1].nativeBalanceOfRootBridge, states[0].nativeBalanceOfRootBridge + amount, BAL_06);
    }

    /**
     * @custom:invariant BAL-07: When depositing ETH, the native balance of the root bridge
     * increases by exactly the amount deposited by the user, minus the gas fees
     */
    function invariant_BAL_07(uint256 amount) internal {
        fl.eq(states[1].nativeBalanceOfRootBridge, states[0].nativeBalanceOfRootBridge + amount, BAL_07);
    }

    /**
     * @custom:invariant BAL-08: When withdrawing IMX, the native balance of the child bridge
     * increases by exactly the amount withdrawn by the user, minus the gas fees
     */
    function invariant_BAL_08(uint256 amount) internal {
        fl.eq(states[1].nativeBalanceOfChildBridge, states[0].nativeBalanceOfChildBridge + amount, BAL_08);
    }

    /**
     * @custom:invariant BAL-09: The native balance of the child bridge decreases by exactly
     * the amount of root ERC20 IMX deposited by the user
     */
    function invariant_BAL_09(address token, uint256 amount) internal {
        if (token != NATIVE_IMX && token != address(0)) return;
        fl.eq(states[1].nativeBalanceOfChildBridge, states[0].nativeBalanceOfChildBridge - amount, BAL_09);
    }
}
