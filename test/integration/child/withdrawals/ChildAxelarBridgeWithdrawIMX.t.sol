// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

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
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";

contract ChildERC20BridgeWithdrawIMXIntegrationTest is
    Test,
    IChildERC20BridgeEvents,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors,
    Utils
{
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string constant CHILD_CHAIN_NAME = "test";
    address constant ROOT_IMX_TOKEN = address(555555);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);

    ChildERC20Bridge public childBridge;
    ChildAxelarBridgeAdaptor public axelarAdaptor;
    address public rootToken;
    address public rootImxToken;
    ChildERC20 public childTokenTemplate;
    MockAxelarGasService public axelarGasService;
    MockAxelarGateway public mockAxelarGateway;

    function setUp() public {
        (childBridge, axelarAdaptor, rootToken, rootImxToken, childTokenTemplate, axelarGasService, mockAxelarGateway) =
            childIntegrationSetup();
    }

    function test_WithdrawIMX_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);
        vm.expectCall(
            address(axelarAdaptor),
            withdrawFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);
    }

    function test_WithdrawIMX_CallsAxelarGateway() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

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

        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);
    }

    function test_WithdrawIMX_CallsGasService() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(axelarGasService),
            withdrawFee,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                childBridge.rootChain(),
                childBridge.rootERC20BridgeAdaptor(),
                predictedPayload,
                address(this)
            )
        );

        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);
    }

    function test_WithdrawIMX_EmitsAxelarMessageEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, ROOT_IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(childBridge.rootChain(), childBridge.rootERC20BridgeAdaptor(), predictedPayload);

        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);
    }

    function test_WithdrawIMX_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(this).balance;
        uint256 preGasBal = address(axelarGasService).balance;

        childBridge.withdrawIMX{value: withdrawFee + withdrawAmount}(withdrawAmount);

        uint256 postBal = address(this).balance;
        uint256 postGasBal = address(axelarGasService).balance;

        assertEq(postBal, preBal - withdrawFee - withdrawAmount, "Balance not reduced");
        assertEq(postGasBal, preGasBal + withdrawFee, "Gas service not getting paid");
    }
}
