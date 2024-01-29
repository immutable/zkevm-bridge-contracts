// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../../mocks/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../mocks/root/MockAxelarGasService.sol";
import {RootERC20Bridge, IRootERC20BridgeEvents, IERC20Metadata} from "../../../src/root/RootERC20Bridge.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {RootAxelarBridgeAdaptor, IRootAxelarBridgeAdaptorEvents} from "../../../src/root/RootAxelarBridgeAdaptor.sol";
import {Utils} from "../../utils.t.sol";

contract RootERC20BridgeFlowRateIntegrationTest is
    Test,
    IRootERC20BridgeEvents,
    IRootAxelarBridgeAdaptorEvents,
    Utils
{
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string constant CHILD_CHAIN_NAME = "test";
    address constant IMX_TOKEN_ADDRESS = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);
    uint256 constant UNLIMITED_DEPOSIT_LIMIT = 0;

    uint256 constant mapTokenFee = 300;
    uint256 constant depositFee = 200;

    ERC20PresetMinterPauser public token;
    ERC20PresetMinterPauser public imxToken;
    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;
    RootERC20BridgeFlowRate public rootBridgeFlowRate;

    function setUp() public {
        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        RootIntegration memory integration = rootIntegrationSetup(
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR,
            CHILD_CHAIN_NAME,
            IMX_TOKEN_ADDRESS,
            WRAPPED_ETH,
            UNLIMITED_DEPOSIT_LIMIT
        );

        imxToken = integration.imxToken;
        token = integration.token;
        rootBridgeFlowRate = integration.rootBridgeFlowRate;
        axelarAdaptor = integration.axelarAdaptor;
        mockAxelarGateway = integration.mockAxelarGateway;
        axelarGasService = integration.axelarGasService;
    }

    /**
     * @dev A future test will assert that the computed childToken is the same as what gets deployed on L2.
     *      This test uses the same code as the mapToken function does to calculate this address, so we can
     *      not consider it sufficient.
     */
    function test_mapTokenTransfersValue() public {
        address childToken =
            Clones.predictDeterministicAddress(address(token), keccak256(abi.encodePacked(token)), CHILD_BRIDGE);

        // Check that we pay mapTokenFee to the axelarGasService.
        uint256 thisPreBal = address(this).balance;
        uint256 axelarGasServicePreBal = address(axelarGasService).balance;

        rootBridgeFlowRate.mapToken{value: mapTokenFee}(token);

        // Should update ETH balances as gas payment for message.
        assertEq(address(this).balance, thisPreBal - mapTokenFee, "ETH balance not decreased");
        assertEq(address(axelarGasService).balance, axelarGasServicePreBal + mapTokenFee, "ETH not paid to gas service");

        assertEq(rootBridgeFlowRate.rootTokenToChildToken(address(token)), childToken, "childToken not set");
    }

    function test_mapTokenEmitsEvents() public {
        address childToken =
            Clones.predictDeterministicAddress(address(token), keccak256(abi.encodePacked(token)), CHILD_BRIDGE);

        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        vm.expectEmit(true, true, true, false, address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, Strings.toHexString(CHILD_BRIDGE_ADAPTOR), payload);

        vm.expectEmit(true, true, false, false, address(rootBridgeFlowRate));
        emit L1TokenMapped(address(token), childToken);

        rootBridgeFlowRate.mapToken{value: mapTokenFee}(token);
    }

    function test_mapTokenCallsAxelarServices() public {
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());

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

        rootBridgeFlowRate.mapToken{value: mapTokenFee}(token);
    }

    /**
     * DEPOSIT ETH
     */
    function test_depositETHTransfersValue() public {
        uint256 tokenAmount = 300;
        setupDeposit(NATIVE_ETH, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

        uint256 bridgePreBal = address(rootBridgeFlowRate).balance;

        uint256 thisNativePreBal = address(this).balance;
        uint256 gasServiceNativePreBal = address(axelarGasService).balance;

        rootBridgeFlowRate.depositETH{value: tokenAmount + depositFee}(tokenAmount);

        // Check that tokens are transferred
        assertEq(bridgePreBal + tokenAmount, address(rootBridgeFlowRate).balance, "ETH not transferred to bridge");
        // Check that native asset transferred to gas service
        assertEq(thisNativePreBal - (depositFee + tokenAmount), address(this).balance, "ETH not paid from user");
        assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    }

    function test_depositETHEmitsEvents() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);

        (, bytes memory predictedPayload) =
            setupDeposit(NATIVE_ETH, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
        vm.expectEmit(address(rootBridgeFlowRate));
        emit NativeEthDeposit(
            address(NATIVE_ETH), rootBridgeFlowRate.childETHToken(), address(this), address(this), tokenAmount
        );

        rootBridgeFlowRate.depositETH{value: tokenAmount + depositFee}(tokenAmount);
    }

    function test_depositETHCallsAxelarServices() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);

        (, bytes memory predictedPayload) =
            setupDeposit(NATIVE_ETH, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

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

        rootBridgeFlowRate.depositETH{value: tokenAmount + depositFee}(tokenAmount);
    }

    /**
     * DEPOSIT IMX
     */
    function test_depositIMXTokenTransfersValue() public {
        uint256 tokenAmount = 300;

        setupDeposit(IMX_TOKEN_ADDRESS, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

        uint256 thisPreBal = imxToken.balanceOf(address(this));
        uint256 bridgePreBal = imxToken.balanceOf(address(rootBridgeFlowRate));

        uint256 thisNativePreBal = address(this).balance;
        uint256 gasServiceNativePreBal = address(axelarGasService).balance;

        rootBridgeFlowRate.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN_ADDRESS), tokenAmount);

        // Check that tokens are transferred
        assertEq(thisPreBal - tokenAmount, imxToken.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(
            bridgePreBal + tokenAmount,
            imxToken.balanceOf(address(rootBridgeFlowRate)),
            "Tokens not transferred to bridge"
        );
        // Check that native asset transferred to gas service
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
        assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    }

    function test_depositIMXTokenEmitsEvents() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);

        (, bytes memory predictedPayload) =
            setupDeposit(IMX_TOKEN_ADDRESS, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
        vm.expectEmit(address(rootBridgeFlowRate));
        emit IMXDeposit(address(IMX_TOKEN_ADDRESS), address(this), address(this), tokenAmount);

        rootBridgeFlowRate.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN_ADDRESS), tokenAmount);
    }

    function test_depositIMXTokenCallsAxelarServices() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);

        (, bytes memory predictedPayload) =
            setupDeposit(IMX_TOKEN_ADDRESS, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

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

        rootBridgeFlowRate.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN_ADDRESS), tokenAmount);
    }

    /**
     * DEPOSIT WETH
     */
    function test_depositWETHTransfersValue() public {
        uint256 tokenAmount = 300;
        setupDeposit(WRAPPED_ETH, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

        uint256 thisPreBal = IERC20Metadata(WRAPPED_ETH).balanceOf(address(this));
        uint256 bridgePreBal = address(rootBridgeFlowRate).balance;

        uint256 thisNativePreBal = address(this).balance;
        uint256 gasServiceNativePreBal = address(axelarGasService).balance;

        rootBridgeFlowRate.deposit{value: depositFee}(IERC20Metadata(WRAPPED_ETH), tokenAmount);

        // Check that tokens are transferred
        assertEq(
            thisPreBal - tokenAmount,
            IERC20Metadata(WRAPPED_ETH).balanceOf(address(this)),
            "Tokens not transferred from user"
        );
        assertEq(bridgePreBal + tokenAmount, address(rootBridgeFlowRate).balance, "ETH not transferred to Bridge");
        // Check that native asset transferred to gas service
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH for fee not paid from user");
        assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    }

    function test_depositWETHEmitsEvents() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (, bytes memory predictedPayload) =
            setupDeposit(WRAPPED_ETH, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
        vm.expectEmit(address(rootBridgeFlowRate));
        emit WETHDeposit(
            address(WRAPPED_ETH), rootBridgeFlowRate.childETHToken(), address(this), address(this), tokenAmount
        );
        rootBridgeFlowRate.deposit{value: depositFee}(IERC20Metadata(WRAPPED_ETH), tokenAmount);
    }

    function test_depositWETHCallsAxelarServices() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (, bytes memory predictedPayload) =
            setupDeposit(WRAPPED_ETH, rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, false);

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

        rootBridgeFlowRate.deposit{value: depositFee}(IERC20Metadata(WRAPPED_ETH), tokenAmount);
    }

    /**
     * DEPOSIT TOKEN
     */
    function test_depositTokenTransfersValue() public {
        uint256 tokenAmount = 300;
        setupDeposit(address(token), rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, true);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridgeFlowRate));

        uint256 thisNativePreBal = address(this).balance;
        uint256 gasServiceNativePreBal = address(axelarGasService).balance;

        rootBridgeFlowRate.deposit{value: depositFee}(token, tokenAmount);

        // Check that tokens are transferred
        assertEq(thisPreBal - tokenAmount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(
            bridgePreBal + tokenAmount, token.balanceOf(address(rootBridgeFlowRate)), "Tokens not transferred to bridge"
        );
        // Check that native asset transferred to gas service
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
        assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    }

    function test_depositTokenEmitsEvents() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (address childToken, bytes memory predictedPayload) =
            setupDeposit(address(token), rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, true);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
        vm.expectEmit(address(rootBridgeFlowRate));
        emit ChildChainERC20Deposit(address(token), childToken, address(this), address(this), tokenAmount);

        rootBridgeFlowRate.deposit{value: depositFee}(token, tokenAmount);
    }

    function test_depositTokenCallsAxelarServices() public {
        uint256 tokenAmount = 300;
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (, bytes memory predictedPayload) =
            setupDeposit(address(token), rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, true);

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

        rootBridgeFlowRate.deposit{value: depositFee}(token, tokenAmount);
    }

    /**
     * DEPOSIT TO
     */
    function test_depositToTransfersValue() public {
        uint256 tokenAmount = 300;
        address recipient = address(9876);
        setupDepositTo(address(token), rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, recipient, true);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridgeFlowRate));

        uint256 thisNativePreBal = address(this).balance;
        uint256 gasServiceNativePreBal = address(axelarGasService).balance;

        rootBridgeFlowRate.depositTo{value: depositFee}(token, recipient, tokenAmount);

        // Check that tokens are transferred
        assertEq(thisPreBal - tokenAmount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(
            bridgePreBal + tokenAmount, token.balanceOf(address(rootBridgeFlowRate)), "Tokens not transferred to bridge"
        );
        // Check that native asset transferred to gas service
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
        assertEq(gasServiceNativePreBal + depositFee, address(axelarGasService).balance, "ETH not paid to adaptor");
    }

    function test_depositToEmitsEvents() public {
        uint256 tokenAmount = 300;
        address recipient = address(9876);
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (address childToken, bytes memory predictedPayload) =
            setupDepositTo(address(token), rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, recipient, true);

        vm.expectEmit(address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, childBridgeAdaptorString, predictedPayload);
        vm.expectEmit(address(rootBridgeFlowRate));
        emit ChildChainERC20Deposit(address(token), childToken, address(this), recipient, tokenAmount);

        rootBridgeFlowRate.depositTo{value: depositFee}(token, recipient, tokenAmount);
    }

    function test_depositToCallsAxelarServices() public {
        uint256 tokenAmount = 300;
        address recipient = address(9876);
        string memory childBridgeAdaptorString = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
        (, bytes memory predictedPayload) =
            setupDepositTo(address(token), rootBridgeFlowRate, mapTokenFee, depositFee, tokenAmount, recipient, true);

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

        rootBridgeFlowRate.depositTo{value: depositFee}(token, recipient, tokenAmount);
    }
}
