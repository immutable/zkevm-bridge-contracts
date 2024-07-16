// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract MockMessenger is Test {

    uint256 otherChainId;

    constructor(uint256 _otherChainId) {
        otherChainId = _otherChainId;

        uint256 currentChainId = vm.activeFork();
        if (currentChainId == otherChainId) {
            revert("This should never happen");
        }
    }

    function sendMessage(bytes calldata payload) external {
        // Get current chain.
        uint256 currentChainId = vm.activeFork();
        console.log("The current chain is", currentChainId, "other chain id is", otherChainId);
        if (currentChainId == otherChainId) {
            revert("This should never happen");
        }

        // Switch to the other chain.
        vm.selectFork(otherChainId);

        currentChainId = vm.activeFork();
        console.log("The current chain is", currentChainId, "other chain id is", otherChainId);
        if (currentChainId == otherChainId) {
            revert("This should never happen");
        }

        onMessageReceive(payload);

        // Switch back to the original chain.
        vm.selectFork(currentChainId);
    }

    function onMessageReceive(bytes calldata data) public {
    }
}