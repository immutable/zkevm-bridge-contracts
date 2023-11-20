// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {MockAxelarGateway} from "../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../src/test/root/MockAxelarGasService.sol";
import {
    RootAxelarBridgeAdaptor,
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors,
    IRootAxelarBridgeAdaptor
} from "../../../src/root/RootAxelarBridgeAdaptor.sol";
import {StubRootBridge} from "../../../src/test/root/StubRootBridge.sol";

contract RootAxelarBridgeAdaptorTest is Test, IRootAxelarBridgeAdaptorEvents, IRootAxelarBridgeAdaptorErrors {
    address constant CHILD_BRIDGE = address(3);
    string public childBridgeAdaptor;
    string constant CHILD_CHAIN_NAME = "test";
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");

    ERC20PresetMinterPauser public token;
    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;
    StubRootBridge public stubRootBridge;

    IRootAxelarBridgeAdaptor.InitializationRoles public roles = IRootAxelarBridgeAdaptor.InitializationRoles({
        defaultAdmin: address(this),
        bridgeManager: address(this),
        gasServiceManager: address(this),
        targetManager: address(this)
    });

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();
        stubRootBridge = new StubRootBridge();
        childBridgeAdaptor = stubRootBridge.childBridgeAdaptor();

        axelarAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        axelarAdaptor.initialize(roles, address(stubRootBridge), CHILD_CHAIN_NAME, address(axelarGasService));
        vm.deal(address(stubRootBridge), 99999999999);
    }

    function test_Initialize() public {
        assertEq(address(axelarAdaptor.rootBridge()), address(stubRootBridge), "rootBridge not set");
        assertEq(axelarAdaptor.childChain(), CHILD_CHAIN_NAME, "childChain not set");
        assertEq(address(axelarAdaptor.gateway()), address(mockAxelarGateway), "axelarGateway not set");
        assertEq(address(axelarAdaptor.gasService()), address(axelarGasService), "axelarGasService not set");
        assertEq(axelarAdaptor.hasRole(axelarAdaptor.DEFAULT_ADMIN_ROLE(), address(this)), true, "defaultAdmin not set");
        assertEq(
            axelarAdaptor.hasRole(axelarAdaptor.BRIDGE_MANAGER_ROLE(), address(this)), true, "bridgeManager not set"
        );
        assertEq(
            axelarAdaptor.hasRole(axelarAdaptor.GAS_SERVICE_MANAGER_ROLE(), address(this)),
            true,
            "gasServiceManager not set"
        );
        assertEq(
            axelarAdaptor.hasRole(axelarAdaptor.TARGET_MANAGER_ROLE(), address(this)), true, "targetManager not set"
        );
    }

    function test_RevertIf_InitializeWithZeroAdmin() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.defaultAdmin = address(0);
        newAdaptor.initialize(roles, address(this), CHILD_CHAIN_NAME, address(axelarGasService));
    }

    function test_RevertIf_InitializeWithZeroBridgeManager() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.bridgeManager = address(0);
        newAdaptor.initialize(roles, address(this), CHILD_CHAIN_NAME, address(axelarGasService));
    }

    function test_RevertIf_InitializeWithZeroGasServiceManager() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.gasServiceManager = address(0);
        newAdaptor.initialize(roles, address(this), CHILD_CHAIN_NAME, address(axelarGasService));
    }

    function test_RevertIf_InitializeWithZeroTargetManager() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.targetManager = address(0);
        newAdaptor.initialize(roles, address(this), CHILD_CHAIN_NAME, address(axelarGasService));
    }

    function test_RevertIf_InitializeGivenZeroAddress() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        newAdaptor.initialize(roles, address(0), CHILD_CHAIN_NAME, address(axelarGasService));
    }

    function test_RevertIf_InitializeGivenEmptyChildChainName() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(InvalidChildChain.selector);
        newAdaptor.initialize(roles, address(this), "", address(axelarGasService));
    }

    function test_Execute_CallsBridge() public {
        bytes32 commandId = bytes32("testCommandId");
        string memory sourceChain = "test";
        string memory sourceAddress = Strings.toHexString(address(123));
        bytes memory payload = abi.encodePacked("payload");

        // We expect to call the bridge's onMessageReceive function.
        vm.expectCall(
            address(stubRootBridge),
            abi.encodeWithSelector(stubRootBridge.onMessageReceive.selector, sourceChain, sourceAddress, payload)
        );
        axelarAdaptor.execute(commandId, sourceChain, sourceAddress, payload);
    }

    function test_Execute_EmitsAdaptorExecuteEvent() public {
        bytes32 commandId = bytes32("testCommandId");
        string memory sourceChain = "test";
        string memory sourceAddress = Strings.toHexString(address(123));
        bytes memory payload = abi.encodePacked("payload");

        // We expect to call the bridge's onMessageReceive function.
        vm.expectEmit();
        emit AdaptorExecute(sourceChain, sourceAddress, payload);
        axelarAdaptor.execute(commandId, sourceChain, sourceAddress, payload);
    }

    /// @dev For this unit test we just want to make sure the correct functions are called on the Axelar Gateway and Gas Service.
    function test_sendMessage_CallsGasService() public {
        address refundRecipient = address(123);
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        uint256 callValue = 300;

        vm.expectCall(
            address(axelarGasService),
            callValue,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                CHILD_CHAIN_NAME,
                childBridgeAdaptor,
                payload,
                refundRecipient
            )
        );

        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, refundRecipient);
    }

    function test_sendMessage_CallsGateway() public {
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        uint256 callValue = 300;

        vm.expectCall(
            address(mockAxelarGateway),
            abi.encodeWithSelector(
                mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, childBridgeAdaptor, payload
            )
        );

        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, address(123));
    }

    function test_sendMessage_EmitsAxelarMessageSentEvent() public {
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        uint256 callValue = 300;

        vm.expectEmit(true, true, true, false, address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, childBridgeAdaptor, payload);
        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, address(123));
    }

    function testFuzz_sendMessage_PaysGasToGasService(uint256 callValue) public {
        vm.assume(callValue < address(this).balance);
        vm.assume(callValue > 0);
        vm.deal(address(stubRootBridge), callValue);

        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());

        uint256 bridgePreBal = address(stubRootBridge).balance;
        uint256 axelarGasServicePreBal = address(axelarGasService).balance;

        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, address(123));

        assertEq(address(stubRootBridge).balance, bridgePreBal - callValue, "ETH balance not decreased");
        assertEq(address(axelarGasService).balance, axelarGasServicePreBal + callValue, "ETH not paid to gas service");
    }

    function test_sendMessage_GivesCorrectRefundRecipient() public {
        address refundRecipient = address(0x3333);
        uint256 callValue = 300;

        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());

        vm.expectCall(
            address(axelarGasService),
            callValue,
            abi.encodeWithSelector(
                axelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                CHILD_CHAIN_NAME,
                childBridgeAdaptor,
                payload,
                refundRecipient
            )
        );

        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, refundRecipient);
    }

    function test_RevertIf_mapTokenCalledByNonRootBridge() public {
        address payable prankster = payable(address(0x33));
        uint256 value = 300;
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());

        // Have to call these above so the expectRevert works on the call to mapToken.
        prankster.transfer(value);
        vm.prank(prankster);
        vm.expectRevert(CallerNotBridge.selector);
        axelarAdaptor.sendMessage{value: value}(payload, address(123));
    }

    function test_RevertIf_mapTokenCalledWithNoValue() public {
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        vm.expectRevert(NoGas.selector);
        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: 0}(payload, address(123));
    }
}
