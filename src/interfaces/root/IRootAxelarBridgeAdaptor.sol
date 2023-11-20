// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

interface IRootAxelarBridgeAdaptor {
    /// @notice Initialization roles used by the adaptor.
    struct InitializationRoles {
        address defaultAdmin; // The address which will inherit `DEFAULT_ADMIN_ROLE`.
        address bridgeManager; // The address which will inherit `BRIDGE_MANAGER_ROLE`.
        address gasServiceManager; // The address which will inherit `GAS_SERVICE_MANAGER_ROLE`.
        address targetManager; // The address which will inherit `TARGET_MANAGER_ROLE`.
    }

    /**
     * @notice Update the root bridge
     * @param newRootBridge Address of new root bridge.
     * @dev Can only be called by BRIDGE_MANAGER_ROLE.
     */
    function updateRootBridge(address newRootBridge) external;

    /**
     * @notice Update the child chain name.
     * @param newChildChain Name of new child chain.
     * @dev Can only be called by TARGET_MANAGER_ROLE.
     */
    function updateChildChain(string memory newChildChain) external;

    /**
     * @notice Update the gas service.
     * @param newGasService Address of new gas service.
     * @dev Can only be called by GAS_SERVICE_MANAGER_ROLE.
     */
    function updateGasService(address newGasService) external;
}

interface IRootAxelarBridgeAdaptorErrors {
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddresses();
    /// @notice Error when a message is to be sent to a child chain that isn't valid.
    error InvalidChildChain();
    /// @notice Error when no gas (in the form of `msg.value`) is given to the transaction to pay for Axelar message passing.
    error NoGas();
    /// @notice Error when the contract calling the adaptor is not the bridge.
    error CallerNotBridge();
}

interface IRootAxelarBridgeAdaptorEvents {
    /// @notice Emitted when an Axelar message is sent to the child chain.
    event AxelarMessageSent(string indexed childChain, string indexed childBridgeAdaptor, bytes indexed payload);
    /// @notice Emitted when an Axelar message is received from the child chain.
    event AdaptorExecute(string sourceChain, string sourceAddress_, bytes payload_);
    /// @notice Emitted when the root bridge is updated.
    event RootBridgeUpdated(address indexed oldRootBridge, address indexed newRootBridge);
    /// @notice Emitted when the child chain name is updated.
    event ChildChainUpdated(string indexed oldChildChain, string indexed newChildChain);
    /// @notice Emitted when the gas service is updated.
    event GasServiceUpdated(address indexed oldGasService, address indexed newGasService);
}
