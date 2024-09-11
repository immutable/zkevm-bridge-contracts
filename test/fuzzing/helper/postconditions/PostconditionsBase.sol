// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../properties/Properties.sol";

/**
 * @title PostconditionsBase
 * @author 0xScourgedev
 * @notice Contains general postconditions used across all postcondition contracts
 */
abstract contract PostconditionsBase is Properties {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     POSTCONDITIONS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice invariants to run after each successful transaction
     * @custom:invariant SPLY-01: The sum of the token balances of each user and the bridges should
     * be exactly equal to the token total supply
     */
    function onSuccessInvariantsGeneral(bytes memory returnData, address tokenToCheck) internal {
        invariant_SPLY_01(tokenToCheck);
    }

    /**
     * @notice invariants to run after each failed transaction
     */
    function onFailInvariantsGeneral(bytes memory returnData) internal {}
}
