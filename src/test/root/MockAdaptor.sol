// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

// @dev A contract for ensuring the Axelar Bridge Adaptor is called correctly during unit tests.
contract MockAdaptor {
    function sendMessage(bytes calldata, address) external payable {}
}
