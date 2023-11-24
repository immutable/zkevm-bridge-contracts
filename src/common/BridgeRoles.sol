// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title BridgeRoles.sol
 * @notice BridgeRoles.sol is an abstract contract that defines the roles and permissions and pausable functionality across the root and child chain bridge contracts.
 * @dev This contract uses OpenZeppelin's AccessControl and Pausable contracts. This contract is abstract and is intended to be inherited by the root and child chain bridge contracts.
 */
abstract contract BridgeRoles is AccessControlUpgradeable, PausableUpgradeable {
    // Roles
    /// @notice Role identifier for those who can pause functionanlity.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER");

    /// @notice Role identifier for those who can unpause functionality.
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER");

    /// @notice Role identifier for those who can update the bridge adaptor.
    bytes32 public constant ADAPTOR_MANAGER_ROLE = keccak256("ADAPTOR_MANAGER");

    // Role granting functions
    /**
     * @notice Function to grant pauser role to an address
     */
    function grantPauserRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PAUSER_ROLE, account);
    }

    /**
     * @notice Function to grant unpauser role to an address
     */
    function grantUnpauserRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(UNPAUSER_ROLE, account);
    }

    /**
     * @notice Function to grant adaptor manager role to an address
     */
    function grantAdaptorManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADAPTOR_MANAGER_ROLE, account);
    }

    // Role revoking functions
    /**
     * @notice Function to revoke pauser role from an address
     */
    function revokePauserRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(PAUSER_ROLE, account);
    }

    /**
     * @notice Function to revoke unpauser role from an address
     */
    function revokeUnpauserRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(UNPAUSER_ROLE, account);
    }

    /**
     * @notice Function to revoke adaptor manager role from an address
     */
    function revokeAdaptorManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADAPTOR_MANAGER_ROLE, account);
    }

    // Pausable functions
    /**
     * @notice Function to pause the contract
     * @dev Only PAUSER_ROLE can call this function
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Function to pause the contract
     * @dev Only UNPAUSER_ROLE can call this function
     */
    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gapBridgeRoles;
}
