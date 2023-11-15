// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockAxelarGateway} from "../../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../../src/test/root/MockAxelarGasService.sol";
import {ChildERC20Bridge, IChildERC20BridgeEvents} from "../../../../src/child/ChildERC20Bridge.sol";
import {
    ChildAxelarBridgeAdaptor,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors
} from "../../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";

contract ChildERC20BridgeWithdrawIntegrationTest is
    Test,
    IChildERC20BridgeEvents,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors,
    Utils
{
    uint256 constant withdrawFee = 200;
    uint256 constant withdrawAmount = 99999999999;

    ChildERC20Bridge public childBridge;
    ChildAxelarBridgeAdaptor public axelarAdaptor;
    address public rootToken;
    MockAxelarGasService public mockAxelarGasService;
    MockAxelarGateway public mockAxelarGateway;

    address receiver = address(0xabcd);

    function setUp() public {
        ChildERC20 childTokenTemplate;
        (childBridge, axelarAdaptor, rootToken,, childTokenTemplate, mockAxelarGasService, mockAxelarGateway) =
            childIntegrationSetup();
    }

    /**
     * @dev A future test will assert that the computed childToken is the same as what gets deployed on L2.
     *      This test uses the same code as the mapToken function does to calculate this address, so we can
     *      not consider it sufficient.
     */
    function test_withdraw_CallsBridgeAdaptor() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, rootToken, address(this), address(this), withdrawAmount);
        vm.expectCall(
            address(axelarAdaptor),
            withdrawFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);
    }

    function test_withdraw_Calls_AxelarGateway() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, rootToken, address(this), address(this), withdrawAmount);
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

        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);
    }

    function test_withdraw_Calls_GasService() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, rootToken, address(this), address(this), withdrawAmount);
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

        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);
    }

    function test_withdraw_emits_AxelarMessageSentEvent() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, rootToken, address(this), address(this), withdrawAmount);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(childBridge.rootChain(), childBridge.rootERC20BridgeAdaptor(), predictedPayload);
        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);
    }

    function test_withdraw_BurnsFundsAndTransfersGas() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        uint256 preBal = childToken.balanceOf(address(this));
        uint256 preGasBal = address(mockAxelarGasService).balance;

        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);

        uint256 postBal = childToken.balanceOf(address(this));
        uint256 postGasBal = address(mockAxelarGasService).balance;

        assertEq(postBal, preBal - withdrawAmount, "Balance not reduced");
        assertEq(postGasBal, preGasBal + withdrawFee, "Gas not transferred");
    }

    function test_RevertIf_WithdrawWithNoGas() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        vm.expectRevert(NoGas.selector);
        childBridge.withdraw(childToken, withdrawAmount);
    }
}
