// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {MockAxelarGateway} from "../../mocks/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../mocks/root/MockAxelarGasService.sol";
import {
    RootAxelarBridgeAdaptor,
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors,
    IRootAxelarBridgeAdaptor
} from "../../../src/root/RootAxelarBridgeAdaptor.sol";
import {StubRootBridge} from "../../mocks/root/StubRootBridge.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract RootAxelarBridgeAdaptorTest is Test, IRootAxelarBridgeAdaptorEvents, IRootAxelarBridgeAdaptorErrors {
    address constant CHILD_BRIDGE = address(3);
    string constant CHILD_CHAIN_NAME = "test";
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string CHILD_BRIDGE_ADAPTOR_STRING = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");

    ERC20PresetMinterPauser public token;
    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;
    StubRootBridge public stubRootBridge;

    address bridgeManager = makeAddr("bridgeManager");
    address gasServiceManager = makeAddr("gasServiceManager");
    address targetManager = makeAddr("targetManager");

    IRootAxelarBridgeAdaptor.InitializationRoles public roles = IRootAxelarBridgeAdaptor.InitializationRoles({
        defaultAdmin: address(this),
        bridgeManager: bridgeManager,
        gasServiceManager: gasServiceManager,
        targetManager: targetManager
    });

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();
        axelarAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        stubRootBridge = new StubRootBridge();
        axelarAdaptor.initialize(
            roles, address(stubRootBridge), CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService)
        );
        vm.deal(address(stubRootBridge), 99999999999);
    }

    /**
     * INITIALIZE
     */

    function test_Initialize() public {
        assertEq(address(axelarAdaptor.rootBridge()), address(stubRootBridge), "rootBridge not set");
        assertEq(axelarAdaptor.childChainId(), CHILD_CHAIN_NAME, "childChain not set");
        assertEq(axelarAdaptor.childBridgeAdaptor(), CHILD_BRIDGE_ADAPTOR_STRING, "childBridgeAdaptor not set");
        assertEq(address(axelarAdaptor.gateway()), address(mockAxelarGateway), "axelarGateway not set");
        assertEq(address(axelarAdaptor.gasService()), address(axelarGasService), "axelarGasService not set");
        assertEq(axelarAdaptor.hasRole(axelarAdaptor.DEFAULT_ADMIN_ROLE(), address(this)), true, "defaultAdmin not set");
        assertEq(
            axelarAdaptor.hasRole(axelarAdaptor.BRIDGE_MANAGER_ROLE(), bridgeManager), true, "bridgeManager not set"
        );
        assertEq(
            axelarAdaptor.hasRole(axelarAdaptor.GAS_SERVICE_MANAGER_ROLE(), gasServiceManager),
            true,
            "gasServiceManager not set"
        );
        assertEq(
            axelarAdaptor.hasRole(axelarAdaptor.TARGET_MANAGER_ROLE(), targetManager), true, "targetManager not set"
        );
    }

    function test_RevertIf_InitializeWithUnauthorizedInitializer() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.prank(address(0x1234));
        vm.expectRevert(UnauthorizedInitializer.selector);
        newAdaptor.initialize(
            roles, address(this), CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService)
        );
    }

    function test_RevertIf_InitializeWithZeroAdmin() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.defaultAdmin = address(0);
        newAdaptor.initialize(
            roles, address(this), CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService)
        );
    }

    function test_RevertIf_InitializeWithZeroBridgeManager() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.bridgeManager = address(0);
        newAdaptor.initialize(
            roles, address(this), CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService)
        );
    }

    function test_RevertIf_InitializeWithZeroGasServiceManager() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.gasServiceManager = address(0);
        newAdaptor.initialize(
            roles, address(this), CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService)
        );
    }

    function test_RevertIf_InitializeWithZeroTargetManager() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        roles.targetManager = address(0);
        newAdaptor.initialize(
            roles, address(this), CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService)
        );
    }

    function test_RevertIf_InitializeGivenZeroAddress() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        newAdaptor.initialize(
            roles, address(0), CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService)
        );
    }

    function test_RevertIf_InitializeGivenEmptyChildChainName() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(InvalidChildChain.selector);
        newAdaptor.initialize(roles, address(this), "", CHILD_BRIDGE_ADAPTOR_STRING, address(axelarGasService));
    }

    function test_RevertIf_InitializeGivenEmptyChildAdapter() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(InvalidChildBridgeAdaptor.selector);
        newAdaptor.initialize(roles, address(this), CHILD_CHAIN_NAME, "", address(axelarGasService));
    }
    /**
     * EXECUTE
     */

    function test_RevertIf_executeCalledWithInvalidSourceChain() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encodePacked("payload");

        vm.expectRevert(InvalidSourceChain.selector);
        axelarAdaptor.execute(commandId, "Invalid-Source-Chain", CHILD_BRIDGE_ADAPTOR_STRING, payload);
    }

    function test_RevertIf_executeCalledWithInvalidSourceAddress() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encodePacked("payload");

        vm.expectRevert(InvalidSourceAddress.selector);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, "invalid-source-address", payload);
    }

    function test_Execute_CallsBridge() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encodePacked("payload");

        // We expect to call the bridge's onMessageReceive function.
        vm.expectCall(
            address(stubRootBridge), abi.encodeWithSelector(stubRootBridge.onMessageReceive.selector, payload)
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, payload);
    }

    function test_Execute_EmitsAdaptorExecuteEvent() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encodePacked("payload");

        // We expect to call the bridge's onMessageReceive function.
        vm.expectEmit();
        emit AdaptorExecute(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, payload);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, payload);
    }

    /**
     * SEND MESSAGE
     */

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
                CHILD_BRIDGE_ADAPTOR_STRING,
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
                mockAxelarGateway.callContract.selector, CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, payload
            )
        );

        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, address(123));
    }

    function test_sendMessage_EmitsAxelarMessageSentEvent() public {
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        uint256 callValue = 300;

        vm.expectEmit(true, true, true, false, address(axelarAdaptor));
        emit AxelarMessageSent(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, payload);
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
                CHILD_BRIDGE_ADAPTOR_STRING,
                payload,
                refundRecipient
            )
        );

        vm.prank(address(stubRootBridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, refundRecipient);
    }

    /**
     * MAP TOKEN
     */

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

    /**
     * UPDATE ROOT BRIDGE
     */

    function test_updateRootBridge_UpdatesRootBridge() public {
        vm.startPrank(bridgeManager);
        address newRootBridge = address(0x3333);
        axelarAdaptor.updateRootBridge(newRootBridge);
        assertEq(address(axelarAdaptor.rootBridge()), newRootBridge, "rootBridge not updated");
        vm.stopPrank();
    }

    function test_updateRootBridge_EmitsEvent() public {
        vm.startPrank(bridgeManager);
        address newRootBridge = address(0x3333);
        vm.expectEmit(true, true, false, false, address(axelarAdaptor));
        emit RootBridgeUpdated(address(stubRootBridge), newRootBridge);
        axelarAdaptor.updateRootBridge(newRootBridge);
        vm.stopPrank();
    }

    function test_RevertsIf_updateRootBridgeCalledByNonBridgeManager() public {
        bytes32 role = axelarAdaptor.BRIDGE_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(this)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        axelarAdaptor.updateRootBridge(address(0x3333));
    }

    function test_RevertsIf_updateRootBridgeCalledWithZeroAddress() public {
        vm.startPrank(bridgeManager);
        vm.expectRevert(ZeroAddresses.selector);
        axelarAdaptor.updateRootBridge(address(0));
    }

    /**
     * UPDATE CHILD CHAIN
     */

    function test_updateChildChain_UpdatesChildChain() public {
        vm.startPrank(targetManager);
        string memory newChildChain = "newChildChain";
        axelarAdaptor.updateChildChain(newChildChain);
        assertEq(axelarAdaptor.childChainId(), newChildChain, "childChain not updated");
        vm.stopPrank();
    }

    function test_updateChildChain_EmitsEvent() public {
        vm.startPrank(targetManager);
        string memory newChildChain = "newChildChain";
        vm.expectEmit(true, true, false, false, address(axelarAdaptor));
        emit ChildChainUpdated(CHILD_CHAIN_NAME, newChildChain);
        axelarAdaptor.updateChildChain(newChildChain);
        vm.stopPrank();
    }

    function test_RevertsIf_updateChildChainCalledByNonTargetManager() public {
        bytes32 role = axelarAdaptor.TARGET_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(this)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        axelarAdaptor.updateChildChain("newChildChain");
    }

    function test_RevertsIf_updateChildChainCalledWithEmptyString() public {
        vm.startPrank(targetManager);
        vm.expectRevert(InvalidChildChain.selector);
        axelarAdaptor.updateChildChain("");
    }

    /**
     * UPDATE CHILD BRIDGE ADAPTOR
     */

    function test_updateChildBridgeAdaptor_UpdatesChildBridgeAdaptor() public {
        vm.startPrank(targetManager);

        string memory newAdaptorAddress = Strings.toHexString(address(0x11111));
        assertEq(axelarAdaptor.childBridgeAdaptor(), CHILD_BRIDGE_ADAPTOR_STRING, "bridgeAdaptor not set");
        axelarAdaptor.updateChildBridgeAdaptor(newAdaptorAddress);
        assertEq(axelarAdaptor.childBridgeAdaptor(), newAdaptorAddress, "bridgeAdaptor not updated");
    }

    function test_updateChildBridgeAdaptor_EmitsEvent() public {
        vm.startPrank(targetManager);

        string memory newAdaptorAddress = Strings.toHexString(address(0x11111));
        vm.expectEmit(true, true, false, false, address(axelarAdaptor));
        emit ChildBridgeAdaptorUpdated(axelarAdaptor.childBridgeAdaptor(), newAdaptorAddress);

        axelarAdaptor.updateChildBridgeAdaptor(newAdaptorAddress);
    }

    function test_RevertsIf_updateChildBridgeAdaptorCalledByNonTargetManager() public {
        address caller = address(0xf00f00);
        vm.startPrank(caller);
        bytes32 role = axelarAdaptor.TARGET_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(caller),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        axelarAdaptor.updateChildBridgeAdaptor(Strings.toHexString(address(0x11111)));
    }

    function test_RevertsIf_updateChildBridgeAdaptorCalledWithEmptyString() public {
        vm.startPrank(targetManager);
        vm.expectRevert(InvalidChildBridgeAdaptor.selector);
        axelarAdaptor.updateChildBridgeAdaptor("");
    }

    /**
     * UPDATE GAS SERVICE
     */

    function test_updateGasService_UpdatesGasService() public {
        vm.startPrank(gasServiceManager);
        address newGasService = address(0x3333);
        axelarAdaptor.updateGasService(newGasService);
        assertEq(address(axelarAdaptor.gasService()), newGasService, "gasService not updated");
        vm.stopPrank();
    }

    function test_updateGasService_EmitsEvent() public {
        vm.startPrank(gasServiceManager);
        address newGasService = address(0x3333);
        vm.expectEmit(true, true, false, false, address(axelarAdaptor));
        emit GasServiceUpdated(address(axelarGasService), newGasService);
        axelarAdaptor.updateGasService(newGasService);
        vm.stopPrank();
    }

    function test_RevertsIf_updateGasServiceCalledByNonGasServiceManager() public {
        bytes32 role = axelarAdaptor.GAS_SERVICE_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(this)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        axelarAdaptor.updateGasService(address(0x3333));
    }

    function test_RevertsIf_updateGasServiceCalledWithZeroAddress() public {
        vm.startPrank(gasServiceManager);
        vm.expectRevert(ZeroAddresses.selector);
        axelarAdaptor.updateGasService(address(0));
    }
}
