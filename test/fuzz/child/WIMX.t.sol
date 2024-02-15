// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {WIMX} from "../../../src/child/WIMX.sol";

contract WIMXTest is Test {
    WIMX public wIMX;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function setUp() public {
        wIMX = new WIMX();
    }

    function testFuzz_Deposit(uint256 depositAmt) public {
        // Create a user and fund it
        address user = address(1234);
        vm.deal(user, depositAmt);
        vm.startPrank(user);

        // Before deposit
        assertEq(user.balance, depositAmt, "User should have given depositAmt of IMX");
        assertEq(wIMX.balanceOf(user), 0, "User should have 0 wIMX");
        assertEq(wIMX.totalSupply(), 0, "Total supply should be 0");

        if (depositAmt != type(uint256).max) {
            vm.expectRevert();
            wIMX.deposit{value: depositAmt + 1}();
        }

        // Deposit
        vm.expectEmit(address(wIMX));
        emit Deposit(user, depositAmt);
        wIMX.deposit{value: depositAmt}();

        // After deposit
        assertEq(user.balance, 0, "User should have 0 of IMX");
        assertEq(wIMX.balanceOf(user), depositAmt, "User should have given depositAmt wIMX");
        assertEq(wIMX.totalSupply(), depositAmt, "Total supply should be given depositAmt");

        vm.stopPrank();
    }

    function testFuzz_Withdraw(uint256 depositAmt, uint256 withdrawAmt) public {
        vm.assume(depositAmt >= withdrawAmt);

        // Create a user and fund it
        address user = address(1234);
        vm.deal(user, depositAmt);
        vm.startPrank(user);

        // Deposit
        wIMX.deposit{value: depositAmt}();

        assertEq(wIMX.totalSupply(), depositAmt, "Total supply should be given depositAmt");

        // Withdraw more than depositAmt
        if (depositAmt != type(uint256).max) {
            vm.expectRevert("Wrapped IMX: Insufficient balance");
            wIMX.withdraw(depositAmt + 1);
        }

        vm.expectEmit(address(wIMX));
        emit Withdrawal(user, withdrawAmt);
        wIMX.withdraw(withdrawAmt);

        assertEq(user.balance, withdrawAmt, "User should have withdrawAmt of IMX");
        assertEq(wIMX.balanceOf(user), depositAmt - withdrawAmt, "User should have depositAmt - withdrawAmt wIMX");
        assertEq(wIMX.totalSupply(), depositAmt - withdrawAmt, "Total supply should be depositAmt - withdrawAmt");

        vm.stopPrank();
    }

    function testFuzz_Approve(address user, address approved, uint256 approvalAmt) public {
        vm.startPrank(user);

        // Approve
        vm.expectEmit(address(wIMX));
        emit Approval(user, approved, approvalAmt);
        wIMX.approve(approved, approvalAmt);

        assertEq(wIMX.allowance(user, approved), approvalAmt, "Allowance should be given approvalAmt");

        vm.stopPrank();
    }

    function testFuzz_Transfer(address from, address to, uint256 depositAmt, uint256 transferAmt) public {
        vm.assume(depositAmt >= transferAmt);
        vm.assume(from != to);

        // Fund sender
        vm.deal(from, depositAmt);
        vm.startPrank(from);

        // Deposit
        wIMX.deposit{value: depositAmt}();

        // Transfer out of balance
        if (depositAmt != type(uint256).max) {
            vm.expectRevert("Wrapped IMX: Insufficient balance");
            wIMX.transfer(to, depositAmt + 1);
        }

        vm.expectEmit(address(wIMX));
        emit Transfer(from, to, transferAmt);
        wIMX.transfer(to, transferAmt);

        assertEq(wIMX.balanceOf(from), depositAmt - transferAmt, "Sender should have depositAmt - transferAmt of IMX");
        assertEq(wIMX.balanceOf(to), transferAmt, "User should have transferAmt wIMX");
        assertEq(wIMX.totalSupply(), depositAmt, "Total supply should be depositAmt");

        vm.stopPrank();
    }

    function testFuzz_TransferFrom(address from, address to, address operator, uint256 depositAmt, uint256 transferAmt)
        public
    {
        vm.assume(depositAmt != type(uint256).max && depositAmt >= transferAmt && transferAmt > 1);
        vm.assume(from != to && from != operator && to != operator);

        // Fund sender
        vm.deal(from, depositAmt);
        vm.startPrank(from);

        // Deposit
        wIMX.deposit{value: depositAmt}();

        // Insufficient allowance
        wIMX.approve(operator, transferAmt - 1);

        // Transfer
        vm.startPrank(operator);

        vm.expectRevert("Wrapped IMX: Insufficient allowance");
        wIMX.transferFrom(from, to, transferAmt);

        // Approve sufficient amount
        vm.startPrank(from);
        wIMX.approve(operator, depositAmt);

        vm.startPrank(operator);
        vm.expectEmit(address(wIMX));
        emit Transfer(from, to, transferAmt);
        wIMX.transferFrom(from, to, transferAmt);

        assertEq(wIMX.balanceOf(from), depositAmt - transferAmt, "Sender should have depositAmt - transferAmt of IMX");
        assertEq(wIMX.balanceOf(to), transferAmt, "User should have transferAmt wIMX");
        assertEq(wIMX.totalSupply(), depositAmt, "Total supply should be depositAmt");
        assertEq(
            wIMX.allowance(from, operator),
            depositAmt - transferAmt,
            "Allowance should have depositAmt - transferAmt of IMX"
        );

        vm.stopPrank();
    }
}
