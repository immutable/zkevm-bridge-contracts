// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

contract MockChildERC20Bridge {
    function onMessageReceive(string calldata, string calldata, bytes calldata) external {}

    function rootERC20BridgeAdaptor() external pure returns (string memory) {
        return "rootERC20BridgeAdaptor";
    }
}
