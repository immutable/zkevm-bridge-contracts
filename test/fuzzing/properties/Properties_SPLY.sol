// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_SPLY
 * @author 0xScourgedev
 * @notice Contains all SPLY invariants
 */
abstract contract Properties_SPLY is PropertiesBase {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INVARIANTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @custom:invariant SPLY-01: The sum of the token balances of each user and the bridges should
     * be exactly equal to the token total supply
     */
    function invariant_SPLY_01(address token) internal {
        if (token == NATIVE_ETH || token == address(0)) return;
        uint256 totalBal = 0;

        for (uint256 i = 0; i < USERS.length; i++) {
            totalBal += states[1].tokenStates[token].balances[USERS[i]];
        }

        totalBal += states[1].tokenStates[token].balances[rootERC20BridgeFlowRate];
        totalBal += states[1].tokenStates[token].balances[childERC20Bridge];

        fl.eq(totalBal, states[1].tokenStates[token].totalSupply, SPLY_01);
    }

    /**
     * @custom:invariant SPLY-02: The total supply of root WETH must be decreased by the amount
     * of WETH deposited by the user
     */
    function invariant_SPLY_02(address token, uint256 amount) internal {
        if (token != wETH) return;

        fl.eq(states[1].tokenStates[token].totalSupply, states[0].tokenStates[token].totalSupply - amount, SPLY_02);
    }

    /**
     * @custom:invariant The total supply of child ERC20s must be increased by exactly the amount
     * of tokens deposited by the user
     */
    function invariant_SPLY_03(address token, uint256 amount) internal {
        if (token == NATIVE_IMX || token == address(0)) return;

        fl.eq(states[1].tokenStates[token].totalSupply, states[0].tokenStates[token].totalSupply + amount, SPLY_03);
    }

    /**
     * @custom:invariant The total supply of child ERC20s must be decreased by exactly the amount
     * of tokens withdrawn by the user
     */
    function invariant_SPLY_04(address token, uint256 amount) internal {
        fl.eq(states[1].tokenStates[token].totalSupply, states[0].tokenStates[token].totalSupply - amount, SPLY_04);
    }
}
