// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
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

contract ChildERC20BridgeWithdrawWIMXIntegrationTest is
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
    MockAxelarGasService public mockAxelarGasService;
    MockAxelarGateway public mockAxelarGateway;
    WIMX public wIMXToken;

    function setUp() public {
        (childBridge, axelarAdaptor,,,, mockAxelarGasService, mockAxelarGateway) = childIntegrationSetup();
        wIMXToken = WIMX(payable(WRAPPED_IMX));
        Address.sendValue(payable(wIMXToken), 100 ether);
    }

    function test_WithdrawWIMX_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
        vm.expectCall(
            address(axelarAdaptor),
            withdrawFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawWIMX_CallsAxelarGateway() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
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

        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawWIMX_CallsGasService() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);

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

        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawWIMX_EmitsAxelarMessageSentEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(childBridge.rootChain(), childBridge.rootERC20BridgeAdaptor(), predictedPayload);

        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);
    }

    function test_WithdrawWIMX_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;
        uint256 preTokenBal = wIMXToken.balanceOf(address(this));
        uint256 preGasBal = address(mockAxelarGasService).balance;

        wIMXToken.approve(address(childBridge), withdrawAmount);
        childBridge.withdrawWIMX{value: withdrawFee}(withdrawAmount);

        uint256 postBal = address(this).balance;
        uint256 postTokenBal = wIMXToken.balanceOf(address(this));
        uint256 postGasBal = address(mockAxelarGasService).balance;

        assertEq(postBal, preBal - withdrawFee, "Balance not reduced");
        assertEq(postTokenBal, preTokenBal - withdrawAmount);
        assertEq(postGasBal, preGasBal + withdrawFee, "Gas service not getting paid");
    }
}
