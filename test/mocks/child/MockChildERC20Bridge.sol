// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

contract MockChildERC20Bridge {
    function onMessageReceive(bytes calldata) external {}

    function rootERC20BridgeAdaptor() external pure returns (string memory) {
        return "rootERC20BridgeAdaptor";
    }
}
