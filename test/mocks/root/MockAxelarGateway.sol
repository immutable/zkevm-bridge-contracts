// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

// @dev A contract for ensuring the Axelar Gateway is called correctly during unit tests.
contract MockAxelarGateway {
    function callContract(string memory childChain, string memory childBridgeAdaptor, bytes memory payload) external {}

    function validateContractCall(bytes32, string calldata, string calldata, bytes32) external pure returns (bool) {
        return true;
    }
}
