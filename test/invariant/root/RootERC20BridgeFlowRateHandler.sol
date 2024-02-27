// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {ChildHelper} from "../child/ChildHelper.sol";
import {RootHelper} from "./RootHelper.sol";

contract RootERC20BridgeFlowRateHandler is Test {
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

    function deposit(uint256 userIndexSeed, uint256 tokenIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        address rootToken = rootTokens[bound(tokenIndexSeed, 0, rootTokens.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get child token
        address childToken = rootHelper.rootBridge().rootTokenToChildToken(rootToken);

        // Get current balance
        uint256 currentBalance = ChildERC20(rootToken).balanceOf(user);

        if (currentBalance < amount) {
            // Fund difference
            fund(userIndexSeed, rootToken, childToken, amount - currentBalance);
        }

        rootHelper.deposit(user, rootToken, amount, gasAmt);

        vm.selectFork(original);
    }

    function depositTo(
        uint256 userIndexSeed,
        uint256 recipientIndexSeed,
        uint256 tokenIndexSeed,
        uint256 amount,
        uint256 gasAmt
    ) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        address recipient = users[bound(recipientIndexSeed, 0, users.length - 1)];
        address rootToken = rootTokens[bound(tokenIndexSeed, 0, rootTokens.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get child token
        address childToken = rootHelper.rootBridge().rootTokenToChildToken(rootToken);

        // Get current balance
        uint256 currentBalance = ChildERC20(rootToken).balanceOf(user);

        if (currentBalance < amount) {
            // Fund difference
            fund(userIndexSeed, rootToken, childToken, amount - currentBalance);
        }

        rootHelper.depositTo(user, recipient, rootToken, amount, gasAmt);

        vm.selectFork(original);
    }

    function fund(uint256 userIndexSeed, address rootToken, address childToken, uint256 diff) public {
        uint256 offset = bound(userIndexSeed, 0, users.length - 1);
        address user = users[offset];
        address from = findFrom(offset, rootToken, diff);
        if (from != address(0)) {
            vm.prank(from);
            ChildERC20(rootToken).transfer(user, diff);
        } else {
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            from = findFrom(offset, childToken, diff);
            childHelper.withdrawTo(from, user, childToken, diff, 1);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }
    }

    function findFrom(uint256 offset, address token, uint256 requiredAmt) public view returns (address from) {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 index = i + offset;
            if (index >= users.length) {
                index -= users.length;
            }
            if (ChildERC20(token).balanceOf(users[index]) >= requiredAmt) {
                from = users[index];
                break;
            }
        }
    }
}
