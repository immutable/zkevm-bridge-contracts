// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    RootERC20Bridge,
    IRootERC20BridgeEvents,
    IERC20Metadata,
    IRootERC20BridgeErrors,
    IRootERC20Bridge
} from "../../../src/root/RootERC20Bridge.sol";
import {MockAxelarGateway} from "../../mocks/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../mocks/root/MockAxelarGasService.sol";
import {MockAdaptor} from "../../mocks/root/MockAdaptor.sol";
import {Utils, IPausable} from "../../utils.t.sol";

contract ReentrancyAttackDeposit is ERC20PresetMinterPauser {
    IRootERC20Bridge bridge;

    constructor(address _bridge) ERC20PresetMinterPauser("Test", "TST") {
        bridge = IRootERC20Bridge(_bridge);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (msg.sender == address(bridge)) {
            bridge.deposit(IERC20Metadata(address(this)), amount);
        }

        return super.transferFrom(from, to, amount);
    }
}

contract RootERC20BridgeUnitTest is Test, IRootERC20BridgeEvents, IRootERC20BridgeErrors, Utils {
    address constant CHILD_BRIDGE = address(3);
    address constant IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);
    uint256 constant mapTokenFee = 300;
    uint256 constant depositFee = 200;
    uint256 constant UNLIMITED_IMX_DEPOSITS = 0;

    ERC20PresetMinterPauser public token;
    RootERC20Bridge public rootBridge;
    MockAdaptor public mockAxelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        deployCodeTo("ERC20PresetMinterPauser.sol", abi.encode("ImmutableX", "IMX"), IMX_TOKEN);

        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        rootBridge = new RootERC20Bridge();
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();

        mockAxelarAdaptor = new MockAdaptor();

        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: pauser,
            unpauser: unpauser,
            variableManager: address(this),
            adaptorManager: address(this)
        });

        // The specific ERC20 token template does not matter for these unit tests
        rootBridge.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            UNLIMITED_IMX_DEPOSITS
        );
    }

    /**
     * INITIALIZE
     */

    function test_InitializeBridge() public {
        assertEq(address(rootBridge.rootBridgeAdaptor()), address(mockAxelarAdaptor), "bridgeAdaptor not set");
        assertEq(rootBridge.childERC20Bridge(), CHILD_BRIDGE, "childERC20Bridge not set");
        assertEq(rootBridge.childTokenTemplate(), address(token), "childTokenTemplate not set");
        assertEq(address(token), rootBridge.childTokenTemplate(), "childTokenTemplate not set");
        assertEq(rootBridge.rootIMXToken(), IMX_TOKEN, "rootIMXToken not set");
        assertEq(rootBridge.rootWETHToken(), WRAPPED_ETH, "rootWETHToken not set");
        assert(rootBridge.rootTokenToChildToken(IMX_TOKEN) != address(0));
        assert(rootBridge.rootTokenToChildToken(NATIVE_ETH) != address(0));
        assert(rootBridge.rootTokenToChildToken(NATIVE_ETH) != address(0));
    }

    function test_NativeTransferFromWETH() public {
        address caller = address(0x123a);
        payable(caller).transfer(2 ether);
        // forge inspect src/root/RootERC20Bridge.sol:RootERC20Bridge storageLayout | grep -B3 -A5 -i "rootWETHToken"
        uint256 wETHStorageSlot = 307;
        vm.store(address(rootBridge), bytes32(wETHStorageSlot), bytes32(uint256(uint160(caller))));

        vm.startPrank(caller);
        uint256 bal = address(rootBridge).balance;
        (bool ok,) = address(rootBridge).call{value: 1 ether}("");
        assert(ok);
        uint256 postBal = address(rootBridge).balance;

        assertEq(bal + 1 ether, postBal, "balance not increased");
    }

    function test_RevertI_fNativeTransferIsFromNonWETH() public {
        vm.expectRevert(NonWrappedNativeTransfer.selector);
        (bool ok,) = address(rootBridge).call{value: 1 ether}("");
        assert(ok);
    }

    function test_RevertIf_NativeTransferWhenPaused() public {
        pause(IPausable(address(rootBridge)));
        vm.expectRevert("Pausable: paused");
        (bool ok,) = address(rootBridge).call{value: 1 ether}("");
        assert(ok);
    }

    function test_NativeTransferResumesFunctionalityAfterUnpausing() public {
        test_RevertIf_NativeTransferWhenPaused();
        unpause(IPausable(address(rootBridge)));
        // Expect success case to pass
        test_NativeTransferFromWETH();
    }

    function test_RevertIf_InitializeTwice() public {
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert("Initializable: contract is already initialized");
        rootBridge.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            UNLIMITED_IMX_DEPOSITS
        );
    }

    function test_RevertIf_InitializeWithAZeroAddressDefaultAdmin() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(0),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(1), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressPauser() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(0),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(1), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressUnpauser() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(0),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(1), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressVariableManager() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(0),
            adaptorManager: address(this)
        });
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(1), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressAdaptorManager() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(0)
        });
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(1), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressRootAdapter() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(0), address(1), address(1), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressChildBridge() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(0), address(1), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressTokenTemplate() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(0), address(1), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressIMXToken() public {
        RootERC20Bridge bridge = new RootERC20Bridge();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(1), address(0), address(1), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressWETHToken() public {
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), address(1), address(1), address(1), address(0), UNLIMITED_IMX_DEPOSITS);
    }

    function test_RevertIf_InitializeWithAZeroAddressAll() public {
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(0),
            pauser: address(0),
            unpauser: address(0),
            variableManager: address(0),
            adaptorManager: address(0)
        });
        RootERC20Bridge bridge = new RootERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(0), address(0), address(0), address(0), address(0), UNLIMITED_IMX_DEPOSITS);
    }

    /**
     * ON MESSAGE RECEIVED
     */
    function test_RevertsIf_OnMessageReceivedWhenPaused() public {
        pause(IPausable(address(rootBridge)));
        bytes memory data = abi.encode(WITHDRAW_SIG, token, address(this), address(this), 1000);
        vm.expectRevert("Pausable: paused");
        rootBridge.onMessageReceive(data);
    }

    function test_OnMessageReceiveResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_OnMessageReceivedWhenPaused();
        unpause(IPausable(address(rootBridge)));
        // Expect revert on standard flow, not on pause
        vm.expectRevert(NotBridgeAdaptor.selector);
        bytes memory data = abi.encode(WITHDRAW_SIG, token, address(this), address(this), 1000);
        rootBridge.onMessageReceive(data);
    }

    /**
     * UPDATE IMX CUMULATIVE DEPOSIT LIMIT
     */
    function test_RevertsIf_IMXDepositLimitTooLow() public {
        uint256 imxCumulativeDepositLimit = 700;
        uint256 depositAmount = imxCumulativeDepositLimit + 1;

        rootBridge.updateImxCumulativeDepositLimit(imxCumulativeDepositLimit);

        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, depositAmount, false);

        IERC20Metadata(IMX_TOKEN).approve(address(rootBridge), type(uint256).max);

        rootBridge.updateImxCumulativeDepositLimit(depositAmount);

        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), depositAmount);

        vm.expectRevert(ImxDepositLimitTooLow.selector);
        rootBridge.updateImxCumulativeDepositLimit(imxCumulativeDepositLimit);
    }

    function test_RevertIf_updateImxCumulativeDepositLimitCalledByNonOwner() public {
        uint256 imxCumulativeDepositLimit = 700;
        vm.prank(address(0xf00f00));
        vm.expectRevert();
        rootBridge.updateImxCumulativeDepositLimit(imxCumulativeDepositLimit);
    }

    /**
     * MAP TOKEN
     */

    function test_RevertsIf_MapTokenWhenPaused() public {
        pause(IPausable(address(rootBridge)));
        vm.expectRevert("Pausable: paused");
        rootBridge.mapToken(token);
    }

    function test_MapTokenResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_MapTokenWhenPaused();
        unpause(IPausable(address(rootBridge)));
        // Expect success case to pass
        test_mapToken_EmitsTokenMappedEvent();
    }

    function test_RevertsIf_MapTokenCalledWithZeroFee() public {
        vm.expectRevert(NoGas.selector);
        rootBridge.mapToken(token);
    }

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

    function test_RevertIf_mapTokenCalledWithETHAddress() public {
        vm.expectRevert(CantMapETH.selector);
        rootBridge.mapToken{value: 300}(IERC20Metadata(NATIVE_ETH));
    }

    function test_SucceedIf_mapTokenWithSupportedMethods() public {
        rootBridge.mapToken{value: 300}(token);
    }

    function test_RevertIf_mapTokenWithoutName() public {
        vm.mockCallRevert(address(token), abi.encodeWithSelector(IERC20Metadata.name.selector), "Unsupported operation");
        vm.expectRevert(TokenNotSupported.selector);
        rootBridge.mapToken{value: 300}(token);
    }

    function test_RevertIf_mapTokenWithoutSymbol() public {
        vm.mockCallRevert(
            address(token), abi.encodeWithSelector(IERC20Metadata.symbol.selector), "Unsupported operation"
        );
        vm.expectRevert(TokenNotSupported.selector);
        rootBridge.mapToken{value: 300}(token);
    }

    function test_RevertIf_mapTokenWithoutDecimals() public {
        vm.mockCallRevert(
            address(token), abi.encodeWithSelector(IERC20Metadata.decimals.selector), "Unsupported operation"
        );
        vm.expectRevert(TokenNotSupported.selector);
        rootBridge.mapToken{value: 300}(token);
    }

    function test_updateRootBridgeAdaptor_UpdatesRootBridgeAdaptor() public {
        address newAdaptorAddress = address(0x11111);

        assertEq(address(rootBridge.rootBridgeAdaptor()), address(mockAxelarAdaptor), "bridgeAdaptor not set");
        rootBridge.updateRootBridgeAdaptor(newAdaptorAddress);
        assertEq(address(rootBridge.rootBridgeAdaptor()), newAdaptorAddress, "bridgeAdaptor not updated");
    }

    function test_updateRootBridgeAdaptor_EmitsRootBridgeAdaptorUpdatedEvent() public {
        address newAdaptorAddress = address(0x11111);

        vm.expectEmit();
        emit RootBridgeAdaptorUpdated(address(rootBridge.rootBridgeAdaptor()), newAdaptorAddress);

        rootBridge.updateRootBridgeAdaptor(newAdaptorAddress);
    }

    function test_RevertIf_updateRootBridgeAdaptorCalledByNonOwner() public {
        address caller = address(0xf00f00);
        bytes32 role = rootBridge.ADAPTOR_MANAGER_ROLE();
        vm.prank(caller);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(caller),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        rootBridge.updateRootBridgeAdaptor(address(0x11111));
    }

    function test_RevertIf_updateRootBridgeAdaptorCalledWithZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        rootBridge.updateRootBridgeAdaptor(address(0));
    }

    /**
     * DEPOSIT ETH
     */

    function test_RevertsIf_DepositETHWhenPaused() public {
        pause(IPausable(address(rootBridge)));
        vm.expectRevert("Pausable: paused");
        rootBridge.depositETH{value: 1000}(1000);
    }

    function test_DepositETHResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_DepositETHWhenPaused();
        unpause(IPausable(address(rootBridge)));
        // Expect success case to pass
        test_depositETHCallsSendMessage();
    }

    function test_depositETHCallsSendMessage() public {
        uint256 amount = 1000;
        (, bytes memory predictedPayload) = setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositETH{value: amount + depositFee}(amount);
    }

    function test_depositETHEmitsNativeEthDepositEvent() public {
        uint256 amount = 1000;
        setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectEmit();
        emit NativeEthDeposit(NATIVE_ETH, rootBridge.childETHToken(), address(this), address(this), amount);
        rootBridge.depositETH{value: amount + depositFee}(amount);
    }

    function test_RevertIf_depositETHInsufficientValue() public {
        uint256 amount = 1000;
        setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(InsufficientValue.selector);
        rootBridge.depositETH{value: (amount / 2) + depositFee}(amount);
    }

    /**
     * DEPOSIT TO ETH
     */

    function test_RevertsIf_DepositToETHWhenPaused() public {
        pause(IPausable(address(rootBridge)));
        vm.expectRevert("Pausable: paused");
        rootBridge.depositToETH{value: 1000}(address(this), 1000);
    }

    function test_DepositToETHResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_DepositToETHWhenPaused();
        unpause(IPausable(address(rootBridge)));
        // Expect success case to pass
        test_depositToETHCallsSendMessage();
    }

    function test_depositToETHCallsSendMessage() public {
        uint256 amount = 1000;
        address receiver = address(12345);
        (, bytes memory predictedPayload) =
            setupDepositTo(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, receiver, false);
        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositToETH{value: amount + depositFee}(receiver, amount);
    }

    function test_depositToETHEmitsNativeEthDepositEvent() public {
        uint256 amount = 1000;
        address receiver = address(12345);
        setupDepositTo(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        vm.expectEmit();
        emit NativeEthDeposit(NATIVE_ETH, rootBridge.childETHToken(), address(this), receiver, amount);
        rootBridge.depositToETH{value: amount + depositFee}(receiver, amount);
    }

    function test_RevertIf_depositToETHInsufficientValue() public {
        uint256 amount = 1000;
        address receiver = address(12345);
        setupDepositTo(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        vm.expectRevert(InsufficientValue.selector);
        rootBridge.depositToETH{value: (amount / 2) + depositFee}(receiver, amount);
    }

    /**
     * ZERO AMOUNT
     */

    function test_RevertIf_depositETHAmountIsZero() public {
        uint256 amount = 0;
        setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.depositETH{value: amount + depositFee}(amount);
    }

    function test_RevertIf_depositToETHAmountIsZero() public {
        uint256 amount = 0;
        address receiver = address(12345);

        setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.depositToETH{value: amount + depositFee}(receiver, amount);
    }

    function test_RevertIf_depositAmountIsZero() public {
        uint256 amount = 0;
        setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.deposit{value: depositFee}(token, amount);
    }

    function test_RevertIf_depositToAmountIsZero() public {
        uint256 amount = 0;
        address receiver = address(12345);
        setupDeposit(NATIVE_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectRevert(ZeroAmount.selector);
        rootBridge.depositTo{value: depositFee}(token, receiver, amount);
    }

    /**
     * DEPOSIT WETH
     */

    function test_depositWETHCallsSendMessage() public {
        uint256 amount = 100;
        (, bytes memory predictedPayload) =
            setupDeposit(WRAPPED_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectCall(
            address(mockAxelarAdaptor),
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.deposit{value: depositFee}(IERC20Metadata(WRAPPED_ETH), amount);
    }

    function test_depositWETHEmitsNativeDepositEvent() public {
        uint256 amount = 100;
        setupDeposit(WRAPPED_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectEmit();
        emit WETHDeposit(WRAPPED_ETH, rootBridge.childETHToken(), address(this), address(this), amount);
        rootBridge.deposit{value: depositFee}(IERC20Metadata(WRAPPED_ETH), amount);
    }

    function test_depositToWETHEmitsWETHDepositEvent() public {
        uint256 amount = 1000;
        address receiver = address(12345);
        setupDepositTo(WRAPPED_ETH, rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        vm.expectEmit();
        emit WETHDeposit(WRAPPED_ETH, rootBridge.childETHToken(), address(this), receiver, amount);
        rootBridge.depositTo{value: depositFee}(IERC20Metadata(WRAPPED_ETH), receiver, amount);
    }

    function test_depositWETHTransfersTokens() public {
        uint256 amount = 100;

        setupDeposit(WRAPPED_ETH, rootBridge, mapTokenFee, depositFee, amount, false);

        uint256 thisPreBal = IERC20Metadata(WRAPPED_ETH).balanceOf(address(this));
        uint256 bridgePreBal = address(rootBridge).balance;

        rootBridge.deposit{value: depositFee}(IERC20Metadata(WRAPPED_ETH), amount);

        // Check that tokens are transferred
        assertEq(
            thisPreBal - amount,
            IERC20Metadata(WRAPPED_ETH).balanceOf(address(this)),
            "Tokens not transferred from user"
        );
        assertEq(bridgePreBal + amount, address(rootBridge).balance, "ETH not transferred to Bridge");
    }

    function test_depositToWETHTransfersTokens() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(WRAPPED_ETH, rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        uint256 thisPreBal = IERC20Metadata(WRAPPED_ETH).balanceOf(address(this));
        uint256 bridgePreBal = address(rootBridge).balance;

        rootBridge.depositTo{value: depositFee}(IERC20Metadata(WRAPPED_ETH), receiver, amount);

        // Check that tokens are transferred
        assertEq(
            thisPreBal - amount,
            IERC20Metadata(WRAPPED_ETH).balanceOf(address(this)),
            "Tokens not transferred from user"
        );
        assertEq(bridgePreBal + amount, address(rootBridge).balance, "ETH not transferred to Bridge");
    }

    /**
     * DEPOSIT TOKEN
     */

    function test_RevertsIf_DepositReentered() public {
        // Create attack token
        ReentrancyAttackDeposit attackToken = new ReentrancyAttackDeposit(address(rootBridge));

        // Map
        {
            // Found by running `forge inspect src/root/RootERC20Bridge.sol:RootERC20Bridge storageLayout | grep -B3 -A5 -i "rootTokenToChildToken"`
            uint256 rootTokenToChildTokenMappingSlot = 301;
            bytes32 slot = getMappingStorageSlotFor(address(attackToken), rootTokenToChildTokenMappingSlot);
            bytes32 data = bytes32(uint256(uint160(address(attackToken))));
            vm.store(address(rootBridge), slot, data);
        }

        // Approve and mint
        address attacker = makeAddr("attacker");
        ERC20PresetMinterPauser(address(attackToken)).mint(attacker, 10000);
        vm.startPrank(attacker);
        vm.deal(attacker, 10 ether);
        ERC20PresetMinterPauser(address(attackToken)).approve(address(rootBridge), type(uint256).max);

        // Deposit
        vm.expectRevert("ReentrancyGuard: reentrant call");
        rootBridge.deposit{value: depositFee}(IERC20Metadata(address(attackToken)), 100);
    }

    function test_RevertsIf_DepositTokenWhenPaused() public {
        uint256 amount = 100;
        pause(IPausable(address(rootBridge)));
        vm.expectRevert("Pausable: paused");
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);
    }

    function test_DepositTokenResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_DepositTokenWhenPaused();
        unpause(IPausable(address(rootBridge)));
        // Expect success case to pass
        test_depositCallsSendMessage();
    }

    function test_RevertsIf_DepositTokenWithZeroFee() public {
        uint256 amount = 100;
        vm.expectRevert(NoGas.selector);
        rootBridge.deposit(IERC20Metadata(IMX_TOKEN), amount);
    }

    function test_RevertsIf_IMXDepositLimitExceeded() public {
        uint256 imxCumulativeDepositLimit = 700;

        uint256 amount = 300;
        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, false);

        IERC20Metadata(IMX_TOKEN).approve(address(rootBridge), type(uint256).max);

        rootBridge.updateImxCumulativeDepositLimit(imxCumulativeDepositLimit);

        // Valid
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);

        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, false);
        // Valid
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);

        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, false);
        // Invalid
        vm.expectRevert(ImxDepositLimitExceeded.selector);
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);
    }

    function test_deposit_whenSettingImxDepositLimitToUnlimited() public {
        uint256 imxCumulativeDepositLimit = 700;

        uint256 amount = 300;
        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, false);

        IERC20Metadata(IMX_TOKEN).approve(address(rootBridge), type(uint256).max);

        rootBridge.updateImxCumulativeDepositLimit(imxCumulativeDepositLimit);

        // Valid
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);

        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, false);
        // Valid
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);

        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, false);
        // Invalid
        vm.expectRevert(ImxDepositLimitExceeded.selector);
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);

        rootBridge.updateImxCumulativeDepositLimit(UNLIMITED_IMX_DEPOSITS);

        uint256 bigDepositAmount = 999999999999 ether;
        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, bigDepositAmount, false);

        uint256 thisPreBal = IERC20Metadata(IMX_TOKEN).balanceOf(address(this));
        uint256 bridgePreBal = IERC20Metadata(IMX_TOKEN).balanceOf(address(rootBridge));

        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), bigDepositAmount);

        // Check that tokens are transferred
        assertEq(
            thisPreBal - bigDepositAmount,
            IERC20Metadata(IMX_TOKEN).balanceOf(address(this)),
            "Tokens not transferred from user"
        );
        assertEq(
            bridgePreBal + bigDepositAmount,
            IERC20Metadata(IMX_TOKEN).balanceOf(address(rootBridge)),
            "Tokens not transferred to bridge"
        );
    }

    function test_depositCallsSendMessage() public {
        uint256 amount = 100;
        (, bytes memory predictedPayload) =
            setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, amount, true);

        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.deposit{value: depositFee}(token, amount);
    }

    function test_depositEmitsChildChainERC20DepositEvent() public {
        uint256 amount = 100;
        (address childToken,) = setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, amount, true);

        vm.expectEmit();
        emit ChildChainERC20Deposit(address(token), childToken, address(this), address(this), amount);
        rootBridge.deposit{value: depositFee}(token, amount);
    }

    function test_depositIMXEmitsIMXDepositEvent() public {
        uint256 amount = 100;

        setupDeposit(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, false);

        vm.expectEmit();
        emit IMXDeposit(IMX_TOKEN, address(this), address(this), amount);
        rootBridge.deposit{value: depositFee}(IERC20Metadata(IMX_TOKEN), amount);
    }

    function test_depositTransfersTokens() public {
        uint256 amount = 100;

        setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, amount, true);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        rootBridge.deposit{value: depositFee}(token, amount);

        // Check that tokens are transferred
        assertEq(thisPreBal - amount, token.balanceOf(address(this)), "Tokens not transferred from user");
        assertEq(bridgePreBal + amount, token.balanceOf(address(rootBridge)), "Tokens not transferred to bridge");
    }

    function test_depositTransfersNativeAsset() public {
        uint256 amount = 100;
        setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, amount, true);

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
        setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, amount, true);

        // Will fail when it tries to call balanceOf
        vm.expectRevert();
        rootBridge.deposit{value: depositFee}(IERC20Metadata(address(0)), amount);
    }

    function test_RevertIf_depositCalledWithUnmappedToken() public {
        uint256 amount = 100;
        setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, amount, true);

        ERC20PresetMinterPauser newToken = new ERC20PresetMinterPauser("Test", "TST");

        vm.expectRevert(NotMapped.selector);
        rootBridge.deposit{value: depositFee}(newToken, amount);
    }

    // We want to ensure that messages don't get sent when they are not supposed to
    function test_RevertIf_depositCalledWhenTokenApprovalNotProvided() public {
        uint256 amount = 100;
        setupDeposit(address(token), rootBridge, mapTokenFee, depositFee, amount, true);

        vm.expectRevert();
        rootBridge.deposit{value: depositFee}(token, amount * 2);
    }

    /**
     * DEPOSIT TO
     */

    function test_RevertsIf_DepositToWhenPaused() public {
        pause(IPausable(address(rootBridge)));
        vm.expectRevert("Pausable: paused");
        rootBridge.depositTo{value: 1000}(token, address(this), 1000);
    }

    function test_DepositToResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_DepositToWhenPaused();
        unpause(IPausable(address(rootBridge)));
        // Expect success case to pass
        test_depositToCallsSendMessage();
    }

    function test_depositToCallsSendMessage() public {
        uint256 amount = 100;
        address receiver = address(12345);

        (, bytes memory predictedPayload) =
            setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        vm.expectCall(
            address(mockAxelarAdaptor),
            depositFee,
            abi.encodeWithSelector(mockAxelarAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        rootBridge.depositTo{value: depositFee}(token, receiver, amount);
    }

    function test_depositToEmitsChildChainERC20DepositEvent() public {
        uint256 amount = 100;
        address receiver = address(12345);

        (address childToken,) =
            setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        vm.expectEmit();
        emit ChildChainERC20Deposit(address(token), childToken, address(this), receiver, amount);
        rootBridge.depositTo{value: depositFee}(token, receiver, amount);
    }

    function test_depositToIMXEmitsIMXDepositEvent() public {
        uint256 amount = 100;

        address receiver = address(12345);

        setupDepositTo(IMX_TOKEN, rootBridge, mapTokenFee, depositFee, amount, receiver, false);

        vm.expectEmit();
        emit IMXDeposit(IMX_TOKEN, address(this), receiver, amount);
        rootBridge.depositTo{value: depositFee}(IERC20Metadata(IMX_TOKEN), receiver, amount);
    }

    function test_depositToTransfersTokens() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, amount, receiver, true);

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

        setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, amount, receiver, true);

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
        setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        vm.expectRevert();
        rootBridge.depositTo{value: depositFee}(token, receiver, amount * 2);
    }

    function test_RevertIf_depositToCalledWithZeroAddress() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        // Will fail when it tries to call balanceOf
        vm.expectRevert();
        rootBridge.depositTo{value: depositFee}(IERC20Metadata(address(0)), receiver, amount);
    }

    function test_RevertIf_depositToCalledWithUnmappedToken() public {
        uint256 amount = 100;
        address receiver = address(12345);

        setupDepositTo(address(token), rootBridge, mapTokenFee, depositFee, amount, receiver, true);

        ERC20PresetMinterPauser newToken = new ERC20PresetMinterPauser("Test", "TST");

        vm.expectRevert(NotMapped.selector);
        rootBridge.depositTo{value: depositFee}(newToken, receiver, amount);
    }
}
