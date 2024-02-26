// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {ChildERC20Bridge} from "../../../src/child/ChildERC20Bridge.sol";
import {IChildERC20} from "../../../src/interfaces/child/IChildERC20.sol";

contract ChildHelper is Test {
    ChildERC20Bridge public childBridge;

    uint256 public totalGas;

    constructor(address payable _childBridge) {
        childBridge = ChildERC20Bridge(_childBridge);
    }

    function withdraw(address user, address childToken, uint256 amount, uint256 gasAmt) public {
        vm.deal(user, gasAmt);
        totalGas += gasAmt;

        vm.prank(user);
        childBridge.withdraw{value: gasAmt}(IChildERC20(childToken), amount);
    }

    function withdrawTo(address user, address recipient, address childToken, uint256 amount, uint256 gasAmt) public {
        vm.deal(user, gasAmt);
        totalGas += gasAmt;

        vm.prank(user);
        childBridge.withdrawTo{value: gasAmt}(IChildERC20(childToken), recipient, amount);
    }
}
