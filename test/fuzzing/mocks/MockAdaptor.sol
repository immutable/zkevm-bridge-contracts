// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {IChildBridgeAdaptor} from "../../../src/interfaces/child/IChildBridgeAdaptor.sol";
import {IRootBridgeAdaptor} from "../../../src/interfaces/root/IRootBridgeAdaptor.sol";

import {LibLog} from "@perimetersec/fuzzlib/src/libraries/LibLog.sol";

interface MessageReceiver {
    function onMessageReceive(bytes calldata data) external;
}

contract MockAdaptor is IChildBridgeAdaptor, IRootBridgeAdaptor {
    uint256 otherChainId;
    MessageReceiver bridge;

    constructor() {}

    function initialize(address _bridge) public {
        bridge = MessageReceiver(_bridge);
    }

    function sendMessage(bytes calldata payload, address /*refundRecipient*/ )
        external
        payable
        override(IChildBridgeAdaptor, IRootBridgeAdaptor)
    {}

    function onMessageReceive(bytes calldata data) public {
        bridge.onMessageReceive(data);
    }
}
