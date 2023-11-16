// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20Bridge,
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors
} from "../../../../src/child/ChildERC20Bridge.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../../utils.t.sol";

contract ChildERC20BridgeWithdrawIMXUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));
    string constant ROOT_CHAIN_NAME = "test";
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant WIMX_TOKEN_ADDRESS = address(0xabc);
    ChildERC20 public childTokenTemplate;
    ChildERC20Bridge public childBridge;
    MockAdaptor public mockAdaptor;

    function setUp() public {
        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        mockAdaptor = new MockAdaptor();

        childBridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });
        childBridge.initialize(
            roles,
            address(mockAdaptor),
            ROOT_BRIDGE_ADAPTOR,
            address(childTokenTemplate),
            ROOT_CHAIN_NAME,
            ROOT_IMX_TOKEN,
            WIMX_TOKEN_ADDRESS
        );
    }

    function test_RevertIf_WithdrawIMXCalledWithZeroFee() public {
        uint256 withdrawAmount = 300;

        vm.expectRevert(NoGas.selector);
        childBridge.withdrawIMX(withdrawAmount);
    }

    function test_RevertsIf_WithdrawIMXCalledWithInsufficientFund() public {
        uint256 withdrawAmount = 7 ether;

        vm.expectRevert(InsufficientValue.selector);
        childBridge.withdrawIMX{value: withdrawAmount - 1}(withdrawAmount);
    }

    function test_RevertIf_ZeroAmountIsProvided() public {
        uint256 withdrawFee = 300;

        vm.expectRevert(ZeroAmount.selector);
        childBridge.withdrawIMX{value: withdrawFee}(0);
    }

    function test_WithdrawIMX_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);
    }

    function test_WithdrawIMX_EmitsNativeIMXWithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainNativeIMXWithdraw(ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);
    }

    function test_WithdrawIMX_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;

        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);

        uint256 postBal = address(this).balance;
        assertEq(postBal, preBal - withdrawAmount - withdrawFee, "Balance not reduced");
    }

    function test_WithdrawIMX_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(mockAdaptor).balance;

        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);

        uint256 postBal = address(mockAdaptor).balance;
        assertEq(postBal, preBal + withdrawFee, "Adaptor balance not increased");
    }
}
