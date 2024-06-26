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
import {IChildERC20} from "../../../../src/interfaces/child/IChildERC20.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../mocks/root/MockAdaptor.sol";
import {Utils, IPausable} from "../../../utils.t.sol";

contract ChildERC20BridgeWithdrawETHUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WIMX_TOKEN_ADDRESS = address(0xabc);
    ChildERC20 public childTokenTemplate;
    ChildERC20 public childETHToken;
    ChildERC20Bridge public childBridge;
    MockAdaptor public mockAdaptor;

    function setUp() public {
        childTokenTemplate = new ChildERC20();

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

        childETHToken = ChildERC20(childBridge.childETHToken());
        vm.prank(address(childBridge));
        childETHToken.mint(address(this), 100 ether);
    }

    /**
     * WITHDRAW ETH
     */
    function test_RevertsIf_WithdrawETHWhenPaused() public {
        pause(IPausable(address(childBridge)));
        vm.expectRevert("Pausable: paused");
        childBridge.withdrawETH{value: 1 ether}(100);
    }

    function test_WithdrawETHResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_WithdrawETHWhenPaused();
        unpause(IPausable(address(childBridge)));
        // Expect success case to pass
        test_WithdrawETH_EmitsChildChainEthWithdrawEvent();
    }

    function test_RevertsIf_WithdrawETHCalledWithZeroFee() public {
        uint256 withdrawAmount = 100;

        vm.expectRevert(NoGas.selector);
        childBridge.withdrawETH(withdrawAmount);
    }

    function test_RevertsIf_WithdrawEthCalledWithInsufficientFund() public {
        uint256 withdrawAmount = 101 ether;
        uint256 withdrawFee = 300;

        vm.expectRevert(BurnFailed.selector);
        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);
    }

    function test_RevertsIf_ZeroAmountIsProvided() public {
        uint256 withdrawFee = 300;

        vm.expectRevert(ZeroAmount.selector);
        childBridge.withdrawETH{value: withdrawFee}(0);
    }

    function test_WithdrawETH_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );
        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawETH_EmitsChildChainEthWithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainEthWithdraw(address(this), address(this), withdrawAmount);
        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawETH_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = childETHToken.balanceOf(address(this));

        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);

        uint256 postBal = childETHToken.balanceOf(address(this));
        assertEq(postBal, preBal - withdrawAmount, "Balance not reduced");
    }

    function test_WithdrawETH_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;

        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);

        uint256 postBal = address(this).balance;
        assertEq(postBal, preBal - withdrawFee, "Fee not paid");
    }
}
