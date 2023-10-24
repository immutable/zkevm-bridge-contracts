// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../src/test/root/MockAxelarGasService.sol";
import {RootERC20Bridge, IRootERC20BridgeEvents, IERC20Metadata} from "../../../src/root/RootERC20Bridge.sol";
import {RootAxelarBridgeAdaptor, IRootAxelarBridgeAdaptorEvents} from "../../../src/root/RootAxelarBridgeAdaptor.sol";
import {Utils} from "../../utils.t.sol";

contract RootERC20BridgeIntegrationTest is Test, IRootERC20BridgeEvents, IRootAxelarBridgeAdaptorEvents, Utils {
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string constant CHILD_CHAIN_NAME = "test";
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    address constant IMX_TOKEN_ADDRESS = address(0xccc);
    address constant CHILD_ETH_TOKEN = address(0xddd);
    uint256 constant mapTokenFee = 300;
    uint256 constant depositFee = 200;

    ERC20PresetMinterPauser public token;
    RootERC20Bridge public rootBridge;
    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    function setUp() public {
        (token, rootBridge, axelarAdaptor, mockAxelarGateway, axelarGasService) =
            integrationSetup(CHILD_BRIDGE, CHILD_BRIDGE_ADAPTOR, CHILD_CHAIN_NAME, IMX_TOKEN_ADDRESS, CHILD_ETH_TOKEN);
    }

    /**
     * @dev A future test will assert that the computed childToken is the same as what gets deployed on L2.
     *      This test uses the same code as the mapToken function does to calculate this address, so we can
     *      not consider it sufficient.
     */
    function test_mapToken() public {
        // TODO split this up into multiple tests.
        address childToken =
            Clones.predictDeterministicAddress(address(token), keccak256(abi.encodePacked(token)), CHILD_BRIDGE);

        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        vm.expectEmit(true, true, true, false, address(axelarAdaptor));
        emit MapTokenAxelarMessage(CHILD_CHAIN_NAME, Strings.toHexString(CHILD_BRIDGE_ADAPTOR), payload);

        vm.expectEmit(true, true, false, false, address(rootBridge));
        emit L1TokenMapped(address(token), childToken);

        // Instead of using expectCalls, we could use expectEmit in combination with mock contracts emitting events.
        // expectCalls requires less boilerplate and is less dependant on mock code.
        vm.expectCall(
            address(axelarAdaptor),
            mapTokenFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, payload, address(this))
        );

        // These are calls that the axelarAdaptor should make.
        vm.expectCall(
            address(axelarGasService),
            mapTokenFee,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                CHILD_CHAIN_NAME,
                Strings.toHexString(CHILD_BRIDGE_ADAPTOR),
                payload,
                address(this)
            )
        );

        vm.expectCall(
            address(mockAxelarGateway),
            0,
            abi.encodeWithSelector(
                mockAxelarGateway.callContract.selector,
                CHILD_CHAIN_NAME,
                Strings.toHexString(CHILD_BRIDGE_ADAPTOR),
                payload
            )
        );

        // Check that we pay mapTokenFee to the axelarGasService.
        uint256 thisPreBal = address(this).balance;
        uint256 axelarGasServicePreBal = address(axelarGasService).balance;

        rootBridge.mapToken{value: mapTokenFee}(token);

        // Should update ETH balances as gas payment for message.
        assertEq(address(this).balance, thisPreBal - mapTokenFee, "ETH balance not decreased");
        assertEq(address(axelarGasService).balance, axelarGasServicePreBal + mapTokenFee, "ETH not paid to gas service");

        assertEq(rootBridge.rootTokenToChildToken(address(token)), childToken, "childToken not set");
    }

    // TODO split into multiple tests
    function test_depositToken() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (address childToken, bytes memory predictedPayload) =
            setupDeposit(token, rootBridge, mapTokenFee, depositFee, tokenAmount, true);

        vm.expectEmit(address(axelarAdaptor));
        emit MapTokenAxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
        vm.expectEmit(address(rootBridge));
        emit ERC20Deposit(address(token), childToken, address(this), address(this), tokenAmount);

        vm.expectCall(
            address(axelarAdaptor),
            depositFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        vm.expectCall(
            address(axelarGasService),
            depositFee,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                CHILD_CHAIN_NAME,
                childBridgeAdaptorString,
                predictedPayload,
                address(this)
            )
        );

        vm.expectCall(
            address(mockAxelarGateway),
            0,
            abi.encodeWithSelector(
                mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload
            )
        );

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        uint256 thisNativePreBal = address(this).balance;
        uint256 gasServiceNativePreBal = address(axelarGasService).balance;

        rootBridge.deposit{value: depositFee}(token, tokenAmount);

        // Check that tokens are transferred
        assertEq(thisPreBal - tokenAmount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(bridgePreBal + tokenAmount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
        // Check that native asset transferred to gas service
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
        assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    }

    // TODO split into multiple tests
    function test_depositTo() public {
        uint256 tokenAmount = 300;
        address recipient = address(9876);
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (address childToken, bytes memory predictedPayload) =
            setupDepositTo(token, rootBridge, mapTokenFee, depositFee, tokenAmount, recipient, true);

        vm.expectEmit(address(axelarAdaptor));
        emit MapTokenAxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
        vm.expectEmit(address(rootBridge));
        emit ERC20Deposit(address(token), childToken, address(this), recipient, tokenAmount);

        vm.expectCall(
            address(axelarAdaptor),
            depositFee,
            abi.encodeWithSelector(axelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        vm.expectCall(
            address(axelarGasService),
            depositFee,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                CHILD_CHAIN_NAME,
                childBridgeAdaptorString,
                predictedPayload,
                address(this)
            )
        );

        vm.expectCall(
            address(mockAxelarGateway),
            0,
            abi.encodeWithSelector(
                mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload
            )
        );

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        uint256 thisNativePreBal = address(this).balance;
        uint256 gasServiceNativePreBal = address(axelarGasService).balance;

        rootBridge.depositTo{value: depositFee}(token, recipient, tokenAmount);

        // Check that tokens are transferred
        assertEq(thisPreBal - tokenAmount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(bridgePreBal + tokenAmount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
        // Check that native asset transferred to gas service
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
        assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    }
}
