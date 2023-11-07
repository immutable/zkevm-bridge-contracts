// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20BridgeEvents,
    IERC20Metadata,
    IChildERC20BridgeErrors
} from "../../../../src/child/ChildERC20Bridge.sol";
import {IChildERC20} from "../../../../src/interfaces/child/IChildERC20.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WIMX} from "../../../../src/child/WIMX.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ChildERC20BridgeWithdrawWIMXUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));
    string constant ROOT_CHAIN_NAME = "test";
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant WIMX_TOKEN_ADDRESS = address(0xabc);
    ChildERC20 public childTokenTemplate;
    ChildERC20Bridge public childBridge;
    MockAdaptor public mockAdaptor;
    WIMX public wIMXToken;

    function setUp() public {
        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        mockAdaptor = new MockAdaptor();

        wIMXToken = new WIMX();
        Address.sendValue(payable(wIMXToken), 100 ether);

        childBridge = new ChildERC20Bridge();
        childBridge.initialize(
            address(mockAdaptor),
            ROOT_BRIDGE_ADAPTOR,
            address(childTokenTemplate),
            ROOT_CHAIN_NAME,
            ROOT_IMX_TOKEN,
            address(wIMXToken)
        );
    }

    function test_RevertsIf_WithdrawWIMXCalledWithInsufficientFund() public {
        uint256 withdrawAmount = 101 ether;
        uint256 withdrawFee = 300;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        vm.expectRevert(bytes("Wrapped IMX: Insufficient balance"));
        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_RevertsIf_WithdrawWIMXCalledWithInsufficientAllowance() public {
        uint256 withdrawAmount = 99 ether;
        uint256 withdrawFee = 300;

        wIMXToken.approve(address(childBridge), withdrawAmount - 1);
        vm.expectRevert(bytes("Wrapped IMX: Insufficient allowance"));
        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_RevertsIf_ZeroAmountIsProvided() public {
        uint256 withdrawFee = 300;

        vm.expectRevert(ZeroAmount.selector);
        childBridge.withdrawWIMX{value: withdrawFee}(0);
    }

    function test_WithdrawWIMX_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
        wIMXToken.approve(address(childBridge), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawWIMX_EmitsWrappedIMXWithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        vm.expectEmit(address(childBridge));
        emit ChildChainWrappedIMXWithdraw(ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawWIMX_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = wIMXToken.balanceOf(address(this));

        wIMXToken.approve(address(childBridge), withdrawAmount);
        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);

        uint256 postBal = wIMXToken.balanceOf(address(this));
        assertEq(postBal, preBal - withdrawAmount, "Balance not reduced");
    }

    function test_WithdrawWIMX_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);

        uint256 postBal = address(this).balance;
        assertEq(postBal, preBal - withdrawFee, "Fee not paid");
    }
}
