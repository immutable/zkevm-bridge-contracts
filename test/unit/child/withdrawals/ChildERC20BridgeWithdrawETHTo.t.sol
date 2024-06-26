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
    IChildERC20BridgeErrors
} from "../../../../src/child/ChildERC20Bridge.sol";
import {IChildERC20} from "../../../../src/interfaces/child/IChildERC20.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../mocks/root/MockAdaptor.sol";
import {Utils, IPausable} from "../../../utils.t.sol";

contract ChildERC20BridgeWithdrawETHToUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WIMX_TOKEN_ADDRESS = address(0xabc);
    ChildERC20 public childTokenTemplate;
    ChildERC20 public rootToken;
    ChildERC20 public childToken;
    ChildERC20 public childETHToken;
    ChildERC20Bridge public childBridge;
    MockAdaptor public mockAdaptor;

    function setUp() public {
        rootToken = new ChildERC20();
        rootToken.initialize(address(456), "Test", "TST", 18);

        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        mockAdaptor = new MockAdaptor();

        childBridge = new ChildERC20Bridge(address(this));
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: pauser,
            unpauser: unpauser,
            adaptorManager: address(this),
            initialDepositor: address(this),
            treasuryManager: address(this)
        });
        childBridge.initialize(
            roles, address(mockAdaptor), address(childTokenTemplate), ROOT_IMX_TOKEN, WIMX_TOKEN_ADDRESS
        );

        bytes memory mapTokenData =
            abi.encode(MAP_TOKEN_SIG, rootToken, rootToken.name(), rootToken.symbol(), rootToken.decimals());

        vm.prank(address(mockAdaptor));
        childBridge.onMessageReceive(mapTokenData);

        childToken = ChildERC20(childBridge.rootTokenToChildToken(address(rootToken)));
        vm.prank(address(childBridge));
        childToken.mint(address(this), 1000000 ether);
        childToken.approve(address(childBridge), 1000000 ether);

        childETHToken = ChildERC20(childBridge.childETHToken());
        vm.prank(address(childBridge));
        childETHToken.mint(address(this), 100 ether);
    }

    /**
     * WITHDRAW ETH TO
     */
    function test_RevertsIf_WithdrawETHToWhenPaused() public {
        pause(IPausable(address(childBridge)));
        vm.expectRevert("Pausable: paused");
        childBridge.withdrawETHTo{value: 1 ether}(address(this), 100);
    }

    function test_WithdrawETHToResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_WithdrawETHToWhenPaused();
        unpause(IPausable(address(childBridge)));
        // Expect success case to pass
        test_WithdrawETHTo_CallsBridgeAdaptor();
    }

    function test_RevertsIf_WithdrawETHToCalledWithZeroFee() public {
        uint256 withdrawAmount = 100;

        vm.expectRevert(NoGas.selector);
        childBridge.withdrawETHTo(address(this), withdrawAmount);
    }

    function test_RevertsIf_WithdrawEthToCalledWithInsufficientFund() public {
        uint256 withdrawAmount = 101 ether;
        uint256 withdrawFee = 300;

        vm.expectRevert(BurnFailed.selector);
        childBridge.withdrawETHTo{value: withdrawFee}(address(this), withdrawAmount);
    }

    function test_RevertsIf_ZeroAmountIsProvided() public {
        uint256 withdrawFee = 300;

        vm.expectRevert(ZeroAmount.selector);
        childBridge.withdrawETHTo{value: withdrawFee}(address(this), 0);
    }

    function test_WithdrawETHTo_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawETHTo{value: withdrawFee}(address(this), withdrawAmount);
    }

    function test_WithdrawETHToWithDifferentAccount_CallsBridgeAdaptor() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload = abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), receiver, withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawETHTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawETHTo_EmitsChildChainEthWithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainEthWithdraw(address(this), address(this), withdrawAmount);
        childBridge.withdrawETHTo{value: withdrawFee}(address(this), withdrawAmount);
    }

    function test_WithdrawETHToWithDifferentAccount_EmitsChildChainEthWithdrawEvent() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainEthWithdraw(address(this), receiver, withdrawAmount);
        childBridge.withdrawETHTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawETHTo_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = childETHToken.balanceOf(address(this));

        childBridge.withdrawETHTo{value: withdrawFee}(address(this), withdrawAmount);

        uint256 postBal = childETHToken.balanceOf(address(this));
        assertEq(postBal, preBal - withdrawAmount, "Balance not reduced");
    }

    function test_WithdrawETHTo_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;

        childBridge.withdrawETHTo{value: withdrawFee}(address(this), withdrawAmount);

        uint256 postBal = address(this).balance;
        assertEq(postBal, preBal - withdrawFee, "Fee not paid");
    }
}
