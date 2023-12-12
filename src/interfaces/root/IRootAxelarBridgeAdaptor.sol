// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

/**
 * @title Root Axelar Bridge Adaptor interface
 * @notice Defines the functions and types of a root chain bridge adaptor.
 */
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
     * @notice Update the child chain bridge adaptor address
     * @param newChildBridgeAdaptor address of the new child bridge adaptor.
     * @dev Can only be called by TARGET_MANAGER_ROLE.
     */
    function updateChildBridgeAdaptor(string memory newChildBridgeAdaptor) external;

    /**
     * @notice Update the gas service.
     * @param newGasService Address of new gas service.
     * @dev Can only be called by GAS_SERVICE_MANAGER_ROLE.
     */
    function updateGasService(address newGasService) external;

    /**
     * @notice Get the child chain id
     * @return Axelar's string id of the child chain.
     */
    function childChainId() external view returns (string memory);

    /**
     * @notice Get the child bridge adaptor address.
     * @return String representation of the check sum address of the bridge adaptor on the child chain
     */
    function childBridgeAdaptor() external view returns (string memory);
}

/**
 * @title Root Bridge Adaptor Errors
 * @notice Contains the different error types that can be thrown by a bridge adaptor
 */
interface IRootAxelarBridgeAdaptorErrors {
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddresses();
    /// @notice Error when a message is to be sent to a child chain that isn't valid.
    error InvalidChildChain();
    /// @notice Error when no gas (in the form of `msg.value`) is given to the transaction to pay for Axelar message passing.
    error NoGas();
    /// @notice Error when the contract calling the adaptor is not the bridge.
    error CallerNotBridge();
    /// @notice Error when the given child chain bridge adaptor is invalid.
    error InvalidChildBridgeAdaptor();
    /// @notice Error when a message received has invalid source address.
    error InvalidSourceAddress();
    /// @notice Error when a message received has invalid source chain.
    error InvalidSourceChain();
    /// @notice Error when the an unauthorized initializer tries to initialize the contract.
    error UnauthorizedInitializer();
    /// @notice Error when a function that isn't supported by the adaptor is called.
    error UnsupportedOperation();
}

/**
 * @title Root Bridge Adaptor Events
 * @notice Contains the event types that can be emitted by a bridge adaptor
 */
interface IRootAxelarBridgeAdaptorEvents {
    /// @notice Emitted when the child chain bridge adaptor is updated.
    event ChildBridgeAdaptorUpdated(string oldChildBridgeAdaptor, string newChildBridgeAdaptor);
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
