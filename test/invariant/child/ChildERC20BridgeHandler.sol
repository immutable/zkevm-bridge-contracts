// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {ChildHelper} from "./ChildHelper.sol";
import {RootHelper} from "../root/RootHelper.sol";

contract ChildERC20BridgeHandler is Test {
    uint256 public constant MAX_AMOUNT = 10000;
    uint256 public constant MAX_GAS = 100;

    uint256 childId;
    uint256 rootId;
    address[] users;
    address[] rootTokens;
    ChildHelper childHelper;
    RootHelper rootHelper;

    constructor(
        uint256 _childId,
        uint256 _rootId,
        address[] memory _users,
        address[] memory _rootTokens,
        address _childHelper,
        address _rootHelper
    ) {
        childId = _childId;
        rootId = _rootId;
        users = _users;
        rootTokens = _rootTokens;
        childHelper = ChildHelper(_childHelper);
        rootHelper = RootHelper(_rootHelper);
    }

    function initialize(
        uint256 _childId,
        uint256 _rootId,
        address[] memory _users,
        address[] memory _rootTokens,
        address _childHelper,
        address _rootHelper
    ) public {
        childId = _childId;
        rootId = _rootId;
        users = _users;
        rootTokens = _rootTokens;
        childHelper = ChildHelper(_childHelper);
        rootHelper = RootHelper(_rootHelper);
    }

    function withdraw(uint256 userIndexSeed, uint256 tokenIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to child chain
        vm.selectFork(childId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        address rootToken = rootTokens[bound(tokenIndexSeed, 0, rootTokens.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get child token
        address childToken = childHelper.childBridge().rootTokenToChildToken(rootToken);

        // Get current balance
        uint256 currentBalance = ChildERC20(childToken).balanceOf(user);

        if (currentBalance < amount) {
            // Deposit difference
            vm.selectFork(rootId);
            rootHelper.deposit(user, rootToken, amount - currentBalance, gasAmt);
            vm.selectFork(childId);
        }

        vm.selectFork(rootId);
        uint256 previousLen = rootHelper.getQueueSize(user);
        vm.selectFork(childId);

        childHelper.withdraw(user, childToken, amount, gasAmt);

        vm.selectFork(rootId);
        rootHelper.finaliseWithdrawal(user, previousLen);
        vm.selectFork(childId);

        vm.selectFork(original);
    }
}
