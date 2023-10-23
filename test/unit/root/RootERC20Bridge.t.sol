// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    RootERC20Bridge,
    IRootERC20BridgeEvents,
    IERC20Metadata,
    IRootERC20BridgeErrors
} from "../../../src/root/RootERC20Bridge.sol";
import {MockAxelarGateway} from "../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../src/test/root/MockAxelarGasService.sol";
import {MockAdaptor} from "../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../utils.t.sol";

contract RootERC20BridgeUnitTest is Test, IRootERC20BridgeEvents, IRootERC20BridgeErrors, Utils {
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string CHILD_BRIDGE_ADAPTOR_STRING = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    string constant CHILD_CHAIN_NAME = "test";
    address constant IMX_TOKEN = address(99);
    address constant CHILD_ETH_TOKEN = address(0xddd);
    address constant NATIVE_TOKEN = address(0xeee);
    uint256 constant mapTokenFee = 300;
    uint256 constant depositFee = 200;

    ERC20PresetMinterPauser public token;
    RootERC20Bridge public rootBridge;
    MockAdaptor public mockAxelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        deployCodeTo("ERC20PresetMinterPauser.sol", abi.encode("ImmutableX", "IMX"), IMX_TOKEN);

        rootBridge = new RootERC20Bridge();
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();

        mockAxelarAdaptor = new MockAdaptor();

        // The specific ERC20 token template does not matter for these unit tests
        rootBridge.initialize(address(mockAxelarAdaptor), CHILD_BRIDGE, CHILD_BRIDGE_ADAPTOR_STRING, address(token), IMX_TOKEN, CHILD_ETH_TOKEN);
    }

    /**
     * INITIALIZE
     */

    function test_InitializeBridge() public {
        assertEq(address(rootBridge.rootBridgeAdaptor()), address(mockAxelarAdaptor), "bridgeAdaptor not set");
        assertEq(rootBridge.childERC20Bridge(), CHILD_BRIDGE, "childERC20Bridge not set");
        assertEq(rootBridge.childTokenTemplate(), address(token), "childTokenTemplate not set");
    }

    function test_RevertIfInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        rootBridge.initialize(address(mockAxelarAdaptor), CHILD_BRIDGE, CHILD_BRIDGE_ADAPTOR_STRING, address(token), IMX_TOKEN, CHILD_ETH_TOKEN);
    }

    function test_RevertIf_InitializeWithAZeroAddressRootAdapter() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(0), address(1), CHILD_BRIDGE_ADAPTOR_STRING, address(1), address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressChildBridge() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(0), CHILD_BRIDGE_ADAPTOR_STRING, address(1), address(1), address(1));
    }

    function test_RevertIf_InitializeWithEmptyChildAdapter() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(InvalidChildERC20BridgeAdaptor.selector);
        bridge.initialize(address(1), address(1), "", address(1), address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressTokenTemplate() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(1), CHILD_BRIDGE_ADAPTOR_STRING, address(0), address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressIMXToken() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(1), CHILD_BRIDGE_ADAPTOR_STRING, address(1), address(0), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressETHToken() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(1), CHILD_BRIDGE_ADAPTOR_STRING, address(1), address(1), address(0));
    }

    function test_RevertIf_InitializeWithAZeroAddressAll() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(0), address(0), "", address(0), address(0), address(0));
    }

    /**
     * MAP TOKEN
     */

    function test_mapToken_EmitsTokenMappedEvent() public {
        address childToken =
            Clones.predictDeterministicAddress(address(token), keccak256(abi.encodePacked(token)), CHILD_BRIDGE);

        vm.expectEmit(true, true, false, false, address(rootBridge));
        emit L1TokenMapped(address(token), childToken);

        rootBridge.mapToken{value: mapTokenFee}(token);
    }

    function test_mapToken_CallsAdaptor() public {

        bytes memory payload =
            abi.encode(rootBridge.MAP_TOKEN_SIG(), token, token.name(), token.symbol(), token.decimals());

        vm.expectCall(
            address(mockAxelarAdaptor),
            mapTokenFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, payload, address(this))
        );

        rootBridge.mapToken{value: mapTokenFee}(token);
    }

    function test_mapToken_SetsTokenMapping() public {
        address childToken =
            Clones.predictDeterministicAddress(address(token), keccak256(abi.encodePacked(token)), CHILD_BRIDGE);

        rootBridge.mapToken{value: mapTokenFee}(token);

        assertEq(rootBridge.rootTokenToChildToken(address(token)), childToken, "rootTokenToChildToken mapping not set");
    }

    function testFuzz_mapToken_UpdatesEthBalance(uint256 _mapTokenFee) public {
        vm.assume(_mapTokenFee < address(this).balance);
        vm.assume(_mapTokenFee > 0);
        uint256 thisPreBal = address(this).balance;
        uint256 rootBridgePreBal = address(rootBridge).balance;
        uint256 adaptorPreBal = address(mockAxelarAdaptor).balance;

        rootBridge.mapToken{value: _mapTokenFee}(token);

        /*
         * Because this is a unit test, the adaptor is mocked. This adaptor would typically
         * pay the ETH to the gas service, but in this mocked case it will keep the ETH.
         */

        // User pays
        assertEq(address(this).balance, thisPreBal - _mapTokenFee, "ETH balance not decreased");
        assertEq(address(mockAxelarAdaptor).balance, adaptorPreBal + _mapTokenFee, "ETH not paid to adaptor");
        assertEq(address(rootBridge).balance, rootBridgePreBal, "ETH balance not increased");
    }

    function test_RevertIf_mapTokenCalledWithZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        rootBridge.mapToken{value: 300}(IERC20Metadata(address(0)));
    }

    function test_RevertIf_mapTokenCalledTwice() public {
        rootBridge.mapToken{value: 300}(token);
        vm.expectRevert(AlreadyMapped.selector);
        rootBridge.mapToken{value: 300}(token);
    }

    function test_RevertIf_mapTokenCalledWithIMXAddress() public {
        vm.expectRevert(CantMapIMX.selector);
        rootBridge.mapToken{value: 300}(IERC20Metadata(IMX_TOKEN));
    }

    function test_updateRootBridgeAdaptor() public {
        address newAdaptorAddress = address(0x11111);

        assertEq(address(rootBridge.rootBridgeAdaptor()), address(mockAxelarAdaptor), "bridgeAdaptor not set");
        rootBridge.updateRootBridgeAdaptor(newAdaptorAddress);
        assertEq(address(rootBridge.rootBridgeAdaptor()), newAdaptorAddress, "bridgeAdaptor not updated");
    }

    function test_RevertIf_updateRootBridgeAdaptorCalledByNonOwner() public {
        vm.prank(address(0xf00f00));
        vm.expectRevert("Ownable: caller is not the owner");
        rootBridge.updateRootBridgeAdaptor(address(0x11111));
    }

    function test_RevertIf_updateRootBridgeAdaptorCalledWithZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        rootBridge.updateRootBridgeAdaptor(address(0));
    }

    /**
     * DEPOSIT ETH
     */

    function test_depositETHCallsSendMessage() public {
        uint256 amount = 1000;
        (, bytes memory predictedPayload) = setupDeposit(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositETH{value: amount+depositFee}(amount);
    }

    function test_depositETHEmitsNativeDepositEvent() public {
        uint256 amount = 1000;
        setupDeposit(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectEmit();
        emit NativeDeposit(NATIVE_TOKEN, CHILD_ETH_TOKEN, address(this), address(this), amount);
        rootBridge.depositETH{value: amount+depositFee}(amount);
    }

    function test_RevertIf_depositETHInsufficientValue() public {
        uint256 amount = 1000;
        setupDeposit(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(InsufficientValue.selector);
        rootBridge.depositETH{value: (amount/2)+depositFee}(amount);
    }

     /**
     * DEPOSIT TO ETH
     */

    function test_depositToETHCallsSendMessage() public {
        uint256 amount = 1000;
        address receiver = address(12345);
        (, bytes memory predictedPayload) = setupDepositTo(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, receiver, false);
        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositToETH{value: amount+depositFee}(receiver, amount);
    }

    function test_depositToETHEmitsNativeDepositEvent() public {
        uint256 amount = 1000;
        address receiver = address(12345);
        setupDepositTo(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        vm.expectEmit();
        emit NativeDeposit(NATIVE_TOKEN, CHILD_ETH_TOKEN, address(this), receiver, amount);
        rootBridge.depositToETH{value: amount+depositFee}(receiver, amount);
    }

    function test_RevertIf_depositToETHInsufficientValue() public {
        uint256 amount = 1000;
        address receiver = address(12345);
        setupDepositTo(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        vm.expectRevert(InsufficientValue.selector);
        rootBridge.depositToETH{value: (amount/2)+depositFee}(receiver, amount);
    }

    /**
     * ZERO AMOUNT
     */

    function test_RevertIf_depositETHAmountIsZero() public {
        uint256 amount = 0;
        setupDeposit(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.depositETH{value: amount+depositFee}(amount);
    }

    function test_RevertIf_depositToETHAmountIsZero() public {
        uint256 amount = 0;
        address receiver = address(12345);

        setupDeposit(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.depositToETH{value: amount+depositFee}(receiver, amount);
    }

    function test_RevertIf_depositAmountIsZero() public {
        uint256 amount = 0;
        setupDeposit(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.deposit{value: depositFee}(token, amount);
    }

    function test_RevertIf_depositToAmountIsZero() public {
        uint256 amount = 0;
        address receiver = address(12345);
        setupDeposit(ERC20PresetMinterPauser(NATIVE_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.depositTo{value: depositFee}(token, receiver, amount);
    }

    /**
     * DEPOSIT TOKEN
     */

    function test_depositCallsSendMessage() public {
        uint256 amount = 100;
        (, bytes memory predictedPayload) = setupDeposit(token, rootBridge, mapTokenFee, depositFee, amount, true);

        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.deposit{value: depositFee}(token, amount);
    }

    function test_depositEmitsERC20DepositEvent() public {
        uint256 amount = 100;
        (address childToken,) = setupDeposit(token, rootBridge, mapTokenFee, depositFee, amount, true);

        vm.expectEmit();
        emit ERC20Deposit(address(token), childToken, address(this), address(this), amount);
        rootBridge.deposit{value: depositFee}(token, amount);
    }

    function test_depositIMXEmitsIMXDepositEvent() public {
        uint256 amount = 100;

        setupDeposit(ERC20PresetMinterPauser(IMX_TOKEN), rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectEmit();
        emit IMXDeposit(IMX_TOKEN, address(this), address(this), amount);
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);
    }

    function test_depositTransfersTokens() public {
        uint256 amount = 100;

        setupDeposit(token, rootBridge, mapTokenFee, depositFee, amount, true);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        rootBridge.deposit{value: depositFee}(token, amount);

        // Check that tokens are transferred
        assertEq(thisPreBal - amount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(bridgePreBal + amount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
    }

    function test_depositTransfersNativeAsset() public {
        uint256 amount = 100;
        setupDeposit(token, rootBridge, mapTokenFee, depositFee, amount, true);

        uint256 thisNativePreBal = address(this).balance;
        uint256 adaptorNativePreBal = address(mockAxelarAdaptor).balance;

        rootBridge.deposit{value: depositFee}(token, amount);

        // Check that native asset transferred to adaptor
        // In this case, because the adaptor is mocked, gas payment goes to the adaptor.
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
        assertEq(adaptorNativePreBal + depositFee, address(mockAxelarAdaptor).balance, "ETH not paid to adaptor");
    }

    function test_RevertIf_depositCalledWithZeroAddress() public {
        uint256 amount = 100;
        setupDeposit(token, rootBridge, mapTokenFee, depositFee, amount, true);

        // Will fail when it tries to call balanceOf
        vm.expectRevert();
        rootBridge.deposit{value: depositFee}(IERC20Metadata(address(0)), amount);
    }

    function test_RevertIf_depositCalledWithUnmappedToken() public {
        uint256 amount = 100;
        setupDeposit(token, rootBridge, mapTokenFee, depositFee, amount, true);

        ERC20PresetMinterPauser newToken = new ERC20PresetMinterPauser("Test", "TST");

        vm.expectRevert(NotMapped.selector);
        rootBridge.deposit{value: depositFee}(newToken, amount);
    }

    // We want to ensure that messages don't get sent when they are not supposed to
    function test_RevertIf_depositCalledWhenTokenApprovalNotProvided() public {
        uint256 amount = 100;
        setupDeposit(token, rootBridge, mapTokenFee, depositFee, amount, true);

        vm.expectRevert();
        rootBridge.deposit{value: depositFee}(token, amount * 2);
    }

    /**
     * DEPOSITTO
     */

    function test_depositToCallsSendMessage() public {
        uint256 amount = 100;
        address receiver = address(12345);

        (, bytes memory predictedPayload) = setupDepositTo(token, rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositTo{value: depositFee}(token, receiver, amount);
    }

    function test_depositToEmitsERC20DepositEvent() public {
        uint256 amount = 100;
        address receiver = address(12345);

        (address childToken,) = setupDepositTo(token, rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        vm.expectEmit();
        emit ERC20Deposit(address(token), childToken, address(this), receiver, amount);
        rootBridge.depositTo{value: depositFee}(token, receiver, amount);
    }

    function test_depositToIMXEmitsIMXDepositEvent() public {
        uint256 amount = 100;

        address receiver = address(12345);

        setupDepositTo(ERC20PresetMinterPauser(IMX_TOKEN), rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        vm.expectEmit();
        emit IMXDeposit(IMX_TOKEN, address(this), receiver, amount);
        rootBridge.depositTo{value: depositFee}(IERC20Metadata(IMX_TOKEN), receiver, amount);
    }

    function test_depositToTransfersTokens() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        rootBridge.depositTo{value: depositFee}(token, receiver, amount);

        // Check that tokens are transferred
        assertEq(thisPreBal - amount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(bridgePreBal + amount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
    }

    function test_depositToTransfersNativeAsset() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        uint256 thisNativePreBal = address(this).balance;
        uint256 adaptorNativePreBal = address(mockAxelarAdaptor).balance;

        rootBridge.depositTo{value: depositFee}(token, receiver, amount);

        // Check that native asset transferred to adaptor
        // In this case, because the adaptor is mocked, gas payment goes to the adaptor.
        assertEq(thisNativePreBal - depositFee, address(this).balance, "ETH not paid from user");
        assertEq(adaptorNativePreBal + depositFee, address(mockAxelarAdaptor).balance, "ETH not paid to adaptor");
    }

    // We want to ensure that messages don't get sent when they are not supposed to
    function test_RevertIf_depositToCalledWhenTokenApprovalNotProvided() public {
        uint256 amount = 100;
        address receiver = address(12345);
        setupDepositTo(token, rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        vm.expectRevert();
        rootBridge.depositTo{value: depositFee}(token, receiver, amount * 2);
    }

    function test_RevertIf_depositToCalledWithZeroAddress() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        // Will fail when it tries to call balanceOf
        vm.expectRevert();
        rootBridge.depositTo{value: depositFee}(IERC20Metadata(address(0)), receiver, amount);
    }

    function test_RevertIf_depositToCalledWithUnmappedToken() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        ERC20PresetMinterPauser newToken = new ERC20PresetMinterPauser("Test", "TST");

        vm.expectRevert(NotMapped.selector);
        rootBridge.depositTo{value: depositFee}(newToken, receiver, amount);
    }
}
