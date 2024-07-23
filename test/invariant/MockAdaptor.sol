// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IChildBridgeAdaptor} from "../../src/interfaces/child/IChildBridgeAdaptor.sol";
import {IRootBridgeAdaptor} from "../../src/interfaces/root/IRootBridgeAdaptor.sol";
import {IChainManager} from "./IChainManager.sol";

interface MessageReceiver {
    function onMessageReceive(bytes calldata data) external;
}

contract MockAdaptor is Test, IChildBridgeAdaptor, IRootBridgeAdaptor {
    uint256 otherChainId;
    MessageReceiver messageReceiver;
    IChainManager chainManager;

    constructor() {}

    function initialize(uint256 _otherChainId, address _messageReceiver, address _chainManager) public {
        otherChainId = _otherChainId;
        messageReceiver = MessageReceiver(_messageReceiver);
        chainManager = IChainManager(_chainManager);
    }

    function sendMessage(bytes calldata payload, address /*refundRecipient*/ )
        external
        payable
        override(IChildBridgeAdaptor, IRootBridgeAdaptor)
    {
        uint256 original = vm.activeFork();

        // Switch to the other chain.
        chainManager.switchToChain(otherChainId);
        onMessageReceive(payload);

        chainManager.switchToChain(original);
    }

    function onMessageReceive(bytes calldata data) public {
        messageReceiver.onMessageReceive(data);
    }
}
