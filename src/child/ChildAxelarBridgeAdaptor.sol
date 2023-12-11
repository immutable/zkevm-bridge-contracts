// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol";
import {IChildERC20Bridge} from "../interfaces/child/IChildERC20Bridge.sol";
import {
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptor
} from "../interfaces/child/IChildAxelarBridgeAdaptor.sol";
import {IChildBridgeAdaptor} from "../interfaces/child/IChildBridgeAdaptor.sol";
import {AdaptorRoles} from "../common/AdaptorRoles.sol";

/**
 * @notice Facilitates communication between the ChildERC20Bridge and the Axelar core contracts,to send and receive messages to and from the root chain.
 * @dev The contract ensures that any delivered message originated from the registered root chain and bridge adapter contract on the root chain. It will reject all other messages.
 * @dev Features:
 *      - Send messages to the root chain via the Axelar Gateway.
 *      - Receive messages from the root chain via the Axelar Gateway.
 *      - Manage Role Based Access Control
 * @dev Roles:
 *      - An account with a BRIDGE_MANAGER_ROLE can update the root bridge address.
 *      - An account with a TARGET_MANAGER_ROLE can update the child chain name.
 *      - An account with a GAS_SERVICE_MANAGER_ROLE can update the gas service address.
 *      - An account with a DEFAULT_ADMIN_ROLE can grant and revoke roles.
 * @dev Note:
 *      - This is an upgradeable contract that should be operated behind OpenZeppelin's TransparentUpgradeableProxy.
 *      - The initialize function is susceptible to front running, so precautions should be taken to account for this scenario.
 */
contract ChildAxelarBridgeAdaptor is
    AdaptorRoles,
    AxelarExecutable,
    IChildBridgeAdaptor,
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptor
{
    /// @notice Address of bridge to relay messages to.
    IChildERC20Bridge public childBridge;

    /// @notice Axelar's ID for the child chain. Axelar uses the chain name as the chain ID.
    string public rootChainId;

    /// @notice Address of the bridge adaptor on the root chain, which this contract will communicate with.
    string public rootBridgeAdaptor;

    IAxelarGasService public gasService;

    constructor(address _gateway) AxelarExecutable(_gateway) {}

    /**
     * @notice Initialization function for ChildAxelarBridgeAdaptor.
     * @param _roles Struct containing addresses of roles.
     * @param _childBridge Address of child bridge contract.
     * @param _rootChainId Axelar's string ID for the root chain.
     * @param _rootBridgeAdaptor Address of the bridge adaptor on the root chain.
     * @param _gasService Address of Axelar Gas Service contract.
     */
    function initialize(
        InitializationRoles memory _roles,
        address _childBridge,
        string memory _rootChainId,
        string memory _rootBridgeAdaptor,
        address _gasService
    ) external initializer {
        if (
            _childBridge == address(0) || _gasService == address(0) || _roles.defaultAdmin == address(0)
                || _roles.bridgeManager == address(0) || _roles.gasServiceManager == address(0)
                || _roles.targetManager == address(0)
        ) {
            revert ZeroAddress();
        }

        if (bytes(_rootChainId).length == 0) {
            revert InvalidRootChain();
        }

        if (bytes(_rootBridgeAdaptor).length == 0) {
            revert InvalidRootBridgeAdaptor();
        }
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _roles.defaultAdmin);
        _grantRole(BRIDGE_MANAGER_ROLE, _roles.bridgeManager);
        _grantRole(GAS_SERVICE_MANAGER_ROLE, _roles.gasServiceManager);
        _grantRole(TARGET_MANAGER_ROLE, _roles.targetManager);

        childBridge = IChildERC20Bridge(_childBridge);
        rootChainId = _rootChainId;
        rootBridgeAdaptor = _rootBridgeAdaptor;
        gasService = IAxelarGasService(_gasService);
    }

    /**
     * @inheritdoc IChildAxelarBridgeAdaptor
     */
    function updateChildBridge(address newChildBridge) external onlyRole(BRIDGE_MANAGER_ROLE) {
        if (newChildBridge == address(0)) {
            revert ZeroAddress();
        }

        emit ChildBridgeUpdated(address(childBridge), newChildBridge);
        childBridge = IChildERC20Bridge(newChildBridge);
    }

    /**
     * @inheritdoc IChildAxelarBridgeAdaptor
     */
    function updateRootChain(string memory newRootChain) external onlyRole(TARGET_MANAGER_ROLE) {
        if (bytes(newRootChain).length == 0) {
            revert InvalidRootChain();
        }

        emit RootChainUpdated(rootChainId, newRootChain);
        rootChainId = newRootChain;
    }

    /**
     * @inheritdoc IChildAxelarBridgeAdaptor
     */
    function updateRootBridgeAdaptor(string memory newRootBridgeAdaptor) external onlyRole(TARGET_MANAGER_ROLE) {
        if (bytes(newRootBridgeAdaptor).length == 0) {
            revert InvalidRootBridgeAdaptor();
        }

        emit RootBridgeAdaptorUpdated(rootBridgeAdaptor, newRootBridgeAdaptor);
        rootBridgeAdaptor = newRootBridgeAdaptor;
    }

    /**
     * @inheritdoc IChildAxelarBridgeAdaptor
     */
    function updateGasService(address newGasService) external onlyRole(GAS_SERVICE_MANAGER_ROLE) {
        if (newGasService == address(0)) {
            revert ZeroAddress();
        }

        emit GasServiceUpdated(address(gasService), newGasService);
        gasService = IAxelarGasService(newGasService);
    }

    /**
     * @inheritdoc IChildBridgeAdaptor
     */
    function sendMessage(bytes calldata payload, address refundRecipient) external payable override {
        if (msg.value == 0) {
            revert NoGas();
        }
        if (msg.sender != address(childBridge)) {
            revert CallerNotBridge();
        }

        // Load from storage.
        string memory _rootBridgeAdaptor = rootBridgeAdaptor;
        string memory _rootChain = rootChainId;

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), _rootChain, _rootBridgeAdaptor, payload, refundRecipient
        );

        gateway.callContract(_rootChain, _rootBridgeAdaptor, payload);
        emit AxelarMessageSent(_rootChain, _rootBridgeAdaptor, payload);
    }

    /**
     * @dev This function is called by the parent `AxelarExecutable` contract to execute a message payload sent from the root chain.
     *      It is only called after the message has been validated by the Axelar core contracts.
     *      Validations include, ensuring that the Axelar validator set has signed the message and that the message has not been executed before.
     *      For more details see:
     *        - [AxelarExecutable.sol](https://github.com/axelarnetwork/axelar-gmp-sdk-solidity/blob/main/contracts/executable/AxelarExecutable.sol#L17),
     *        - [AxelarGateway.sol](https://github.com/axelarnetwork/axelar-cgp-solidity/blob/d4536599321774927bf9716178a9e360f8e0efac/contracts/AxelarGateway.sol#L233)
     *
     * @dev The function first validates the message by checking that it originated from the registered
     *      root chain and bridge adaptor contract on the root chain. If not, the message is rejected.
     *      If a message is valid, it calls the child bridge contract's `onMessageReceive` function.
     * @param _sourceChain The chain id that the message originated from.
     * @param _sourceAddress The contract address that sent the message on the source chain.
     * @param _payload The message payload.
     * @custom:assumes `_sourceAddress` is a 20 byte address.
     */
    function _execute(string calldata _sourceChain, string calldata _sourceAddress, bytes calldata _payload)
        internal
        override
    {
        if (!Strings.equal(_sourceChain, rootChainId)) {
            revert InvalidSourceChain();
        }

        if (!Strings.equal(_sourceAddress, rootBridgeAdaptor)) {
            revert InvalidSourceAddress();
        }

        emit AdaptorExecute(_sourceChain, _sourceAddress, _payload);
        childBridge.onMessageReceive(_payload);
    }

    /**
     * @inheritdoc AxelarExecutable
     * @dev This function is called by the parent `AxelarExecutable` contract's `executeWithToken()` function.
     *      However, this function is not required for the bridge, and thus reverts with an `UnsupportedOperation` error.
     */
    function _executeWithToken(string calldata, string calldata, bytes calldata, string calldata, uint256)
        internal
        pure
        override
    {
        revert UnsupportedOperation();
    }

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gapChildAxelarBridgeAdaptor;
}
