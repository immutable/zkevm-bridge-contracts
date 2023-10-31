// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IChildERC20Bridge} from "../interfaces/child/IChildERC20Bridge.sol";
import {IChildAxelarBridgeAdaptorErrors} from "../interfaces/child/IChildAxelarBridgeAdaptor.sol";

contract ChildAxelarBridgeAdaptor is AxelarExecutable, Initializable, IChildAxelarBridgeAdaptorErrors {
    /// @notice Address of bridge to relay messages to.
    IChildERC20Bridge public childBridge;
    string public rootBridgeAdaptor;

    constructor(address _gateway) AxelarExecutable(_gateway) {}

    /**
     * @notice Initializes the contract.
     * @param _childBridge Address of the child bridge contract.
     * @dev Always sets the rootBridgeAdaptor to whatever the rootERC20BridgeAdaptor of the bridge contract is.
     */
    function initialize(address _childBridge) external initializer {
        if (_childBridge == address(0)) {
            revert ZeroAddress();
        }

        childBridge = IChildERC20Bridge(_childBridge);
        rootBridgeAdaptor = childBridge.rootERC20BridgeAdaptor();
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
