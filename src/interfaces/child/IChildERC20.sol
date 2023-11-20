// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0

pragma solidity 0.8.19;

import {IERC20MetadataUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

/**
 * @dev Interface of IChildERC20
 */
interface IChildERC20 is IERC20MetadataUpgradeable {
    /**
     * @dev Sets the values for {rootToken}, {name}, {symbol} and {decimals}.
     *
     * All these values are immutable: they can only be set once during
     * initialization.
     */
    function initialize(address rootToken_, string calldata name_, string calldata symbol_, uint8 decimals_) external;

    /**
     * @notice Returns bridge address controlling the child token
     * @return address Returns the address of the Bridge
     */
    function bridge() external view returns (address);

    /**
     * @notice Returns the address of the mapped token on the root chain
     * @return address Returns the address of the root token
     */
    function rootToken() external view returns (address);

    /**
     * @notice Mints an amount of tokens to a particular address
     * @dev Can only be called by the predicate address
     * @param account Account of the user to mint the tokens to
     * @param amount Amount of tokens to mint to the account
     * @return bool Returns true if function call is succesful
     */
    function mint(address account, uint256 amount) external returns (bool);

    /**
     * @notice Burns an amount of tokens from a particular address
     * @dev Can only be called by the predicate address
     * @param account Account of the user to burn the tokens from
     * @param amount Amount of tokens to burn from the account
     * @return bool Returns true if function call is succesful
     */
    function burn(address account, uint256 amount) external returns (bool);
}
