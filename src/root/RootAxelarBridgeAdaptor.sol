// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol";
import {IRootERC20BridgeAdaptor} from "../interfaces/root/IRootERC20BridgeAdaptor.sol";
import {
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors,
    IRootAxelarBridgeAdaptor
} from "../interfaces/root/IRootAxelarBridgeAdaptor.sol";
import {IRootERC20Bridge} from "../interfaces/root/IRootERC20Bridge.sol";
import {AdaptorRoles} from "../common/AdaptorRoles.sol";

/**
 * @notice Facilitates communication between the RootERC20Bridge and the Axelar Gateway. It enables sending and receiving messages to and from the child chain.
 * @dev Features:
 *      - Send messages to the child chain via the Axelar Gateway.
 *      - Receive messages from the child chain via the Axelar Gateway.
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
contract RootAxelarBridgeAdaptor is
    AxelarExecutable,
    IRootERC20BridgeAdaptor,
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors,
    IRootAxelarBridgeAdaptor,
    AdaptorRoles
{
    IRootERC20Bridge public rootBridge;
    string public childChain;
    IAxelarGasService public gasService;

    constructor(address _gateway) AxelarExecutable(_gateway) {}

    /**
     * @notice Initilization function for RootAxelarBridgeAdaptor.
     * @param newRoles Struct containing addresses of roles.
     * @param _rootBridge Address of root bridge contract.
     * @param _childChain Name of child chain.
     * @param _gasService Address of Axelar Gas Service contract.
     */
    function initialize(
        InitializationRoles memory newRoles,
        address _rootBridge,
        string memory _childChain,
        address _gasService
    ) public initializer {
        if (
            _rootBridge == address(0) || _gasService == address(0) || newRoles.defaultAdmin == address(0)
                || newRoles.bridgeManager == address(0) || newRoles.gasServiceManager == address(0)
                || newRoles.targetManager == address(0)
        ) {
            revert ZeroAddresses();
        }

        if (bytes(_childChain).length == 0) {
            revert InvalidChildChain();
        }

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, newRoles.defaultAdmin);
        _grantRole(BRIDGE_MANAGER_ROLE, newRoles.bridgeManager);
        _grantRole(GAS_SERVICE_MANAGER_ROLE, newRoles.gasServiceManager);
        _grantRole(TARGET_MANAGER_ROLE, newRoles.targetManager);

        rootBridge = IRootERC20Bridge(_rootBridge);
        childChain = _childChain;
        gasService = IAxelarGasService(_gasService);
    }

    /**
     * @inheritdoc IRootAxelarBridgeAdaptor
     */
    function updateRootBridge(address newRootBridge) external override onlyRole(BRIDGE_MANAGER_ROLE) {
        if (newRootBridge == address(0)) {
            revert ZeroAddresses();
        }

        emit RootBridgeUpdated(address(rootBridge), newRootBridge);
        rootBridge = IRootERC20Bridge(newRootBridge);
    }

    /**
     * @inheritdoc IRootAxelarBridgeAdaptor
     */
    function updateChildChain(string memory newChildChain) external override onlyRole(TARGET_MANAGER_ROLE) {
        if (bytes(newChildChain).length == 0) {
            revert InvalidChildChain();
        }

        emit ChildChainUpdated(childChain, newChildChain);
        childChain = newChildChain;
    }

    /**
     * @inheritdoc IRootAxelarBridgeAdaptor
     */
    function updateGasService(address newGasService) external override onlyRole(GAS_SERVICE_MANAGER_ROLE) {
        if (newGasService == address(0)) {
            revert ZeroAddresses();
        }

        emit GasServiceUpdated(address(gasService), newGasService);
        gasService = IAxelarGasService(newGasService);
    }

    /**
     * @inheritdoc IRootERC20BridgeAdaptor
     */
    function sendMessage(bytes calldata payload, address refundRecipient) external payable override {
        if (msg.value == 0) {
            revert NoGas();
        }
        if (msg.sender != address(rootBridge)) {
            revert CallerNotBridge();
        }

        // Load from storage.
        string memory _childBridgeAdaptor = IRootERC20Bridge(rootBridge).childBridgeAdaptor();
        string memory _childChain = childChain;

        // TODO For `sender` (first param), should likely be refundRecipient (and in which case refundRecipient should be renamed to sender and used as refund recipient)
        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), _childChain, _childBridgeAdaptor, payload, refundRecipient
        );

        gateway.callContract(_childChain, _childBridgeAdaptor, payload);
        emit AxelarMessageSent(_childChain, _childBridgeAdaptor, payload);
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
        rootBridge.onMessageReceive(sourceChain_, sourceAddress_, payload_);
    }
}
