// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    RootAxelarBridgeAdaptor,
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors,
    IRootAxelarBridgeAdaptor
} from "../../../src/root/RootAxelarBridgeAdaptor.sol";
import {MockAxelarGateway} from "../../mocks/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../mocks/root/MockAxelarGasService.sol";
import {StubRootBridge} from "../../mocks/root/StubRootBridge.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract RootAxelarBridgeAdaptorTest is Test, IRootAxelarBridgeAdaptorErrors, IRootAxelarBridgeAdaptorEvents {
    string public constant CHILD_CHAIN_NAME = "child";
    string public CHILD_BRIDGE_ADAPTOR = Strings.toHexString(address(4));

    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockRootAxelarGateway;
    MockAxelarGasService public mockRootAxelarGasService;
    StubRootBridge public mockRootERC20Bridge;

    function setUp() public {
        IRootAxelarBridgeAdaptor.InitializationRoles memory roles = IRootAxelarBridgeAdaptor.InitializationRoles({
            defaultAdmin: address(this),
            bridgeManager: address(this),
            gasServiceManager: address(this),
            targetManager: address(this)
        });

        mockRootERC20Bridge = new StubRootBridge();
        mockRootAxelarGateway = new MockAxelarGateway();
        mockRootAxelarGasService = new MockAxelarGasService();

        axelarAdaptor = new RootAxelarBridgeAdaptor(address(mockRootAxelarGateway), address(this));
        axelarAdaptor.initialize(
            roles,
            address(mockRootERC20Bridge),
            CHILD_CHAIN_NAME,
            CHILD_BRIDGE_ADAPTOR,
            address(mockRootAxelarGasService)
        );
    }

    function testFuzz_SendMessage(uint256 callValue, bytes calldata payload, address refundRecipient) public {
        vm.assume(callValue > 0 && callValue < type(uint256).max);

        vm.startPrank(address(mockRootERC20Bridge));
        vm.deal(address(mockRootERC20Bridge), callValue);

        // Send message called with insufficient balance should revert
        vm.expectRevert();
        axelarAdaptor.sendMessage{value: callValue + 1}(payload, refundRecipient);

        // Send message correctly should call gas service and gateway with expected data
        vm.expectCall(
            address(mockRootAxelarGasService),
            callValue,
            abi.encodeWithSelector(
                mockRootAxelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                CHILD_CHAIN_NAME,
                axelarAdaptor.childBridgeAdaptor(),
                payload,
                refundRecipient
            )
        );
        vm.expectCall(
            address(mockRootAxelarGateway),
            abi.encodeWithSelector(
                mockRootAxelarGateway.callContract.selector,
                CHILD_CHAIN_NAME,
                axelarAdaptor.childBridgeAdaptor(),
                payload
            )
        );
        axelarAdaptor.sendMessage{value: callValue}(payload, refundRecipient);

        vm.stopPrank();
    }

    function testFuzz_Execute(bytes32 commandId, bytes calldata payload) public {
        // Execute should emit event and call bridge.
        vm.expectEmit();
        emit AdaptorExecute(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR, payload);
        vm.expectCall(
            address(mockRootERC20Bridge), abi.encodeWithSelector(mockRootERC20Bridge.onMessageReceive.selector, payload)
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR, payload);
    }
}
