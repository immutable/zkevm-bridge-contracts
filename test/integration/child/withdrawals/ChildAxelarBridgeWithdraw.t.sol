// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

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

contract ChildERC20BridgeWithdrawIntegrationTest is
    Test,
    IChildERC20BridgeEvents,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptorErrors,
    Utils
{
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string constant CHILD_CHAIN_NAME = "test";
    address constant IMX_TOKEN_ADDRESS = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);

    uint256 constant withdrawFee = 200;
    uint256 constant withdrawAmount = 99999999999;

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

        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);
    }

    function test_withdraw_emits_AxelarMessageEvent() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, rootToken, address(this), address(this), withdrawAmount);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessage(childBridge.rootChain(), childBridge.rootERC20BridgeAdaptor(), predictedPayload);
        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);
    }

    function test_withdraw_BurnsFundsAndTransfersGas() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        uint256 preBal = childToken.balanceOf(address(this));
        uint256 preGasBal = address(axelarGasService).balance;

        childBridge.withdraw{value: withdrawFee}(childToken, withdrawAmount);

        uint256 postBal = childToken.balanceOf(address(this));
        uint256 postGasBal = address(axelarGasService).balance;

        assertEq(postBal, preBal - withdrawAmount, "Balance not reduced");
        assertEq(postGasBal, preGasBal + withdrawFee, "Gas not transferred");
    }

    function test_RevertIf_WithdrawWithNoGas() public {
        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(rootToken));

        vm.expectRevert(NoGas.selector);
        childBridge.withdraw(childToken, withdrawAmount);
    }

    // 7a8dc26796a1e50e6e190b70259f58f6a4edd5b22280ceecc82b687b8e982869
    // 000000000000000000000000000000000000000000000000000000000000ad9c
    // 0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
    // 0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
    // 000000000000000000000000000000000000000000000000000000174876e7ff
    // 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496

    // f20755ba
    // 0000000000000000000000000000000000000000000000000000000000000040
    // 0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
    // 00000000000000000000000000000000000000000000000000000000000000a0
    // 2cef46a936bdc5b7e6e8c71aa04560c41cf7d88bb26901a7e7f4936ff02accad
    // 000000000000000000000000000000000000000000000000000000000000ad9c
    // 0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
    // 0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
    // 000000000000000000000000000000000000000000000000000000174876e7ff

    //     bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
    //     vm.expectEmit(true, true, true, false, address(axelarAdaptor));
    //     emit AxelarMessage(CHILD_CHAIN_NAME, Strings.toHexString(CHILD_BRIDGE_ADAPTOR), payload);

    //     vm.expectEmit(true, true, false, false, address(rootBridge));
    //     emit L1TokenMapped(address(token), childToken);

    //     // Instead of using expectCalls, we could use expectEmit in combination with mock contracts emitting events.
    //     // expectCalls requires less boilerplate and is less dependant on mock code.
    //     vm.expectCall(
    //         address(axelarAdaptor),
    //         mapTokenFee,
    //         abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, payload, address(this))
    //     );

    //     // These are calls that the axelarAdaptor should make.
    //     vm.expectCall(
    //         address(axelarGasService),
    //         mapTokenFee,
    //         abi.encodeWithSelector(
    //             axelarGasService.payNativeGasForContractCall.selector,
    //             address(axelarAdaptor),
    //             CHILD_CHAIN_NAME,
    //             Strings.toHexString(CHILD_BRIDGE_ADAPTOR),
    //             payload,
    //             address(this)
    //         )
    //     );

    //     vm.expectCall(
    //         address(mockAxelarGateway),
    //         0,
    //         abi.encodeWithSelector(
    //             mockAxelarGateway.callContract.selector,
    //             CHILD_CHAIN_NAME,
    //             Strings.toHexString(CHILD_BRIDGE_ADAPTOR),
    //             payload
    //         )
    //     );

    //     // Check that we pay mapTokenFee to the axelarGasService.
    //     uint256 thisPreBal = address(this).balance;
    //     uint256 axelarGasServicePreBal = address(axelarGasService).balance;

    //     rootBridge.mapToken{value: mapTokenFee}(token);

    //     // Should update ETH balances as gas payment for message.
    //     assertEq(address(this).balance, thisPreBal - mapTokenFee, "ETH balance not decreased");
    //     assertEq(address(axelarGasService).balance, axelarGasServicePreBal + mapTokenFee, "ETH not paid to gas service");

    //     assertEq(rootBridge.rootTokenToChildToken(address(token)), childToken, "childToken not set");
    // }

    // // TODO split into multiple tests
    // function test_depositETH() public {
    //     uint256 tokenAmount = 300;
    //     string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);

    //     (, bytes memory predictedPayload) =
    //         setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, tokenAmount, false);

    //     console2.logBytes(predictedPayload);

    //     vm.expectEmit(address(axelarAdaptor));
    //     emit AxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
    //     vm.expectEmit(address(rootBridge));
    //     emit NativeEthDeposit(
    //         address(NATIVE_ETH), rootBridge.childETHToken(), address(this), address(this), tokenAmount
    //     );

    //     vm.expectCall(
    //         address(axelarAdaptor),
    //         depositFee,
    //         abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
    //     );

    //     vm.expectCall(
    //         address(axelarGasService),
    //         depositFee,
    //         abi.encodeWithSelector(
    //             axelarGasService.payNativeGasForContractCall.selector,
    //             address(axelarAdaptor),
    //             CHILD_CHAIN_NAME,
    //             childBridgeAdaptorString,
    //             predictedPayload,
    //             address(this)
    //         )
    //     );

    //     vm.expectCall(
    //         address(mockAxelarGateway),
    //         0,
    //         abi.encodeWithSelector(
    //             mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload
    //         )
    //     );

    //     uint256 bridgePreBal = address(rootBridge).balance;

    //     uint256 thisNativePreBal = address(this).balance;
    //     uint256 gasServiceNativePreBal = address(axelarGasService).balance;

    //     rootBridge.depositETH{value: tokenAmount + depositFee}(tokenAmount);

    //     // Check that tokens are transferred
    //     assertEq(bridgePreBal + tokenAmount, address(rootBridge).balance, "ETH not transferred to bridge");
    //     // Check that native asset transferred to gas service
    //     assertEq(thisNativePreBal - (depositFee + tokenAmount), address(this).balance, "ETH not paid from user");
    //     assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    // }

    // // TODO split into multiple tests
    // function test_depositIMXToken() public {
    //     uint256 tokenAmount = 300;
    //     string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);

    //     (, bytes memory predictedPayload) =
    //         setupDeposit(IMX_TOKEN_ADDRESS, rootBridge, mapTokenFee, depositFee, tokenAmount, false);

    //     vm.expectEmit(address(axelarAdaptor));
    //     emit AxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
    //     vm.expectEmit(address(rootBridge));
    //     emit IMXDeposit(address(IMX_TOKEN_ADDRESS), address(this), address(this), tokenAmount);

    //     vm.expectCall(
    //         address(axelarAdaptor),
    //         depositFee,
    //         abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
    //     );

    //     vm.expectCall(
    //         address(axelarGasService),
    //         depositFee,
    //         abi.encodeWithSelector(
    //             axelarGasService.payNativeGasForContractCall.selector,
    //             address(axelarAdaptor),
    //             CHILD_CHAIN_NAME,
    //             childBridgeAdaptorString,
    //             predictedPayload,
    //             address(this)
    //         )
    //     );

    //     vm.expectCall(
    //         address(mockAxelarGateway),
    //         0,
    //         abi.encodeWithSelector(
    //             mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload
    //         )
    //     );

    //     uint256 thisPreBal = imxToken.balanceOf(address(this));
    //     uint256 bridgePreBal = imxToken.balanceOf(address(rootBridge));

    //     uint256 thisNativePreBal = address(this).balance;
    //     uint256 gasServiceNativePreBal = address(axelarGasService).balance;

    //     rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN_ADDRESS), tokenAmount);

    //     // Check that tokens are transferred
    //     assertEq(thisPreBal - tokenAmount, imxToken.balanceOf(address(this)), "Tokens not transferred from user");
    //     assertEq(
    //         bridgePreBal + tokenAmount, imxToken.balanceOf(address(rootBridge)), "Tokens not transferred to bridge"
    //     );
    //     // Check that native asset transferred to gas service
    //     assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
    //     assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    // }

    // // TODO split into multiple tests
    // function test_depositWETH() public {
    //     uint256 tokenAmount = 300;
    //     string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    //     (, bytes memory predictedPayload) =
    //         setupDeposit(WRAPPED_ETH, rootBridge, mapTokenFee, depositFee, tokenAmount, false);

    //     vm.expectEmit(address(axelarAdaptor));
    //     emit AxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
    //     vm.expectEmit(address(rootBridge));
    //     emit WETHDeposit(address(WRAPPED_ETH), rootBridge.childETHToken(), address(this), address(this), tokenAmount);
    //     vm.expectCall(
    //         address(axelarAdaptor),
    //         depositFee,
    //         abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
    //     );

    //     vm.expectCall(
    //         address(axelarGasService),
    //         depositFee,
    //         abi.encodeWithSelector(
    //             axelarGasService.payNativeGasForContractCall.selector,
    //             address(axelarAdaptor),
    //             CHILD_CHAIN_NAME,
    //             childBridgeAdaptorString,
    //             predictedPayload,
    //             address(this)
    //         )
    //     );

    //     vm.expectCall(
    //         address(mockAxelarGateway),
    //         0,
    //         abi.encodeWithSelector(
    //             mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload
    //         )
    //     );

    //     uint256 thisPreBal = IERC20Metadata(WRAPPED_ETH).balanceOf(address(this));
    //     uint256 bridgePreBal = address(rootBridge).balance;

    //     uint256 thisNativePreBal = address(this).balance;
    //     uint256 gasServiceNativePreBal = address(axelarGasService).balance;

    //     rootBridge.deposit{value: depositFee}(IERC20Metadata(WRAPPED_ETH), tokenAmount);

    //     // Check that tokens are transferred
    //     assertEq(
    //         thisPreBal - tokenAmount,
    //         IERC20Metadata(WRAPPED_ETH).balanceOf(address(this)),
    //         "Tokens not transferred from user"
    //     );
    //     assertEq(bridgePreBal + tokenAmount, address(rootBridge).balance, "ETH not transferred to Bridge");
    //     // Check that native asset transferred to gas service
    //     assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH for fee not paid from user");
    //     assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    // }

    // // TODO split into multiple tests
    // function test_depositToken() public {
    //     uint256 tokenAmount = 300;
    //     string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    //     (address childToken, bytes memory predictedPayload) =
    //         setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, tokenAmount, true);

    //     vm.expectEmit(address(axelarAdaptor));
    //     emit AxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
    //     vm.expectEmit(address(rootBridge));
    //     emit ChildChainERC20Deposit(address(token), childToken, address(this), address(this), tokenAmount);

    //     vm.expectCall(
    //         address(axelarAdaptor),
    //         depositFee,
    //         abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
    //     );

    //     vm.expectCall(
    //         address(axelarGasService),
    //         depositFee,
    //         abi.encodeWithSelector(
    //             axelarGasService.payNativeGasForContractCall.selector,
    //             address(axelarAdaptor),
    //             CHILD_CHAIN_NAME,
    //             childBridgeAdaptorString,
    //             predictedPayload,
    //             address(this)
    //         )
    //     );

    //     vm.expectCall(
    //         address(mockAxelarGateway),
    //         0,
    //         abi.encodeWithSelector(
    //             mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload
    //         )
    //     );

    //     uint256 thisPreBal = token.balanceOf(address(this));
    //     uint256 bridgePreBal = token.balanceOf(address(rootBridge));

    //     uint256 thisNativePreBal = address(this).balance;
    //     uint256 gasServiceNativePreBal = address(axelarGasService).balance;

    //     rootBridge.deposit{value: depositFee}(token, tokenAmount);

    //     // Check that tokens are transferred
    //     assertEq(thisPreBal - tokenAmount, token.balanceOf(address(this)), "Tokens not transferred from user");
    //     assertEq(bridgePreBal + tokenAmount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
    //     // Check that native asset transferred to gas service
    //     assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
    //     assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    // }

    // // TODO split into multiple tests
    // function test_depositTo() public {
    //     uint256 tokenAmount = 300;
    //     address recipient = address(9876);
    //     string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    //     (address childToken, bytes memory predictedPayload) =
    //         setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, tokenAmount, recipient, true);

    //     vm.expectEmit(address(axelarAdaptor));
    //     emit AxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
    //     vm.expectEmit(address(rootBridge));
    //     emit ChildChainERC20Deposit(address(token), childToken, address(this), recipient, tokenAmount);

    //     vm.expectCall(
    //         address(axelarAdaptor),
    //         depositFee,
    //         abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
    //     );

    //     vm.expectCall(
    //         address(axelarGasService),
    //         depositFee,
    //         abi.encodeWithSelector(
    //             axelarGasService.payNativeGasForContractCall.selector,
    //             address(axelarAdaptor),
    //             CHILD_CHAIN_NAME,
    //             childBridgeAdaptorString,
    //             predictedPayload,
    //             address(this)
    //         )
    //     );

    //     vm.expectCall(
    //         address(mockAxelarGateway),
    //         0,
    //         abi.encodeWithSelector(
    //             mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload
    //         )
    //     );

    //     uint256 thisPreBal = token.balanceOf(address(this));
    //     uint256 bridgePreBal = token.balanceOf(address(rootBridge));

    //     uint256 thisNativePreBal = address(this).balance;
    //     uint256 gasServiceNativePreBal = address(axelarGasService).balance;

    //     rootBridge.depositTo{value: depositFee}(token, recipient, tokenAmount);

    //     // Check that tokens are transferred
    //     assertEq(thisPreBal - tokenAmount, token.balanceOf(address(this)), "Tokens not transferred from user");
    //     assertEq(bridgePreBal + tokenAmount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
    //     // Check that native asset transferred to gas service
    //     assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
    //     assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    // }
}
