// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title AdaptorRoles.sol
 * @notice AdaptorRoles.sol is an abstract contract that defines the roles and permissions across the root and child chain adaptor contracts.
 * @dev This contract uses OpenZeppelin's AccessControl contract. This contract is abstract and is intended to be inherited by the root and child chain adaptor contracts.
 */
abstract contract AdaptorRoles is AccessControlUpgradeable {
    // Roles
    /// @notice Role identifier for those who can update the bridge used by the adaptor.
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER");

    /// @notice Role identifier for those who can update the gas service used by the adaptor.
    bytes32 public constant GAS_SERVICE_MANAGER_ROLE = keccak256("GAS_SERVICE_MANAGER");

    /// @notice Role identifier for those who can update targeted bridge used by the adpator (e.g. target is child chain on root adaptors).
    bytes32 public constant TARGET_MANAGER_ROLE = keccak256("TARGET_MANAGER");

    // Role granting functions
    /**
     * @notice Function to grant bridge manager role to an address
     */
    function grantBridgeManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BRIDGE_MANAGER_ROLE, account);
    }

    /**
     * @notice Function to grant gas service manager role to an address
     */
    function grantGasServiceManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(GAS_SERVICE_MANAGER_ROLE, account);
    }

    /**
     * @notice Function to grant target manager role to an address
     */
    function grantTargetManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(TARGET_MANAGER_ROLE, account);
    }

    // Role revoking functions
    /**
     * @notice Function to revoke bridge manager role from an address
     */
    function revokeBridgeManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BRIDGE_MANAGER_ROLE, account);
    }

    /**
     * @notice Function to revoke gas service manager role from an address
     */
    function revokeGasServiceManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(GAS_SERVICE_MANAGER_ROLE, account);
    }

    /**
     * @notice Function to target manager role from an address
     */
    function revokeTargetMangaerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(TARGET_MANAGER_ROLE, account);
    }
}
