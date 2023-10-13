// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {WIMX} from "../../../src/child/WIMX.sol";

contract WIMXTest is Test {
    string constant DEFAULT_WIMX_NAME = "Wrapped IMX";
    string constant DEFAULT_WIMX_SYMBOL = "WIMX";

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

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
        uint256 imxAmt = 1 ether;
        vm.deal(user, imxAmt);

        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, imxAmt, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        vm.prank(user);
        // Deposit should revert because user has only 1 IMX
        vm.expectRevert();
        wIMX.deposit{value: imxAmt + 1}();

        // After deposit, user should have 0 wIMX
        assertEq(user.balance, imxAmt, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");
    }

    function test_RevertIf_TransferWithInsufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        uint256 imxAmt = 1 ether;
        vm.deal(user, imxAmt);

        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, imxAmt, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        vm.prank(user);
        // Deposit should revert because user has only 1 IMX
        vm.expectRevert();
        (bool success,) = address(wIMX).call{value: imxAmt + 1}("");
        require(success);

        // After deposit, user should have 0 wIMX
        assertEq(user.balance, imxAmt, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");
    }

    function test_SucceedIf_DepositWithSufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        uint256 imxAmt = 1 ether;
        vm.deal(user, imxAmt);

        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, imxAmt, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        uint256 depositAmt = 0.1 ether;
        vm.prank(user);
        vm.expectEmit(address(wIMX));
        emit Deposit(user, depositAmt);
        wIMX.deposit{value: depositAmt}();

        // After deposit, user should have 0.1 wIMX
        assertEq(user.balance, imxAmt - depositAmt, "User should have 0.9 IMX");
        assertEq(wIMX.balanceOf(user), depositAmt, "User should have 0.1 wIMX");
    }

    function test_SucceedIf_TransferWithSufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        uint256 imxAmt = 1 ether;
        vm.deal(user, imxAmt);

        // Before deposit, user should have 0 wIMX
        assertEq(user.balance, imxAmt, "User should have 1 IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");

        uint256 depositAmt = 0.1 ether;
        vm.prank(user);
        vm.expectEmit(address(wIMX));
        emit Deposit(user, depositAmt);
        (bool success,) = address(wIMX).call{value: depositAmt}("");
        require(success);

        // After deposit, user should have 0.1 wIMX
        assertEq(user.balance, imxAmt - depositAmt, "User should have 0.9 wIMX");
        assertEq(wIMX.balanceOf(user), depositAmt, "User should have 0.1 IMX");
    }

    function test_RevertIf_OverWithdraw() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        uint256 imxAmt = 1 ether;
        vm.deal(user, imxAmt);

        // Deposit 0.1 IMX
        uint256 depositAmt = 0.1 ether;
        vm.startPrank(user);
        wIMX.deposit{value: depositAmt}();

        // Try withdraw 0.2 wIMX
        uint256 withdrawlAmt = 0.2 ether;
        vm.expectRevert();
        wIMX.withdraw(withdrawlAmt);
        vm.stopPrank();

        // User should still have 0.1 wIMX and 0.9 IMX
        assertEq(user.balance, imxAmt - depositAmt, "User should have 0.9 IMX");
        assertEq(wIMX.balanceOf(user), depositAmt, "User should have 0.1 wIMX");
    }

    function test_SucceedIf_WithdrawWithinLimit() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        uint256 imxAmt = 1 ether;
        vm.deal(user, imxAmt);

        // Deposit 0.1 IMX
        uint256 depositAmt = 0.1 ether;
        vm.startPrank(user);
        wIMX.deposit{value: depositAmt}();

        // Try withdraw 0.05 wIMX
        uint256 withdrawlAmt = 0.05 ether;
        vm.expectEmit(address(wIMX));
        emit Withdrawal(user, withdrawlAmt);
        wIMX.withdraw(withdrawlAmt);
        vm.stopPrank();

        // User should have 0.05 wIMX and 0.95 IMX
        assertEq(user.balance, imxAmt - depositAmt + withdrawlAmt, "User should have 0.95 IMX");
        assertEq(wIMX.balanceOf(user), depositAmt - withdrawlAmt, "User should have 0.05 wIMX");
    }

    function test_SupplyUpdated_OnDepositAndWithdraw() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        uint256 imxAmt = 1 ether;
        vm.deal(user, imxAmt);

        assertEq(wIMX.totalSupply(), 0, "Token supply should be 0 at start");

        // Deposit 0.1 IMX
        uint256 depositAmt1 = 0.1 ether;
        vm.startPrank(user);
        wIMX.deposit{value: depositAmt1}();
        assertEq(wIMX.totalSupply(), depositAmt1, "Token supply should be 0.1 after deposit");

        // Withdraw 0.05 IMX
        uint256 withdrawlAmt1 = 0.05 ether;
        wIMX.withdraw(withdrawlAmt1);
        assertEq(wIMX.totalSupply(), depositAmt1 - withdrawlAmt1, "Token supply should be 0.05 after withdraw");

        vm.stopPrank();

        // Create another user and fund it with 1 IMX
        address user2 = address(1235);
        vm.deal(user2, imxAmt);

        // Deposit 0.5 IMX
        uint256 depositAmt2 = 0.5 ether;
        vm.startPrank(user2);
        wIMX.deposit{value: depositAmt2}();
        assertEq(
            wIMX.totalSupply(),
            depositAmt1 - withdrawlAmt1 + depositAmt2,
            "Token supply should be 0.55 after 2nd deposit"
        );

        // Withdraw 0.5 IMX
        uint256 withdrawlAmt2 = 0.5 ether;
        vm.startPrank(user2);
        wIMX.withdraw(withdrawlAmt2);
        assertEq(
            wIMX.totalSupply(),
            depositAmt1 - withdrawlAmt1 + depositAmt2 - withdrawlAmt2,
            "Token supply should be 0.05 after 2nd withdraw"
        );
    }

    function test_RevertIf_TransferAmountExceedingBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a recipient
        address recipient = address(1235);

        // Deposit 0.1 IMX
        uint256 depositAmt = 0.1 ether;
        vm.startPrank(user);
        wIMX.deposit{value: depositAmt}();

        // Transfer 0.2 wIMX to recipient should revert
        vm.expectRevert();
        wIMX.transfer(recipient, depositAmt + 1);

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
        uint256 depositAmt = 0.1 ether;
        vm.startPrank(user);
        wIMX.deposit{value: depositAmt}();

        assertEq(wIMX.balanceOf(user), depositAmt, "User should have 0.1 wIMX");
        assertEq(wIMX.balanceOf(recipient), 0, "Recipient should have 0 wIMX");

        // Transfer 0.05 wIMX to recipient should revert
        uint256 transferredAmt = 0.05 ether;
        vm.expectEmit(address(wIMX));
        emit Transfer(user, recipient, transferredAmt);
        wIMX.transfer(recipient, transferredAmt);

        vm.stopPrank();

        assertEq(wIMX.balanceOf(user), depositAmt - transferredAmt, "User should have 0.05 wIMX");
        assertEq(wIMX.balanceOf(recipient), transferredAmt, "Recipient should have 0.05 wIMX");
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
        uint256 approvedAmt = 0.05 ether;
        vm.expectEmit(address(wIMX));
        emit Approval(user, user2, approvedAmt);
        wIMX.approve(user2, approvedAmt);

        vm.stopPrank();
        vm.startPrank(user2);

        // Second user tries to transfer from
        vm.expectRevert();
        wIMX.transferFrom(user, user2, approvedAmt + 1);

        vm.stopPrank();
    }

    function test_RevertIf_TransferFromWithInsufficientBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a second user
        address user2 = address(1235);

        // Deposit 0.1 IMX
        uint256 depositAmt = 0.1 ether;
        vm.startPrank(user);
        wIMX.deposit{value: depositAmt}();

        // Allow second user
        vm.expectEmit(address(wIMX));
        emit Approval(user, user2, depositAmt + 1);
        wIMX.approve(user2, depositAmt + 1);

        vm.stopPrank();
        vm.startPrank(user2);

        // Second user tries to transfer from
        vm.expectRevert();
        wIMX.transferFrom(user, user2, depositAmt + 1);

        vm.stopPrank();
    }

    function test_SucceedIf_TransferFromWithinAllowanceAndBalance() public {
        // Create a user and fund it with 1 IMX
        address user = address(1234);
        vm.deal(user, 1 ether);
        // Create a second user
        address user2 = address(1235);

        // Deposit 0.1 IMX
        uint256 depositAmt = 0.1 ether;
        vm.startPrank(user);
        wIMX.deposit{value: depositAmt}();

        // Allow second user
        vm.expectEmit(address(wIMX));
        emit Approval(user, user2, depositAmt);
        wIMX.approve(user2, depositAmt);

        vm.stopPrank();
        vm.startPrank(user2);

        // Second user tries to transfer from
        uint256 transferredAmt = 0.1 ether;
        vm.expectEmit(address(wIMX));
        emit Transfer(user, user2, transferredAmt);
        wIMX.transferFrom(user, user2, transferredAmt);

        vm.stopPrank();

        assertEq(wIMX.balanceOf(user), depositAmt - transferredAmt, "User should have 0 wIMX");
        assertEq(wIMX.balanceOf(user2), transferredAmt, "Recipient should have 0.05 wIMX");
    }
}
