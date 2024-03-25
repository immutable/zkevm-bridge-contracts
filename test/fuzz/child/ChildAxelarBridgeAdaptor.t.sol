// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents,
    IChildAxelarBridgeAdaptor
} from "../../../src/interfaces/child/IChildAxelarBridgeAdaptor.sol";
import {ChildAxelarBridgeAdaptor} from "../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {MockChildERC20Bridge} from "../../mocks/child/MockChildERC20Bridge.sol";
import {MockChildAxelarGateway} from "../../mocks/child/MockChildAxelarGateway.sol";
import {MockChildAxelarGasService} from "../../mocks/child/MockChildAxelarGasService.sol";

contract ChildAxelarBridgeAdaptorTest is Test, IChildAxelarBridgeAdaptorErrors, IChildAxelarBridgeAdaptorEvents {
    string public constant ROOT_CHAIN_NAME = "root";
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));

    ChildAxelarBridgeAdaptor public axelarAdaptor;
    MockChildERC20Bridge public mockChildERC20Bridge;
    MockChildAxelarGateway public mockChildAxelarGateway;
    MockChildAxelarGasService public mockChildAxelarGasService;

    function setUp() public {
        IChildAxelarBridgeAdaptor.InitializationRoles memory roles = IChildAxelarBridgeAdaptor.InitializationRoles({
            defaultAdmin: address(this),
            bridgeManager: address(this),
            gasServiceManager: address(this),
            targetManager: address(this)
        });

        mockChildERC20Bridge = new MockChildERC20Bridge();
        mockChildAxelarGateway = new MockChildAxelarGateway();
        mockChildAxelarGasService = new MockChildAxelarGasService();

        axelarAdaptor = new ChildAxelarBridgeAdaptor(address(mockChildAxelarGateway), address(this));
        axelarAdaptor.initialize(
            roles,
            address(mockChildERC20Bridge),
            ROOT_CHAIN_NAME,
            ROOT_BRIDGE_ADAPTOR,
            address(mockChildAxelarGasService)
        );
    }

    function testFuzz_SendMessage(uint256 callValue, bytes calldata payload, address refundRecipient) public {
        vm.assume(callValue > 0 && callValue < type(uint256).max);

        vm.startPrank(address(mockChildERC20Bridge));
        vm.deal(address(mockChildERC20Bridge), callValue);

        // Send message called with insufficient balance should revert
        vm.expectRevert();
        axelarAdaptor.sendMessage{value: callValue + 1}(payload, refundRecipient);

        // Send message correctly should call gas service and gateway with expected data
        vm.expectCall(
            address(mockChildAxelarGasService),
            callValue,
            abi.encodeWithSelector(
                mockChildAxelarGasService.payNativeGasForContractCall.selector,
                address(axelarAdaptor),
                ROOT_CHAIN_NAME,
                axelarAdaptor.rootBridgeAdaptor(),
                payload,
                refundRecipient
            )
        );
        vm.expectCall(
            address(mockChildAxelarGateway),
            abi.encodeWithSelector(
                mockChildAxelarGateway.callContract.selector,
                ROOT_CHAIN_NAME,
                axelarAdaptor.rootBridgeAdaptor(),
                payload
            )
        );
        axelarAdaptor.sendMessage{value: callValue}(payload, refundRecipient);

        vm.stopPrank();
    }

    function testFuzz_Execute(bytes32 commandId, bytes calldata payload) public {
        // Execute should emit event and call bridge.
        vm.expectEmit();
        emit AdaptorExecute(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, payload);
        vm.expectCall(
            address(mockChildERC20Bridge),
            abi.encodeWithSelector(mockChildERC20Bridge.onMessageReceive.selector, payload)
        );
        axelarAdaptor.execute(commandId, ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, payload);
    }
}
