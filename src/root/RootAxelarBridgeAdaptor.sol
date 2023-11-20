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
 * @notice RootAxelarBridgeAdaptor is a bridge adaptor that allows the RootERC20Bridge to communicate with the Axelar Gateway.
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
     * @notice Sends an arbitrary message to the child chain, via the Axelar network.
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
     */
    function _execute(string calldata sourceChain_, string calldata sourceAddress_, bytes calldata payload_)
        internal
        override
    {
        emit AdaptorExecute(sourceChain_, sourceAddress_, payload_);
        rootBridge.onMessageReceive(sourceChain_, sourceAddress_, payload_);
    }

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gapRootAxelarBridgeAdaptor;
}
