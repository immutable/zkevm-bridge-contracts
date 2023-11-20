// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {ChildAxelarBridgeAdaptor} from "../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {MockChildERC20Bridge} from "../../../src/test/child/MockChildERC20Bridge.sol";
import {MockChildAxelarGateway} from "../../../src/test/child/MockChildAxelarGateway.sol";
import {MockChildAxelarGasService} from "../../../src/test/child/MockChildAxelarGasService.sol";
import {
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptor
} from "../../../src/interfaces/child/IChildAxelarBridgeAdaptor.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract ChildAxelarBridgeAdaptorUnitTest is Test, IChildAxelarBridgeAdaptorErrors, IChildAxelarBridgeAdaptorEvents {
    address public GATEWAY_ADDRESS = address(1);
    string public constant ROOT_CHAIN_NAME = "root";
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");

    ERC20PresetMinterPauser public token;
    ChildAxelarBridgeAdaptor public axelarAdaptor;
    MockChildERC20Bridge public mockChildERC20Bridge;
    MockChildAxelarGateway public mockChildAxelarGateway;
    MockChildAxelarGasService public mockChildAxelarGasService;

    address bridgeManager = makeAddr("bridgeManager");
    address gasServiceManager = makeAddr("gasServiceManager");
    address targetManager = makeAddr("targetManager");

    IChildAxelarBridgeAdaptor.InitializationRoles roles = IChildAxelarBridgeAdaptor.InitializationRoles({
        defaultAdmin: address(this),
        bridgeManager: bridgeManager,
        gasServiceManager: gasServiceManager,
        targetManager: targetManager
    });

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        mockChildERC20Bridge = new MockChildERC20Bridge();
        mockChildAxelarGateway = new MockChildAxelarGateway();
        mockChildAxelarGasService = new MockChildAxelarGasService();
        axelarAdaptor = new ChildAxelarBridgeAdaptor(address(mockChildAxelarGateway));
        axelarAdaptor.initialize(
            roles, ROOT_CHAIN_NAME, address(mockChildERC20Bridge), address(mockChildAxelarGasService)
        );
    }

    /**
     * INITIALIZE
     */

    function test_Initialize() public {
        assertEq(address(axelarAdaptor.childBridge()), address(mockChildERC20Bridge), "childBridge not set");
        assertEq(address(axelarAdaptor.gateway()), address(mockChildAxelarGateway), "gateway not set");
        assertEq(axelarAdaptor.rootChain(), ROOT_CHAIN_NAME, "rootChain not set");
        assertEq(address(axelarAdaptor.gasService()), address(mockChildAxelarGasService), "gasService not set");
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

    function test_RevertIf_InitializeWithZeroAdmin() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        roles.defaultAdmin = address(0);
        newAdaptor.initialize(roles, "root", address(mockChildERC20Bridge), address(mockChildAxelarGasService));
    }

    function test_RevertIf_InitializeWithZeroBridgeManager() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        roles.bridgeManager = address(0);
        newAdaptor.initialize(roles, "root", address(mockChildERC20Bridge), address(mockChildAxelarGasService));
    }

    function test_RevertIf_InitializeWithZeroGasServiceManager() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        roles.gasServiceManager = address(0);
        newAdaptor.initialize(roles, "root", address(mockChildERC20Bridge), address(mockChildAxelarGasService));
    }

    function test_RevertIf_InitializeWithZeroTargetManager() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        roles.targetManager = address(0);
        newAdaptor.initialize(roles, "root", address(mockChildERC20Bridge), address(mockChildAxelarGasService));
    }

    function test_RevertIf_InitializeGivenZeroAddress() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        newAdaptor.initialize(roles, "root", address(0), address(mockChildAxelarGasService));
    }

    function test_RevertIf_InitializeGivenEmptyRootChain() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(InvalidRootChain.selector);
        newAdaptor.initialize(roles, "", address(mockChildERC20Bridge), address(mockChildAxelarGasService));
    }

    function test_RevertIf_InitializeGivenZeroGasService() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        newAdaptor.initialize(roles, "root", address(mockChildERC20Bridge), address(0));
    }

    /**
     * EXECUTE
     */

    function test_Execute_CallsBridge() public {
        bytes32 commandId = bytes32("testCommandId");
        string memory sourceChain = "test";
        string memory sourceAddress = Strings.toHexString(address(123));
        bytes memory payload = abi.encodePacked("payload");

        // We expect to call the bridge's onMessageReceive function.
        vm.expectCall(
            address(mockChildERC20Bridge),
            abi.encodeWithSelector(mockChildERC20Bridge.onMessageReceive.selector, sourceChain, sourceAddress, payload)
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

    /**
     * SEND MESSAGE
     */

    function test_sendMessage_CallsGasService() public {
        address refundRecipient = address(123);
        bytes memory payload = abi.encode(WITHDRAW_SIG, address(token), address(this), address(999), 11111);
        uint256 callValue = 300;

        vm.expectCall(
            address(mockChildAxelarGasService),
            callValue,
            abi.encodeWithSelector(
                mockChildAxelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                ROOT_CHAIN_NAME,
                mockChildERC20Bridge.rootERC20BridgeAdaptor(),
                payload,
                refundRecipient
            )
        );

        vm.deal(address(mockChildERC20Bridge), callValue);
        vm.prank(address(mockChildERC20Bridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, refundRecipient);
    }

    function test_sendMessage_CallsGateway() public {
        bytes memory payload = abi.encode(WITHDRAW_SIG, address(token), address(this), address(999), 11111);
        uint256 callValue = 300;

        vm.expectCall(
            address(mockChildAxelarGateway),
            abi.encodeWithSelector(
                mockChildAxelarGateway.callContract.selector,
                ROOT_CHAIN_NAME,
                mockChildERC20Bridge.rootERC20BridgeAdaptor(),
                payload
            )
        );

        vm.deal(address(mockChildERC20Bridge), callValue);
        vm.prank(address(mockChildERC20Bridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, address(123));
    }

    function test_sendMessage_EmitsAxelarMessageSentEvent() public {
        bytes memory payload = abi.encode(WITHDRAW_SIG, address(token), address(this), address(999), 11111);
        uint256 callValue = 300;

        vm.expectEmit();
        emit AxelarMessageSent(ROOT_CHAIN_NAME, mockChildERC20Bridge.rootERC20BridgeAdaptor(), payload);

        vm.deal(address(mockChildERC20Bridge), callValue);
        vm.prank(address(mockChildERC20Bridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, address(123));
    }

    function testFuzz_sendMessage_PaysGasToGasService(uint256 callValue) public {
        vm.assume(callValue < address(this).balance);
        vm.assume(callValue > 0);
        vm.deal(address(mockChildERC20Bridge), callValue);

        bytes memory payload = abi.encode(WITHDRAW_SIG, address(token), address(this), address(999), 11111);

        uint256 bridgePreBal = address(mockChildERC20Bridge).balance;
        uint256 axelarGasServicePreBal = address(mockChildAxelarGasService).balance;

        vm.prank(address(mockChildERC20Bridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, address(123));

        assertEq(address(mockChildERC20Bridge).balance, bridgePreBal - callValue, "ETH balance not decreased");
        assertEq(
            address(mockChildAxelarGasService).balance,
            axelarGasServicePreBal + callValue,
            "ETH not paid to gas service"
        );
    }

    function test_sendMessage_GivesCorrectRefundRecipient() public {
        address refundRecipient = address(0x3333);
        uint256 callValue = 300;

        bytes memory payload = abi.encode(WITHDRAW_SIG, address(token), address(this), address(999), 11111);

        vm.expectCall(
            address(mockChildAxelarGasService),
            callValue,
            abi.encodeWithSelector(
                mockChildAxelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                ROOT_CHAIN_NAME,
                mockChildERC20Bridge.rootERC20BridgeAdaptor(),
                payload,
                refundRecipient
            )
        );

        vm.deal(address(mockChildERC20Bridge), callValue);
        vm.prank(address(mockChildERC20Bridge));
        axelarAdaptor.sendMessage{value: callValue}(payload, refundRecipient);
    }

    function test_RevertIf_sendMessageCalledByNonRootBridge() public {
        address payable prankster = payable(address(0x33));
        uint256 value = 300;
        bytes memory payload = abi.encode(WITHDRAW_SIG, address(token), address(this), address(999), 11111);

        prankster.transfer(value);
        vm.prank(prankster);
        vm.expectRevert(CallerNotBridge.selector);
        axelarAdaptor.sendMessage{value: value}(payload, address(123));
    }

    function test_RevertIf_sendMessageCalledWithNoValue() public {
        bytes memory payload = abi.encode(WITHDRAW_SIG, address(token), address(this), address(999), 11111);
        vm.expectRevert(NoGas.selector);
        vm.prank(address(mockChildERC20Bridge));
        axelarAdaptor.sendMessage{value: 0}(payload, address(123));
    }

    /**
     *  UPDATE CHILD BRIDGE
     */

    function test_updateChildBridge_UpdatesChildBridge() public {
        vm.startPrank(bridgeManager);
        address newChildBridge = address(0x123);
        axelarAdaptor.updateChildBridge(newChildBridge);
        assertEq(address(axelarAdaptor.childBridge()), newChildBridge, "childBridge not updated");
        vm.stopPrank();
    }

    function test_updateChildBridge_EmitsChildBridgeUpdatedEvent() public {
        vm.startPrank(bridgeManager);
        address newChildBridge = address(0x123);
        vm.expectEmit(true, true, false, false, address(axelarAdaptor));
        emit ChildBridgeUpdated(address(mockChildERC20Bridge), newChildBridge);
        axelarAdaptor.updateChildBridge(newChildBridge);
        vm.stopPrank();
    }

    function test_RevertIf_updateChildBridgeCalledByNonBridgeManager() public {
        bytes32 role = axelarAdaptor.BRIDGE_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(this)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        address newChildBridge = address(0x123);
        axelarAdaptor.updateChildBridge(newChildBridge);
    }

    function test_RevertIf_updateChildBridgeCalledWithZeroAddress() public {
        vm.startPrank(bridgeManager);
        vm.expectRevert(ZeroAddress.selector);
        axelarAdaptor.updateChildBridge(address(0));
        vm.stopPrank();
    }

    /**
     *  UPDATE ROOT CHAIN
     */

    function test_updateRootChain_UpdatesRootChain() public {
        vm.startPrank(targetManager);
        string memory newRootChain = "newRoot";
        axelarAdaptor.updateRootChain(newRootChain);
        assertEq(axelarAdaptor.rootChain(), newRootChain, "rootChain not updated");
        vm.stopPrank();
    }

    function test_updateRootChain_EmitsRootChainUpdatedEvent() public {
        vm.startPrank(targetManager);
        string memory newRootChain = "newRoot";
        vm.expectEmit(true, true, false, false, address(axelarAdaptor));
        emit RootChainUpdated(ROOT_CHAIN_NAME, newRootChain);
        axelarAdaptor.updateRootChain(newRootChain);
        vm.stopPrank();
    }

    function test_RevertIf_updateRootChainCalledByNonTargetManager() public {
        bytes32 role = axelarAdaptor.TARGET_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(this)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        axelarAdaptor.updateRootChain("newRoot");
    }

    function test_RevertIf_updateRootChainCalledWithEmptyRootChain() public {
        vm.startPrank(targetManager);
        vm.expectRevert(InvalidRootChain.selector);
        axelarAdaptor.updateRootChain("");
        vm.stopPrank();
    }

    /**
     * UPDATE GAS SERVICE
     */

    function test_updateGasService_UpdatesGasService() public {
        vm.startPrank(gasServiceManager);
        address newGasService = address(0x123);
        axelarAdaptor.updateGasService(newGasService);
        assertEq(address(axelarAdaptor.gasService()), newGasService, "gasService not updated");
        vm.stopPrank();
    }

    function test_updateGasService_EmitsGasServiceUpdatedEvent() public {
        vm.startPrank(gasServiceManager);
        address newGasService = address(0x123);
        vm.expectEmit(true, true, false, false, address(axelarAdaptor));
        emit GasServiceUpdated(address(mockChildAxelarGasService), newGasService);
        axelarAdaptor.updateGasService(newGasService);
        vm.stopPrank();
    }

    function test_RevertIf_updateGasServiceCalledByNonGasServiceManager() public {
        bytes32 role = axelarAdaptor.GAS_SERVICE_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(this)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        axelarAdaptor.updateGasService(address(0));
    }

    function test_RevertIf_updateGasServiceCalledWithZeroAddress() public {
        vm.startPrank(gasServiceManager);
        vm.expectRevert(ZeroAddress.selector);
        axelarAdaptor.updateGasService(address(0));
        vm.stopPrank();
    }
}
