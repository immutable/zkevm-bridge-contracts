// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IAxelarGateway} from "@axelar-cgp-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-cgp-solidity/contracts/interfaces/IAxelarGasService.sol";
import {IRootERC20BridgeAdaptor} from "../interfaces/root/IRootERC20BridgeAdaptor.sol";
import {
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors
} from "../interfaces/root/IRootAxelarBridgeAdaptor.sol";
import {IRootERC20Bridge} from "../interfaces/root/IRootERC20Bridge.sol";

// TODO Note: this will have to be an AxelarExecutable contract in order to receive messages from child chain

/**
 * @notice RootAxelarBridgeAdaptor is a bridge adaptor that allows the RootERC20Bridge to communicate with the Axelar Gateway.
 * @dev This is not an upgradeable contract, because it is trivial to deploy a new one if needed.
 */
contract RootAxelarBridgeAdaptor is
    Initializable,
    IRootERC20BridgeAdaptor,
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors
{
    using SafeERC20 for IERC20Metadata;

    address public rootBridge;
    string public childBridgeAdaptor;
    /// @dev childChain could be immutable, but as of writing this Solidity does not support immutable strings.
    ///      see: https://ethereum.stackexchange.com/questions/127622/typeerror-immutable-variables-cannot-have-a-non-value-type
    string public childChain;
    IAxelarGateway public axelarGateway;
    IAxelarGasService public gasService;
    mapping(uint256 => string) public chainIdToChainName;

    /**
     * @dev Always sets it to whatever the childBridgeAdaptor of the bridge contract is.
     */
    function initialize(address _rootBridge, string memory _childChain, address _axelarGateway, address _gasService)
        public
        initializer
    {
        if (_rootBridge == address(0) || _axelarGateway == address(0) || _gasService == address(0)) {
            revert ZeroAddresses();
        }

        if (bytes(_childChain).length == 0) {
            revert InvalidChildChain();
        }
        rootBridge = _rootBridge;
        childChain = _childChain;
        axelarGateway = IAxelarGateway(_axelarGateway);
        gasService = IAxelarGasService(_gasService);
        childBridgeAdaptor = IRootERC20Bridge(rootBridge).childBridgeAdaptor();
    }

    /**
     * @notice Sets the child bridge adaptor address.
     * @dev Always sets it to whatever the childBridgeAdaptor of the bridge contract is.
     */
    function setChildBridgeAdaptor() external {
        childBridgeAdaptor = IRootERC20Bridge(rootBridge).childBridgeAdaptor();
    }

    /**
     * @inheritdoc IRootERC20BridgeAdaptor
     * @notice Sends an arbitrary message to the child chain, via the Axelar network.
     */
    function sendMessage(bytes calldata payload, address refundRecipient) external payable override {
        if (msg.value == 0) {
            revert NoGas();
        }
        if (msg.sender != rootBridge) {
            revert CallerNotBridge();
        }

        // Load from storage.
        string memory _childBridgeAdaptor = childBridgeAdaptor;
        string memory _childChain = childChain;

        // TODO For `sender` (first param), should likely be refundRecipient (and in which case refundRecipient should be renamed to sender and used as refund recipient)
        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), _childChain, _childBridgeAdaptor, payload, refundRecipient
        );

        axelarGateway.callContract(_childChain, _childBridgeAdaptor, payload);
        emit MapTokenAxelarMessage(_childChain, _childBridgeAdaptor, payload);
    }
}
