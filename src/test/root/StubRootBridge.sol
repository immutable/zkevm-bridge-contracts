// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract StubRootBridge {
    function childBridgeAdaptor() external pure returns (string memory) {
        return Strings.toHexString(address(9999));
    }
}