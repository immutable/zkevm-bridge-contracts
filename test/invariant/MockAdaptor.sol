// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IChildBridgeAdaptor} from "../../src/interfaces/child/IChildBridgeAdaptor.sol";
import {IRootBridgeAdaptor} from "../../src/interfaces/root/IRootBridgeAdaptor.sol";
import "forge-std/console.sol";

interface MessageReceiver {
    function onMessageReceive(bytes calldata data) external;
}

contract MockAdaptor is Test, IChildBridgeAdaptor, IRootBridgeAdaptor {
    uint256 otherChainId;
    MessageReceiver messageReceiver;

    constructor() {}

    function initialize(uint256 _otherChainId, address _messageReceiver) public {
        otherChainId = _otherChainId;
        messageReceiver = MessageReceiver(_messageReceiver);
    }

    function sendMessage(bytes calldata payload, address /*refundRecipient*/ )
        external
        payable
        override(IChildBridgeAdaptor, IRootBridgeAdaptor)
    {
        uint256 original = vm.activeFork();

        // Switch to the other chain.
        vm.selectFork(otherChainId);
        console.log(""); // <= Bug
        onMessageReceive(payload);
        
        vm.selectFork(original);
    }

    function onMessageReceive(bytes calldata data) public {
        messageReceiver.onMessageReceive(data);
    }
}