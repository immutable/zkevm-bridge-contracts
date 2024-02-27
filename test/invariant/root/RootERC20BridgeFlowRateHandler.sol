// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {ChildHelper} from "../child/ChildHelper.sol";
import {RootHelper} from "./RootHelper.sol";
import {WIMX as WETH} from "../../../src/child/WIMX.sol";

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
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdraw(user, childToken, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
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
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdraw(user, childToken, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }

        rootHelper.depositTo(user, recipient, rootToken, amount, gasAmt);

        // If recipient is different, transfer back
        if (user != recipient) {
            vm.selectFork(childId);
            vm.prank(recipient);
            ChildERC20(childToken).transfer(user, amount);
            vm.selectFork(rootId);
        }

        vm.selectFork(original);
    }

    function depositIMX(uint256 userIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get current balance
        uint256 currentBalance = ChildERC20(rootHelper.rootBridge().rootIMXToken()).balanceOf(user);

        if (currentBalance < amount) {
            // Fund difference
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdrawIMX(user, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }

        rootHelper.depositIMX(user, amount, gasAmt);

        vm.selectFork(original);
    }

    function depositIMXTo(uint256 userIndexSeed, uint256 recipientIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        address recipient = users[bound(recipientIndexSeed, 0, users.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get current balance
        uint256 currentBalance = ChildERC20(rootHelper.rootBridge().rootIMXToken()).balanceOf(user);

        if (currentBalance < amount) {
            // Fund difference
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdrawIMX(user, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }

        rootHelper.depositIMXTo(user, recipient, amount, gasAmt);

        // If recipient is different, transfer back
        if (user != recipient) {
            vm.selectFork(childId);
            vm.prank(recipient);
            user.call{value: amount}("");
            vm.selectFork(rootId);
        }

        vm.selectFork(original);
    }

    function depositETH(uint256 userIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get current balance
        uint256 currentBalance = user.balance;

        if (currentBalance < amount) {
            // Fund difference
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdrawETH(user, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }

        rootHelper.depositETH(user, amount, gasAmt);

        vm.selectFork(original);
    }

    function depositETHTo(uint256 userIndexSeed, uint256 recipientIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        address recipient = users[bound(recipientIndexSeed, 0, users.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get current balance
        uint256 currentBalance = user.balance;

        if (currentBalance < amount) {
            // Fund difference
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdrawETH(user, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }

        rootHelper.depositETHTo(user, recipient, amount, gasAmt);

        // If recipient is different, transfer back
        if (user != recipient) {
            vm.selectFork(childId);
            address eth = childHelper.childBridge().childETHToken();
            vm.prank(recipient);
            ChildERC20(eth).transfer(user, amount);
        }
        vm.selectFork(childId);

        vm.selectFork(original);
    }

    function depositWETH(uint256 userIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get current balance
        uint256 currentBalance = user.balance;

        if (currentBalance < amount) {
            // Fund difference
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdrawETH(user, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }

        // Wrap ETH
        address payable wETH = payable(rootHelper.rootBridge().rootWETHToken());
        vm.prank(user);
        WETH(wETH).deposit{value: amount}();

        rootHelper.depositWETH(user, amount, gasAmt);

        vm.selectFork(original);
    }

    function depositWETHTo(uint256 userIndexSeed, uint256 recipientIndexSeed, uint256 amount, uint256 gasAmt) public {
        uint256 original = vm.activeFork();

        // Switch to root chain
        vm.selectFork(rootId);

        // Bound
        address user = users[bound(userIndexSeed, 0, users.length - 1)];
        address recipient = users[bound(recipientIndexSeed, 0, users.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);
        gasAmt = bound(gasAmt, 1, MAX_GAS);

        // Get current balance
        uint256 currentBalance = user.balance;

        if (currentBalance < amount) {
            // Fund difference
            uint256 previousLen = rootHelper.getQueueSize(user);
            vm.selectFork(childId);
            childHelper.withdrawETH(user, amount - currentBalance, gasAmt);
            vm.selectFork(rootId);
            rootHelper.finaliseWithdrawal(user, previousLen);
        }

        // Wrap ETH
        address payable wETH = payable(rootHelper.rootBridge().rootWETHToken());
        vm.prank(user);
        WETH(wETH).deposit{value: amount}();

        rootHelper.depositWETHTo(user, recipient, amount, gasAmt);

        // If recipient is different, transfer back
        if (user != recipient) {
            vm.selectFork(childId);
            address eth = childHelper.childBridge().childETHToken();
            vm.prank(recipient);
            ChildERC20(eth).transfer(user, amount);
            vm.selectFork(rootId);
        }

        vm.selectFork(original);
    }
}
