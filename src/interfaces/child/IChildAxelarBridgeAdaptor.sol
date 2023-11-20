// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

interface IChildAxelarBridgeAdaptor {
    /// @notice Initialization roles used by the adaptor.
    struct InitializationRoles {
        address defaultAdmin; // The address which will inherit `DEFAULT_ADMIN_ROLE`.
        address bridgeManager; // The address which will inherit `BRIDGE_MANAGER_ROLE`.
        address gasServiceManager; // The address which will inherit `GAS_SERVICE_MANAGER_ROLE`.
        address targetManager; // The address which will inherit `TARGET_MANAGER_ROLE`.
    }

    /**
     * @notice Update the child bridge
     * @param newChildBridge Address of new root bridge.
     * @dev Can only be called by BRIDGE_MANAGER_ROLE.
     */
    function updateChildBridge(address newChildBridge) external;

    /**
     * @notice Update the root chain name.
     * @param newRootChain Name of new root chain.
     * @dev Can only be called by TARGET_MANAGER_ROLE.
     */
    function updateRootChain(string memory newRootChain) external;

    /**
     * @notice Update the gas service.
     * @param newGasService Address of new gas service.
     * @dev Can only be called by GAS_SERVICE_MANAGER_ROLE.
     */
    function updateGasService(address newGasService) external;
}

interface IChildAxelarBridgeAdaptorErrors {
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
    /// @notice Error when a message is sent with no gas payment.
    error NoGas();
    /// @notice Error when the caller is not the bridge.
    error CallerNotBridge();
    /// @notice Error when the root chain name is invalid.
    error InvalidRootChain();
}

interface IChildAxelarBridgeAdaptorEvents {
    /// @notice Emitted when an Axelar message is sent to the root chain.
    event AxelarMessageSent(string indexed rootChain, string indexed rootBridgeAdaptor, bytes indexed payload);
    /// @notice Emitted when an Axelar message is received from the root chain.
    event AdaptorExecute(string sourceChain, string sourceAddress_, bytes payload_);
    /// @notice Emitted when the child bridge is updated.
    event ChildBridgeUpdated(address indexed oldRootBridge, address indexed newRootBridge);
    /// @notice Emitted when the root chain name is updated.
    event RootChainUpdated(string indexed oldChildChain, string indexed newChildChain);
    /// @notice Emitted when the gas service is updated.
    event GasServiceUpdated(address indexed oldGasService, address indexed newGasService);
}
