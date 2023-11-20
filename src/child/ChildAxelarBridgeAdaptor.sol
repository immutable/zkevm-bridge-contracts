// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol";
import {IChildERC20Bridge} from "../interfaces/child/IChildERC20Bridge.sol";
import {
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptor
} from "../interfaces/child/IChildAxelarBridgeAdaptor.sol";
import {IChildERC20BridgeAdaptor} from "../interfaces/child/IChildERC20BridgeAdaptor.sol";
import {AdaptorRoles} from "../common/AdaptorRoles.sol";

/**
 * @notice Facilitates communication between the ChildERC20Bridge and the Axelar Gateway. It enables sending and receiving messages to and from the root chain.
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
    AxelarExecutable,
    IChildERC20BridgeAdaptor,
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptor,
    AdaptorRoles
{
    /// @notice Address of bridge to relay messages to.
    IChildERC20Bridge public childBridge;
    IAxelarGasService public gasService;
    string public rootChain;

    constructor(address _gateway) AxelarExecutable(_gateway) {}

    /**
     * @notice Initializes the contract.
     * @param _childBridge Address of the child bridge contract.
     */
    function initialize(
        InitializationRoles memory newRoles,
        string memory _rootChain,
        address _childBridge,
        address _gasService
    ) external initializer {
        if (
            _childBridge == address(0) || _gasService == address(0) || newRoles.defaultAdmin == address(0)
                || newRoles.bridgeManager == address(0) || newRoles.gasServiceManager == address(0)
                || newRoles.targetManager == address(0)
        ) {
            revert ZeroAddress();
        }

        if (bytes(_rootChain).length == 0) {
            revert InvalidRootChain();
        }

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, newRoles.defaultAdmin);
        _grantRole(BRIDGE_MANAGER_ROLE, newRoles.bridgeManager);
        _grantRole(GAS_SERVICE_MANAGER_ROLE, newRoles.gasServiceManager);
        _grantRole(TARGET_MANAGER_ROLE, newRoles.targetManager);

        childBridge = IChildERC20Bridge(_childBridge);
        rootChain = _rootChain;
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

        emit RootChainUpdated(rootChain, newRootChain);
        rootChain = newRootChain;
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
     * @inheritdoc IChildERC20BridgeAdaptor
     */
    function sendMessage(bytes calldata payload, address refundRecipient) external payable override {
        if (msg.value == 0) {
            revert NoGas();
        }
        if (msg.sender != address(childBridge)) {
            revert CallerNotBridge();
        }

        // Load from storage.
        string memory _rootBridgeAdaptor = childBridge.rootERC20BridgeAdaptor();
        string memory _rootChain = rootChain;

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), _rootChain, _rootBridgeAdaptor, payload, refundRecipient
        );

        gateway.callContract(_rootChain, _rootBridgeAdaptor, payload);
        emit AxelarMessageSent(_rootChain, _rootBridgeAdaptor, payload);
    }

    /**
     * @dev This function is called by the parent `AxelarExecutable` contract to execute the payload.
     * @param sourceChain_ The chain id that the message originated from.
     * @param sourceAddress_ The contract address that sent the message on the source chain.
     * @param payload_ The message payload.
     * @custom:assumes `sourceAddress_` is a 20 byte address.
     */
    function _execute(string calldata sourceChain_, string calldata sourceAddress_, bytes calldata payload_)
        internal
        override
    {
        emit AdaptorExecute(sourceChain_, sourceAddress_, payload_);
        childBridge.onMessageReceive(sourceChain_, sourceAddress_, payload_);
    }
}
