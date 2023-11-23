// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20Bridge,
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors
} from "../../../../src/child/ChildERC20Bridge.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../mocks/root/MockAdaptor.sol";
import {Utils, IPausable} from "../../../utils.t.sol";
import {WIMX} from "../../../../src/child/WIMX.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ChildERC20BridgeWithdrawWIMXToUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
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
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: pauser,
            unpauser: unpauser,
            adaptorManager: address(this),
            initialDepositor: address(this),
            treasuryManager: address(this)
        });
        childBridge.initialize(
            roles, address(mockAdaptor), address(childTokenTemplate), ROOT_IMX_TOKEN, address(wIMXToken)
        );
    }

    /**
     * WITHDRAW WIMX TO
     */

    function test_RevertsIf_WithdrawWIMXToWhenPaused() public {
        pause(IPausable(address(childBridge)));
        vm.expectRevert("Pausable: paused");
        childBridge.withdrawWIMXTo{value: 1 ether}(address(this), 100);
    }

    function test_WithdrawWIMXToResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_WithdrawWIMXToWhenPaused();
        unpause(IPausable(address(childBridge)));
        // Expect success case to pass
        test_WithdrawWIMXTo_CallsBridgeAdaptor();
    }

    function test_RevertsIf_WithdrawWIMXToCalledWithZeroReceiver() public {
        uint256 withdrawAmount = 7 ether;

        vm.expectRevert(ZeroAddress.selector);
        childBridge.withdrawWIMXTo{value: 1 ether}(address(0), withdrawAmount);
    }

    function test_RevertsIf_WithdrawWIMXToCalledWithZeroFee() public {
        uint256 withdrawAmount = 7 ether;

        vm.expectRevert(NoGas.selector);
        childBridge.withdrawWIMXTo(address(this), withdrawAmount);
    }

    function test_RevertsIf_WithdrawWIMXToCalledWithInsufficientFund() public {
        uint256 withdrawAmount = 101 ether;
        uint256 withdrawFee = 300;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        vm.expectRevert(bytes("Wrapped IMX: Insufficient balance"));
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), withdrawAmount);
    }

    function test_RevertsIf_WithdrawWIMXToCalledWithInsufficientAllowance() public {
        uint256 withdrawAmount = 99 ether;
        uint256 withdrawFee = 300;

        wIMXToken.approve(address(childBridge), withdrawAmount - 1);
        vm.expectRevert(bytes("Wrapped IMX: Insufficient allowance"));
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), withdrawAmount);
    }

    function test_RevertsIf_WithdrawWIMXToCalledWithZeroAmount() public {
        uint256 withdrawFee = 300;

        vm.expectRevert(ZeroAmount.selector);
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), 0);
    }

    function test_WithdrawWIMXTo_CallsBridgeAdaptor() public {
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
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), withdrawAmount);
    }

    function test_WithdrawWIMXToWithDifferentAccount_CallsBridgeAdaptor() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);
        wIMXToken.approve(address(childBridge), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXTo_EmitsWrappedIMXWithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        vm.expectEmit(address(childBridge));
        emit ChildChainWrappedIMXWithdraw(ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), withdrawAmount);
    }

    function test_WithdrawWIMXToWithDifferentAccount_EmitsWrappedIMXWithdrawEvent() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        vm.expectEmit(address(childBridge));
        emit ChildChainWrappedIMXWithdraw(ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);
        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXTo_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = wIMXToken.balanceOf(address(this));

        wIMXToken.approve(address(childBridge), withdrawAmount);
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), withdrawAmount);

        uint256 postBal = wIMXToken.balanceOf(address(this));
        assertEq(postBal, preBal - withdrawAmount, "Balance not reduced");
    }

    function test_WithdrawWIMXTo_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), withdrawAmount);

        uint256 postBal = address(this).balance;
        assertEq(postBal, preBal - withdrawFee, "Fee not paid");
    }
}
