// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../../../mocks/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../mocks/root/MockAxelarGasService.sol";
import {ChildERC20Bridge, IChildERC20BridgeEvents} from "../../../../src/child/ChildERC20Bridge.sol";
import {
    ChildAxelarBridgeAdaptor,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors
} from "../../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WIMX} from "../../../../src/child/WIMX.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ChildERC20BridgeWithdrawWIMXToIntegrationTest is
    Test,
    IChildERC20BridgeEvents,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors,
    Utils
{
    address constant ROOT_IMX_TOKEN = address(555555);
    address constant WRAPPED_IMX = address(0xabc);

    ChildERC20Bridge public childBridge;
    ChildAxelarBridgeAdaptor public axelarAdaptor;
    address public rootToken;
    address public rootImxToken;
    ChildERC20 public childTokenTemplate;
    MockAxelarGasService public axelarGasService;
    MockAxelarGateway public mockAxelarGateway;
    WIMX public wIMXToken;

    function setUp() public {
        (childBridge, axelarAdaptor, rootToken, rootImxToken, childTokenTemplate, axelarGasService, mockAxelarGateway) =
            childIntegrationSetup();
        wIMXToken = WIMX(payable(WRAPPED_IMX));
        Address.sendValue(payable(wIMXToken), 100 ether);
    }

    function test_WithdrawWIMXTo_CallsBridgeAdaptor() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 1;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);
        vm.expectCall(
            address(axelarAdaptor),
            withdrawFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXToWithDifferentAccount_CallsBridgeAdaptor() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);
        vm.expectCall(
            address(axelarAdaptor),
            withdrawFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXTo_CallsAxelarGateway() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);
        vm.expectCall(
            address(mockAxelarGateway),
            0,
            abi.encodeWithSelector(
                mockAxelarGateway.callContract.selector,
                axelarAdaptor.rootChainId(),
                axelarAdaptor.rootBridgeAdaptor(),
                predictedPayload
            )
        );

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXToWithDifferentAccount_CallsAxelarGateway() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);
        vm.expectCall(
            address(mockAxelarGateway),
            0,
            abi.encodeWithSelector(
                mockAxelarGateway.callContract.selector,
                axelarAdaptor.rootChainId(),
                axelarAdaptor.rootBridgeAdaptor(),
                predictedPayload
            )
        );

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXTo_CallsGasService() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);

        vm.expectCall(
            address(axelarGasService),
            withdrawFee,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                axelarAdaptor.rootChainId(),
                axelarAdaptor.rootBridgeAdaptor(),
                predictedPayload,
                address(this)
            )
        );

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXToWithDifferentAccount_CallsGasService() public {
        address receiver = address(0xabcdf);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);

        vm.expectCall(
            address(axelarGasService),
            withdrawFee,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                axelarAdaptor.rootChainId(),
                axelarAdaptor.rootBridgeAdaptor(),
                predictedPayload,
                address(this)
            )
        );

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXTo_EmitsAxelarMessageSentEvent() public {
        address receiver = address(0xabcd);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(axelarAdaptor.rootChainId(), axelarAdaptor.rootBridgeAdaptor(), predictedPayload);

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXToWithDifferentAccount_EmitsAxelarMessageSentEvent() public {
        address receiver = address(0xabcda);
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), receiver, withdrawAmount);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(axelarAdaptor.rootChainId(), axelarAdaptor.rootBridgeAdaptor(), predictedPayload);

        childBridge.withdrawWIMXTo{value: withdrawFee}(receiver, withdrawAmount);
    }

    function test_WithdrawWIMXTo_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;
        uint256 preTokenBal = wIMXToken.balanceOf(address(this));
        uint256 preGasBal = address(axelarGasService).balance;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        childBridge.withdrawWIMXTo{value: withdrawFee}(address(this), withdrawAmount);

        uint256 postBal = address(this).balance;
        uint256 postTokenBal = wIMXToken.balanceOf(address(this));
        uint256 postGasBal = address(axelarGasService).balance;

        assertEq(postBal, preBal - withdrawFee, "Balance not reduced");
        assertEq(postTokenBal, preTokenBal - withdrawAmount);
        assertEq(postGasBal, preGasBal + withdrawFee, "Gas service not getting paid");
    }
}
