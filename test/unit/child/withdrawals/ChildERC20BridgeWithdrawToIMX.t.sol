// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20Bridge,
    IChildERC20BridgeEvents,
    IERC20Metadata,
    IChildERC20BridgeErrors
} from "../../../../src/child/ChildERC20Bridge.sol";
import {IChildERC20} from "../../../../src/interfaces/child/IChildERC20.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../../utils.t.sol";

contract ChildERC20BridgeWithdrawIMXToUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));
    string constant ROOT_CHAIN_NAME = "test";
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    ChildERC20 public childTokenTemplate;
    ChildERC20 public rootToken;
    ChildERC20 public childToken;
    address public childETHToken;
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
            variableManager: address(this),
            adaptorManager: address(this)
        });
        childBridge.initialize(
            roles,
            address(mockAdaptor),
            ROOT_BRIDGE_ADAPTOR,
            address(childTokenTemplate),
            ROOT_CHAIN_NAME,
            ROOT_IMX_TOKEN
        );
    }

    function test_RevertsIf_withdrawIMXToCalledWithInsufficientFund() public {
        uint256 withdrawAmount = 7 ether;

        vm.expectRevert(InsufficientValue.selector);
        childBridge.withdrawIMXTo{value: withdrawAmount - 1}(address(this), withdrawAmount);
    }

    function test_RevertIf_ZeroAmountIsProvided() public {
        uint256 withdrawFee = 300;

        vm.expectRevert(ZeroAmount.selector);
        childBridge.withdrawIMXTo{value: withdrawFee}(address(this), 0);
    }

    function test_withdrawIMXTo_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawIMXTo{value: withdrawFee + withdrawAmount}(address(this), withdrawAmount);
    }

    function test_withdrawIMXToWithDifferentAccount_CallsBridgeAdaptor() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawIMXTo{value: withdrawFee + withdrawAmount}(receiver, withdrawAmount);
    }

    function test_withdrawIMXTo_EmitsNativeIMXWithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainNativeIMXWithdraw(ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
        childBridge.withdrawIMXTo{value: withdrawFee + withdrawAmount}(address(this), withdrawAmount);
    }

    function test_withdrawIMXToWithDifferentAccount_EmitsNativeIMXWithdrawEvent() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainNativeIMXWithdraw(ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);
        childBridge.withdrawIMXTo{value: withdrawFee + withdrawAmount}(receiver, withdrawAmount);
    }

    function test_WithdrawIMXTo_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;

        childBridge.withdrawIMXTo{value: withdrawFee + withdrawAmount}(address(this), withdrawAmount);

        uint256 postBal = address(this).balance;
        assertEq(postBal, preBal - withdrawAmount - withdrawFee, "Balance not reduced");
    }

    function test_WithdrawIMXTo_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(mockAdaptor).balance;

        childBridge.withdrawIMXTo{value: withdrawFee + withdrawAmount}(address(this), withdrawAmount);

        uint256 postBal = address(mockAdaptor).balance;
        assertEq(postBal, preBal + withdrawFee, "Adaptor balance not increased");
    }
}
