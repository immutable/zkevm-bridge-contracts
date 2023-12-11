// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;
/**
 * @title Child Bridge Adaptor Errors
 * @notice Contains the different error types that can be thrown by a bridge adaptor
 */

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
     * @notice Update the root chain bridge adaptor address
     * @param newRootBridgeAdaptor address of the new child bridge adaptor.
     * @dev Can only be called by TARGET_MANAGER_ROLE.
     */
    function updateRootBridgeAdaptor(string memory newRootBridgeAdaptor) external;

    /**
     * @notice Update the gas service.
     * @param newGasService Address of new gas service.
     * @dev Can only be called by GAS_SERVICE_MANAGER_ROLE.
     */
    function updateGasService(address newGasService) external;

    /**
     * @notice Get the root chain id
     * @return Axelar's string id of the root chain.
     */
    function rootChainId() external view returns (string memory);

    /**
     * @notice Get the root bridge adaptor address.
     * @return String representation of the check sum address of the bridge adaptor on the root chain
     */
    function rootBridgeAdaptor() external view returns (string memory);
}

interface IChildAxelarBridgeAdaptorErrors {
    /// @notice Error when the given bridge adaptor is invalid.
    error InvalidRootBridgeAdaptor();
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
    /// @notice Error when a message is sent with no gas payment.
    error NoGas();
    /// @notice Error when the caller is not the bridge.
    error CallerNotBridge();
    /// @notice Error when the root chain name is invalid.
    error InvalidRootChain();
    /// @notice Error when the message's source chain is not valid.
    error InvalidSourceChain();
    /// @notice Error when the source chain's message sender is not a recognised address.
    error InvalidSourceAddress();
    /// @notice Error when the an unauthorized initializer tries to initialize the contract.
    error UnauthorizedInitializer();
}

/**
 * @title Child Bridge Adaptor Events
 * @notice Contains the event types that can be emitted by a bridge adaptor
 */
interface IChildAxelarBridgeAdaptorEvents {
    /// @notice Emitted when the root chain bridge adaptor is updated.
    event RootBridgeAdaptorUpdated(string oldRootBridgeAdaptor, string newRootBridgeAdaptor);
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
