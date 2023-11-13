// SPDX-License-Identifier: Apache 2.0
// Adapted from OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)
pragma solidity 0.8.19;

import "../../child/ChildERC20.sol";

/**
 *   @title ChildERC20FailOnBurn
 *   @author Immutable (@Benjimmutable)
 *   @notice ChildERC20 contract, except burn always returns false. Used for testing.
 *   @dev USED FOR TESTING
 */
// solhint-disable reason-string
contract ChildERC20FailOnBurn is ChildERC20 {
    function burn(address, /*account*/ uint256 /*amount*/ ) public virtual override returns (bool) {
        return false;
    }
}
