// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";

contract ChildERC20Test is Test {
    ChildERC20 public childToken;

    address constant DEFAULT_ROOT_ADDRESS = address(111);
    string constant DEFAULT_NAME = "Test ERC20";
    string constant DEFAULT_SYMBOL = "TEST";
    uint8 constant DEFAULT_DECIMALS = 18;

    function setUp() public {
        childToken = new ChildERC20();
        childToken.initialize(DEFAULT_ROOT_ADDRESS, DEFAULT_NAME, DEFAULT_SYMBOL, DEFAULT_DECIMALS);
    }

    function testFuzz_Mint(address user, uint256 amount) public {
        vm.assume(user != address(0));

        assertEq(childToken.balanceOf(user), 0, "User should not have balance before mint");

        // Unauthorised mint should revert
        vm.prank(user);
        vm.expectRevert("ChildERC20: Only bridge can call");
        childToken.mint(user, amount);

        childToken.mint(user, amount);
        assertEq(childToken.balanceOf(user), amount, "User should have given amount of balance after mint");
    }

    function testFuzz_Burn(address user, uint256 balance, uint256 burnAmt) public {
        vm.assume(user != address(0));
        vm.assume(balance < type(uint256).max);
        vm.assume(burnAmt < balance);

        childToken.mint(user, balance);
        assertEq(childToken.balanceOf(user), balance, "User should have given amount of balance before burn");

        // Unauthorised burn should revert
        vm.prank(user);
        vm.expectRevert("ChildERC20: Only bridge can call");
        childToken.burn(user, burnAmt);

        // Over burn should revert
        vm.expectRevert("ERC20: burn amount exceeds balance");
        childToken.burn(user, balance + 1);

        // Burn should decrease balance
        childToken.burn(user, burnAmt);
        assertEq(childToken.balanceOf(user), balance - burnAmt, "User should have balance - burnAmt after burn");
    }
}
