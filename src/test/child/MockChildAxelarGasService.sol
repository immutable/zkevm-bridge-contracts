// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

contract MockChildAxelarGasService {
    function payNativeGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    ) external payable {}
}
