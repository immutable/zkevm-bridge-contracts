// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../../../mocks/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../mocks/root/MockAxelarGasService.sol";
import {
    RootAxelarBridgeAdaptor,
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors,
    IRootAxelarBridgeAdaptor
} from "../../../../src/root/RootAxelarBridgeAdaptor.sol";
import {StubRootBridge} from "../../../mocks/root/StubRootBridge.sol";

contract RootAxelarBridgeWithdrawAdaptorTest is Test, IRootAxelarBridgeAdaptorEvents, IRootAxelarBridgeAdaptorErrors {
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

    function test_execute_callsBridge() public {
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
}
