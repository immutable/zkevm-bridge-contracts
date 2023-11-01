// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGasService} from "@axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol";
import {IAxelarGateway} from "@axelar-cgp-solidity/contracts/interfaces/IAxelarGateway.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IChildERC20Bridge} from "../interfaces/child/IChildERC20Bridge.sol";
import {
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents
} from "../interfaces/child/IChildAxelarBridgeAdaptor.sol";
import {IChildERC20BridgeAdaptor} from "../interfaces/child/IChildERC20BridgeAdaptor.sol";

contract ChildAxelarBridgeAdaptor is
    AxelarExecutable,
    IChildERC20BridgeAdaptor,
    Initializable,
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents
{
    /// @notice Address of bridge to relay messages to.
    IChildERC20Bridge public childBridge;
    IAxelarGasService public gasService;
    string public rootBridgeAdaptor;
    string public rootChain;

    constructor(address _gateway) AxelarExecutable(_gateway) {}

    /**
     * @notice Initializes the contract.
     * @param _childBridge Address of the child bridge contract.
     * @dev Always sets the rootBridgeAdaptor to whatever the rootERC20BridgeAdaptor of the bridge contract is.
     */
    function initialize(string memory _rootChain, address _childBridge, address _gasService) external initializer {
        if (_childBridge == address(0)) {
            revert ZeroAddress();
        }

        childBridge = IChildERC20Bridge(_childBridge);
        rootChain = _rootChain;
        gasService = IAxelarGasService(_gasService);
        rootBridgeAdaptor = childBridge.rootERC20BridgeAdaptor();
    }

    // TODO tests for this
    // TODO does this need to be permissioned?
    /**
     * @notice Sets the root bridge adaptor address.
     * @dev Always sets it to whatever the rootERC20BridgeAdaptor of the bridge contract is.
     */
    function setRootBridgeAdaptor() external {
        rootBridgeAdaptor = childBridge.rootERC20BridgeAdaptor();
    }

    /**
     * TODO
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
        string memory _rootChain = rootChain;

        // TODO For `sender` (first param), should likely be refundRecipient (and in which case refundRecipient should be renamed to sender and used as refund recipient)
        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), _rootChain, _rootBridgeAdaptor, payload, refundRecipient
        );

        gateway.callContract(_rootChain, _rootBridgeAdaptor, payload);
        emit MapTokenAxelarMessage(_rootChain, _rootBridgeAdaptor, payload);
    }

    /**
     * @dev This function is called by the parent `AxelarExecutable` contract to execute the payload.
     * @custom:assumes `sourceAddress_` is a 20 byte address.
     */
    function _execute(string calldata sourceChain_, string calldata sourceAddress_, bytes calldata payload_)
        internal
        override
    {
        childBridge.onMessageReceive(sourceChain_, sourceAddress_, payload_);
    }
}
