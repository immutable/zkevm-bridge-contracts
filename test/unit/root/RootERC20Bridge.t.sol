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
    string constant CHILD_CHAIN_NAME = "test";
    address constant IMX_TOKEN = address(99);
    address constant ETH_TOKEN = address(0xeee);

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
        rootBridge.initialize(address(mockAxelarAdaptor), CHILD_BRIDGE, CHILD_BRIDGE_ADAPTOR, address(token), IMX_TOKEN, ETH_TOKEN);
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
        rootBridge.initialize(address(mockAxelarAdaptor), CHILD_BRIDGE, CHILD_BRIDGE_ADAPTOR, address(token), IMX_TOKEN, ETH_TOKEN);
    }

    function test_RevertIf_InitializeWithAZeroAddressRootAdapter() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(0), address(1), address(1), address(1), address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressChildBridge() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(0), address(1), address(1), address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressChildAdapter() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(1), address(0), address(1), address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressTokenTemplate() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(1), address(1), address(0), address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressIMXToken() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(1), address(1), address(1), address(0), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressETHToken() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), address(1), address(1), address(1), address(1), address(0));
    }

    function test_RevertIf_InitializeWithAZeroAddressAll() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(0), address(0), address(0), address(0), address(0), address(0));
    }

    /**
     * MAP TOKEN
     */

    function test_mapToken_EmitsTokenMappedEvent() public {
        uint256 mapTokenFee = 300;
        address childToken =
            Clones.predictDeterministicAddress(address(token), keccak256(abi.encodePacked(token)), CHILD_BRIDGE);

        vm.expectEmit(true, true, false, false, address(rootBridge));
        emit L1TokenMapped(address(token), childToken);

        rootBridge.mapToken{value: mapTokenFee}(token);
    }

    function test_mapToken_CallsAdaptor() public {
        uint256 mapTokenFee = 300;

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
        uint256 mapTokenFee = 300;
        address childToken =
            Clones.predictDeterministicAddress(address(token), keccak256(abi.encodePacked(token)), CHILD_BRIDGE);

        rootBridge.mapToken{value: mapTokenFee}(token);

        assertEq(rootBridge.rootTokenToChildToken(address(token)), childToken, "rootTokenToChildToken mapping not set");
    }

    function testFuzz_mapToken_UpdatesEthBalance(uint256 mapTokenFee) public {
        vm.assume(mapTokenFee < address(this).balance);
        vm.assume(mapTokenFee > 0);
        uint256 thisPreBal = address(this).balance;
        uint256 rootBridgePreBal = address(rootBridge).balance;
        uint256 adaptorPreBal = address(mockAxelarAdaptor).balance;

        rootBridge.mapToken{value: mapTokenFee}(token);

        /*
         * Because this is a unit test, the adaptor is mocked. This adaptor would typically
         * pay the ETH to the gas service, but in this mocked case it will keep the ETH.
         */

        // User pays
        assertEq(address(this).balance, thisPreBal - mapTokenFee, "ETH balance not decreased");
        assertEq(address(mockAxelarAdaptor).balance, adaptorPreBal + mapTokenFee, "ETH not paid to adaptor");
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
        console2.log('test_depositETHCallsSendMessage');
        uint256 amount = 100;
        (, bytes memory predictedPayload) = setupDeposit(ERC20PresetMinterPauser(ETH_TOKEN), rootBridge, 0, amount, false);

        vm.expectCall(
            address(mockAxelarAdaptor),
            0,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositETH{value: amount}();
    }

    function test_depositEmitsNativeDepositEvent() public {
        uint256 amount = 100;
        (address childToken,) = setupDeposit(ERC20PresetMinterPauser(ETH_TOKEN), rootBridge, 0, amount, false);

        vm.expectEmit();
        emit NativeDeposit(address(token), childToken, address(this), address(this), amount);
        rootBridge.depositETH{value: amount}();
    }

    /**
     * DEPOSIT TOKEN
     */

    function test_depositCallsSendMessage() public {
        uint256 amount = 100;
        (, bytes memory predictedPayload) = setupDeposit(token, rootBridge, 0, amount, true);

        vm.expectCall(
            address(mockAxelarAdaptor),
            0,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.deposit(token, amount);
    }

    function test_depositEmitsERC20DepositEvent() public {
        uint256 amount = 100;
        (address childToken,) = setupDeposit(token, rootBridge, 0, amount, true);

        vm.expectEmit();
        emit ERC20Deposit(address(token), childToken, address(this), address(this), amount);
        rootBridge.deposit(token, amount);
    }

    function test_depositIMXEmitsIMXDepositEvent() public {
        uint256 amount = 100;

        setupDeposit(ERC20PresetMinterPauser(IMX_TOKEN), rootBridge, 0, amount, false);

        vm.expectEmit();
        emit IMXDeposit(IMX_TOKEN, address(this), address(this), amount);
        rootBridge.deposit(IERC20Metadata(IMX_TOKEN), amount);
    }

    function test_depositTransfersTokens() public {
        uint256 amount = 100;

        setupDeposit(token, rootBridge, 0, amount, true);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        rootBridge.deposit(token, amount);

        // Check that tokens are transferred
        assertEq(thisPreBal - amount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(bridgePreBal + amount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
    }

    function test_depositTransfersNativeAsset() public {
        uint256 gasPrice = 300;
        uint256 amount = 100;
        setupDeposit(token, rootBridge, 0, amount, true);

        uint256 thisNativePreBal = address(this).balance;
        uint256 adaptorNativePreBal = address(mockAxelarAdaptor).balance;

        rootBridge.deposit{value: gasPrice}(token, amount);

        // Check that native asset transferred to adaptor
        // In this case, because the adaptor is mocked, gas payment goes to the adaptor.
        assertEq(thisNativePreBal - gasPrice, address(this).balance, "ETH not paid from user");
        assertEq(adaptorNativePreBal + gasPrice, address(mockAxelarAdaptor).balance, "ETH not paid to adaptor");
    }

    function test_RevertIf_depositCalledWithZeroAddress() public {
        uint256 amount = 100;
        setupDeposit(token, rootBridge, 0, amount, true);

        // Will fail when it tries to call balanceOf
        vm.expectRevert();
        rootBridge.deposit(IERC20Metadata(address(0)), 100);
    }

    function test_RevertIf_depositCalledWithUnmappedToken() public {
        uint256 amount = 100;
        setupDeposit(token, rootBridge, 0, amount, true);

        ERC20PresetMinterPauser newToken = new ERC20PresetMinterPauser("Test", "TST");

        vm.expectRevert(NotMapped.selector);
        rootBridge.deposit(newToken, 100);
    }

    // We want to ensure that messages don't get sent when they are not supposed to
    function test_RevertIf_depositCalledWhenTokenApprovalNotProvided() public {
        uint256 amount = 100;
        setupDeposit(token, rootBridge, 0, amount, true);

        vm.expectRevert();
        rootBridge.deposit(token, amount * 2);
    }

    /**
     * DEPOSITTO
     */

    function test_depositToCallsSendMessage() public {
        uint256 amount = 100;
        address receiver = address(12345);

        (, bytes memory predictedPayload) = setupDepositTo(token, rootBridge, 0, amount, receiver, true);

        vm.expectCall(
            address(mockAxelarAdaptor),
            0,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositTo(token, receiver, amount);
    }

    function test_depositToEmitsERC20DepositEvent() public {
        uint256 amount = 100;
        address receiver = address(12345);

        (address childToken,) = setupDepositTo(token, rootBridge, 0, amount, receiver, true);

        vm.expectEmit();
        emit ERC20Deposit(address(token), childToken, address(this), receiver, amount);
        rootBridge.depositTo(token, receiver, amount);
    }

    function test_depositToIMXEmitsIMXDepositEvent() public {
        uint256 amount = 100;

        address receiver = address(12345);

        setupDepositTo(ERC20PresetMinterPauser(IMX_TOKEN), rootBridge, 0, amount, receiver, false);

        vm.expectEmit();
        emit IMXDeposit(IMX_TOKEN, address(this), receiver, amount);
        rootBridge.depositTo(IERC20Metadata(IMX_TOKEN), receiver, amount);
    }

    function test_depositToTransfersTokens() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, 0, amount, receiver, true);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        rootBridge.depositTo(token, receiver, amount);

        // Check that tokens are transferred
        assertEq(thisPreBal - amount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(bridgePreBal + amount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
    }

    function test_depositToTransfersNativeAsset() public {
        uint256 gasPrice = 300;
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, gasPrice, amount, receiver, true);

        uint256 thisNativePreBal = address(this).balance;
        uint256 adaptorNativePreBal = address(mockAxelarAdaptor).balance;

        rootBridge.depositTo{value: gasPrice}(token, receiver, amount);

        // Check that native asset transferred to adaptor
        // In this case, because the adaptor is mocked, gas payment goes to the adaptor.
        assertEq(thisNativePreBal - gasPrice, address(this).balance, "ETH not paid from user");
        assertEq(adaptorNativePreBal + gasPrice, address(mockAxelarAdaptor).balance, "ETH not paid to adaptor");
    }

    // We want to ensure that messages don't get sent when they are not supposed to
    function test_RevertIf_depositToCalledWhenTokenApprovalNotProvided() public {
        uint256 amount = 100;
        address receiver = address(12345);
        setupDepositTo(token, rootBridge, 0, amount, receiver, true);

        vm.expectRevert();
        rootBridge.depositTo(token, receiver, amount * 2);
    }

    function test_RevertIf_depositToCalledWithZeroAddress() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, 0, amount, receiver, true);

        // Will fail when it tries to call balanceOf
        vm.expectRevert();
        rootBridge.depositTo(IERC20Metadata(address(0)), receiver, 100);
    }

    function test_RevertIf_depositToCalledWithUnmappedToken() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(token, rootBridge, 0, amount, receiver, true);

        ERC20PresetMinterPauser newToken = new ERC20PresetMinterPauser("Test", "TST");

        vm.expectRevert(NotMapped.selector);
        rootBridge.depositTo(newToken, receiver, 100);
    }
}
