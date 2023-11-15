// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../../src/test/root/MockAxelarGasService.sol";
import {ChildERC20Bridge, IChildERC20BridgeEvents} from "../../../../src/child/ChildERC20Bridge.sol";
import {
    ChildAxelarBridgeAdaptor,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors
} from "../../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WETH} from "../../../../src/test/root/WETH.sol";
import {WIMX} from "../../../../src/child/WIMX.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ChildERC20BridgeWithdrawETHIntegrationTest is
    Test,
    IChildERC20BridgeEvents,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors,
    Utils
{
    address constant NATIVE_ETH = address(0xeee);

    ChildERC20Bridge public childBridge;
    ChildAxelarBridgeAdaptor public axelarAdaptor;
    ChildERC20 public childTokenTemplate;
    MockAxelarGasService public mockAxelarGasService;
    MockAxelarGateway public mockAxelarGateway;
    ChildERC20 public childETHToken;

    function setUp() public {
        (childBridge, axelarAdaptor,,,, mockAxelarGasService, mockAxelarGateway) = childIntegrationSetup();

        childETHToken = ChildERC20(childBridge.childETHToken());
        vm.prank(address(childBridge));
        childETHToken.mint(address(this), 100 ether);
    }

    function test_WithdrawETH_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);
        vm.expectCall(
            address(axelarAdaptor),
            withdrawFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawETH_CallsAxelarGateway() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);
        vm.expectCall(
            address(mockAxelarGateway),
            0,
            abi.encodeWithSelector(
                mockAxelarGateway.callContract.selector,
                childBridge.rootChain(),
                childBridge.rootERC20BridgeAdaptor(),
                predictedPayload
            )
        );

        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawETH_CallsGasService() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(mockAxelarGasService),
            withdrawFee,
            abi.encodeWithSelector(
                mockAxelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                childBridge.rootChain(),
                childBridge.rootERC20BridgeAdaptor(),
                predictedPayload,
                address(this)
            )
        );

        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawETH_EmitsAxelarMessageSentEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(childBridge.rootChain(), childBridge.rootERC20BridgeAdaptor(), predictedPayload);

        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawETH_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;
        uint256 preTokenBal = childETHToken.balanceOf(address(this));
        uint256 preGasBal = address(mockAxelarGasService).balance;

        childBridge.withdrawETH{value: withdrawFee}(withdrawAmount);

        uint256 postBal = address(this).balance;
        uint256 postTokenBal = childETHToken.balanceOf(address(this));
        uint256 postGasBal = address(mockAxelarGasService).balance;

        assertEq(postBal, preBal - withdrawFee, "Balance not reduced");
        assertEq(postTokenBal, preTokenBal - withdrawAmount);
        assertEq(postGasBal, preGasBal + withdrawFee, "Gas service not getting paid");
    }
}
