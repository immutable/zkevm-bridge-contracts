// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockMessenger} from "./MockMessenger.sol";
import {MockHandler} from "./MockHandler.sol";
import "forge-std/console.sol";

contract InvariantBridge is Test {
    string public constant CHAIN_URL = "http://127.0.0.1:8500";
    address public constant ADMIN = address(0x111);

    uint256 childId;
    uint256 rootId;
    MockMessenger childMessenger;
    MockMessenger rootMessenger;
    MockHandler rootHandler;

    function setUp() public {
        // Create two forks, child chain and root chain
        childId = vm.createFork(CHAIN_URL);
        rootId = vm.createFork(CHAIN_URL);

        // Deploy messenger on child chain.
        vm.selectFork(childId);
        vm.startPrank(ADMIN);
        childMessenger = new MockMessenger(rootId);
        vm.stopPrank();

        // Deploy messenger on root chain.
        vm.selectFork(rootId);
        vm.startPrank(ADMIN);
        rootMessenger = new MockMessenger(childId);
        vm.stopPrank();

        // Send a message from root chain to child chain
        rootMessenger.sendMessage("0x1234");

        // Set target contract
        rootHandler = new MockHandler();
        bytes4[] memory rootSelectors = new bytes4[](1);
        rootSelectors[0] = rootHandler.handler.selector;
        targetSelector(FuzzSelector({addr: address(rootHandler), selectors: rootSelectors}));
        targetContract(address(rootHandler));
    }

    /// forge-config: default.invariant.runs = 1
    /// forge-config: default.invariant.depth = 5
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_test() external {
    }
}
