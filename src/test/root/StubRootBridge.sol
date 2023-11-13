// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract StubRootBridge {
    function childBridgeAdaptor() external pure returns (string memory) {
        return Strings.toHexString(address(9999));
    }

    function onMessageReceive(string calldata, string calldata, bytes calldata) external {}
}
