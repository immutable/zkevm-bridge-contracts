// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {WIMX as WETH} from "../../../src/child/WIMX.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {IERC20Metadata} from "../../../src/root/RootERC20Bridge.sol";

contract RootHelper is Test {
    address admin;
    RootERC20BridgeFlowRate public rootBridge;

    uint256 public totalGas;

    constructor(address _admin, address payable _rootBridge) {
        admin = _admin;
        rootBridge = RootERC20BridgeFlowRate(_rootBridge);
    }

    function deposit(address user, address rootToken, uint256 amount, uint256 gasAmt) public {
        vm.prank(user);
        ChildERC20(rootToken).approve(address(rootBridge), amount);

        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.deposit{value: gasAmt}(IERC20Metadata(rootToken), amount);
    }

    function depositTo(address user, address recipient, address rootToken, uint256 amount, uint256 gasAmt) public {
        vm.prank(user);
        ChildERC20(rootToken).approve(address(rootBridge), amount);

        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.depositTo{value: gasAmt}(IERC20Metadata(rootToken), recipient, amount);
    }

    function depositIMX(address user, uint256 amount, uint256 gasAmt) public {
        address IMX = rootBridge.rootIMXToken();

        vm.prank(user);
        ChildERC20(IMX).approve(address(rootBridge), amount);

        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.deposit{value: gasAmt}(IERC20Metadata(IMX), amount);
    }

    function depositIMXTo(address user, address recipient, uint256 amount, uint256 gasAmt) public {
        address IMX = rootBridge.rootIMXToken();

        vm.prank(user);
        ChildERC20(IMX).approve(address(rootBridge), amount);

        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.depositTo{value: gasAmt}(IERC20Metadata(IMX), recipient, amount);
    }

    function depositETH(address user, uint256 amount, uint256 gasAmt) public {
        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.depositETH{value: gasAmt + amount}(amount);
    }

    function depositETHTo(address user, address recipient, uint256 amount, uint256 gasAmt) public {
        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.depositToETH{value: gasAmt + amount}(recipient, amount);
    }

    function depositWETH(address user, uint256 amount, uint256 gasAmt) public {
        address payable wETH = payable(rootBridge.rootWETHToken());

        vm.prank(user);
        WETH(wETH).approve(address(rootBridge), amount);

        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.deposit{value: gasAmt}(IERC20Metadata(wETH), amount);
    }

    function depositWETHTo(address user, address recipient, uint256 amount, uint256 gasAmt) public {
        address payable wETH = payable(rootBridge.rootWETHToken());

        vm.prank(user);
        WETH(wETH).approve(address(rootBridge), amount);

        vm.deal(user, gasAmt + user.balance);
        totalGas += gasAmt;

        vm.prank(user);
        rootBridge.depositTo{value: gasAmt}(IERC20Metadata(wETH), recipient, amount);
    }

    function getQueueSize(address user) public view returns (uint256) {
        return rootBridge.getPendingWithdrawalsLength(user);
    }

    function finaliseWithdrawal(address user, uint256 previousLen) public {
        // Check if this withdrawal has hit rate limit
        if (rootBridge.getPendingWithdrawalsLength(user) > previousLen) {
            skip(86401);
            vm.prank(user);
            rootBridge.finaliseQueuedWithdrawal(user, previousLen);
        }

        if (rootBridge.withdrawalQueueActivated()) {
            vm.prank(admin);
            rootBridge.deactivateWithdrawalQueue();
        }
    }
}
