// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {WIMX} from "../src/WIMX.sol";

contract WIMXTest is Test {
    string constant DEFAULT_WIMX_NAME = "Wrapped IMX";
    string constant DEFAULT_WIMX_SYMBOL = "WIMX";

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    WIMX public wIMX;

    function setUp() public {
        wIMX = new WIMX();
    }

    function test_InitialState() public {
        assertEq(wIMX.name(), DEFAULT_WIMX_NAME, "Incorrect token name");
        assertEq(wIMX.symbol(), DEFAULT_WIMX_SYMBOL, "Incorrect token symbol");
        assertEq(wIMX.totalSupply(), 0, "Incorrect token supply");
    }

    function test_RevertIf_DepositWithInsufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        
        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, 1 ether, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        vm.prank(user);
        // Deposit should revert because user has only 1 IMX
        vm.expectRevert();
        wIMX.deposit{value: 2 ether}();

        // After deposit, user should have 0 wIMX
        assertEq(user.balance, 1 ether, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");
    }

    function test_RevertIf_TransferWithInsufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        
        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, 1 ether, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        vm.prank(user);
        // Deposit should revert because user has only 1 IMX
        vm.expectRevert();
        address(wIMX).call{value: 2 ether}("");
        
        // After deposit, user should have 0 wIMX
        assertEq(user.balance, 1 ether, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");
    }

    function test_SucceedIf_DepositWithSufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        
        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, 1 ether, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        vm.prank(user);
        vm.expectEmit(address(wIMX));
        emit Deposit(user, 0.1 ether);
        wIMX.deposit{value: 0.1 ether}();

        // After deposit, user should have 0.1 wIMX
        assertEq(user.balance, 0.9 ether, "User should have 0.9 IMX");
        assertEq(wIMX.balanceOf(user), 0.1 ether, "User should have 0.1 wIMX");
    }

    function test_SucceedIf_TransferWithSufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        
        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, 1 ether, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        vm.prank(user);
        vm.expectEmit(address(wIMX));
        emit Deposit(user, 0.1 ether);
        address(wIMX).call{value: 0.1 ether}("");
        
        // After deposit, user should have 0.1 wIMX
        assertEq(user.balance, 0.9 ether, "User should have 0.9 wIMX");
        assertEq(wIMX.balanceOf(user), 0.1 ether, "User should have 0.1 IMX");
    }

    function test_RevertIf_OverWithdraw() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        // Try withdraw 0.2 wIMX
        vm.expectRevert();
        wIMX.withdraw(0.2 ether);
        vm.stopPrank();

        // User should still have 0.1 wIMX and 0.9 IMX
        assertEq(user.balance, 0.9 ether, "User should have 0.9 IMX");
        assertEq(wIMX.balanceOf(user), 0.1 ether, "User should have 0.1 wIMX");
    }

    function test_SucceedIf_WithdrawWithinLimit() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        // Try withdraw 0.05 wIMX
        vm.expectEmit(address(wIMX));
        emit Withdrawal(user, 0.05 ether);
        wIMX.withdraw(0.05 ether);
        vm.stopPrank();

        // User should have 0.05 wIMX and 0.95 IMX
        assertEq(user.balance, 0.95 ether, "User should have 0.95 IMX");
        assertEq(wIMX.balanceOf(user), 0.05 ether, "User should have 0.05 wIMX");
    }

    function test_SupplyUpdated_OnDepositAndWithdraw() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);

        assertEq(wIMX.totalSupply(), 0, "Token supply should be 0 at start");

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();
        assertEq(wIMX.totalSupply(), 0.1 ether, "Token supply should be 0.1 after deposit");

        // Withdraw 0.05 IMX
        wIMX.withdraw(0.05 ether);
        assertEq(wIMX.totalSupply(), 0.05 ether, "Token supply should be 0.05 after withdraw");

        vm.stopPrank();

        // Create another user and fund it with 1 IMX
        address user2 = address(1235);
        vm.deal(user2, 1 ether);

        // Deposit 0.5 IMX
        vm.startPrank(user2);
        wIMX.deposit{value: 0.5 ether}();
        assertEq(wIMX.totalSupply(), 0.55 ether, "Token supply should be 0.55 after 2nd deposit");

        // Withdraw 0.5 IMX
        vm.startPrank(user2);
        wIMX.withdraw(0.5 ether);
        assertEq(wIMX.totalSupply(), 0.05 ether, "Token supply should be 0.05 after 2nd withdraw");
    }

    function test_RevertIf_TransferAmountExceedingBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a recipient
        address recipient = address(1235);

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        // Transfer 0.2 wIMX to recipient should revert
        vm.expectRevert();
        wIMX.transfer(recipient, 0.2 ether);

        vm.stopPrank();
    }

    function test_SucceedIf_TransferAmountWithinBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a recipient
        address recipient = address(1235);

        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");
        assertEq(wIMX.balanceOf(recipient), 0, "Recipient should have 0 wIMX");

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        assertEq(wIMX.balanceOf(user), 0.1 ether, "User should have 0.1 wIMX");
        assertEq(wIMX.balanceOf(recipient), 0, "Recipient should have 0 wIMX");

        // Transfer 0.05 wIMX to recipient should revert
        vm.expectEmit(address(wIMX));
        emit Transfer(user, recipient, 0.05 ether);
        wIMX.transfer(recipient, 0.05 ether);
        
        vm.stopPrank();

        assertEq(wIMX.balanceOf(user), 0.05 ether, "User should have 0.05 wIMX");
        assertEq(wIMX.balanceOf(recipient), 0.05 ether, "Recipient should have 0.05 wIMX");
    }

    function test_RevertIf_TransferFromWithNoAllowance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a second user
        address user2 = address(1235);

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        vm.stopPrank();
        vm.startPrank(user2);

        // Second user tries to transfer from
        vm.expectRevert();
        wIMX.transferFrom(user, user2, 0.1 ether);

        vm.stopPrank();
    }

    function test_RevertIf_TransferFromWithInsufficientAllowance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a second user
        address user2 = address(1235);

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        // Allow second user
        vm.expectEmit(address(wIMX));
        emit Approval(user, user2, 0.05 ether);
        wIMX.approve(user2, 0.05 ether);

        vm.stopPrank();
        vm.startPrank(user2);

        // Second user tries to transfer from
        vm.expectRevert();
        wIMX.transferFrom(user, user2, 0.1 ether);

        vm.stopPrank();
    }

    function test_RevertIf_TransferFromWithInsufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a second user
        address user2 = address(1235);

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        // Allow second user
        vm.expectEmit(address(wIMX));
        emit Approval(user, user2, 0.2 ether);
        wIMX.approve(user2, 0.2 ether);

        vm.stopPrank();
        vm.startPrank(user2);

        // Second user tries to transfer from
        vm.expectRevert();
        wIMX.transferFrom(user, user2, 0.2 ether);

        vm.stopPrank();
    }

    function test_SucceedIf_TransferFromWithinAllowanceAndBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a second user
        address user2 = address(1235);

        // Deposit 0.1 IMX
        vm.startPrank(user);
        wIMX.deposit{value: 0.1 ether}();

        // Allow second user
        vm.expectEmit(address(wIMX));
        emit Approval(user, user2, 0.1 ether);
        wIMX.approve(user2, 0.1 ether);

        vm.stopPrank();
        vm.startPrank(user2);

        // Second user tries to transfer from
        vm.expectEmit(address(wIMX));
        emit Transfer(user, user2, 0.1 ether);
        wIMX.transferFrom(user, user2, 0.1 ether);

        vm.stopPrank();
    }
}