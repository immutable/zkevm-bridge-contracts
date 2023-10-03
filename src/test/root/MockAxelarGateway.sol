// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.17;

// @dev A contract for ensuring the Axelar Gateway is called correctly during unit tests.
contract MockAxelarGateway {
    function callContract(string memory childChain, string memory childBridgeAdaptor, bytes memory payload) external {}
}
