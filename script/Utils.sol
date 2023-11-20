// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {AddressToString} from "@axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";

library Utils {
    function getChecksumInputs(address addr) internal pure returns (string[] memory) {
        string[] memory checksumInputs = new string[](2);
        checksumInputs[0] = "./toChecksummedSolidity.sh";
        checksumInputs[1] = AddressToString.toString(addr);
        return checksumInputs;
    }

    function removeZeroByteValues(bytes memory input) internal pure returns (bytes memory) {
        uint256 length = 42; // Address strings are len 42 (including "0x")
        uint256 numberOfZeroes = 0;
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            if (input[i] == 0) {
                numberOfZeroes++;
            }
            result[i] = input[i + numberOfZeroes];
        }

        return result;
    }
}
