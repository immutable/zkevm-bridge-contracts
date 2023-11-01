// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ChildAxelarBridgeAdaptor} from "../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {MockChildERC20Bridge} from "../../../src/test/child/MockChildERC20Bridge.sol";
import {MockChildAxelarGateway} from "../../../src/test/child/MockChildAxelarGateway.sol";
import {MockChildAxelarGasService} from "../../../src/test/child/MockChildAxelarGasService.sol";
import {IChildAxelarBridgeAdaptorErrors} from "../../../src/interfaces/child/IChildAxelarBridgeAdaptor.sol";

contract ChildAxelarBridgeAdaptorUnitTest is Test, IChildAxelarBridgeAdaptorErrors {
    address public GATEWAY_ADDRESS = address(1);

    ChildAxelarBridgeAdaptor public childAxelarBridgeAdaptor;
    MockChildERC20Bridge public mockChildERC20Bridge;
    MockChildAxelarGateway public mockChildAxelarGateway;
    MockChildAxelarGasService public mockChildAxelarGasService;

    function setUp() public {
        mockChildERC20Bridge = new MockChildERC20Bridge();
        mockChildAxelarGateway = new MockChildAxelarGateway();
        mockChildAxelarGasService = new MockChildAxelarGasService();
        childAxelarBridgeAdaptor = new ChildAxelarBridgeAdaptor(address(mockChildAxelarGateway));
        childAxelarBridgeAdaptor.initialize("root", address(mockChildERC20Bridge), address(mockChildAxelarGasService));
    }

    function test_Constructor_SetsValues() public {
        assertEq(address(childAxelarBridgeAdaptor.childBridge()), address(mockChildERC20Bridge), "childBridge not set");
        assertEq(address(childAxelarBridgeAdaptor.gateway()), address(mockChildAxelarGateway), "gateway not set");
    }

    // TODO add more initialize tests
    function test_RevertIf_InitializeGivenZeroAddress() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        newAdaptor.initialize("root", address(0), address(mockChildAxelarGasService));
    }

    function test_Execute() public {
        bytes32 commandId = bytes32("testCommandId");
        string memory sourceChain = "test";
        string memory sourceAddress = Strings.toHexString(address(123));
        bytes memory payload = abi.encodePacked("payload");

        // We expect to call the bridge's onMessageReceive function.
        vm.expectCall(
            address(mockChildERC20Bridge),
            abi.encodeWithSelector(mockChildERC20Bridge.onMessageReceive.selector, sourceChain, sourceAddress, payload)
        );
        childAxelarBridgeAdaptor.execute(commandId, sourceChain, sourceAddress, payload);
    }
}
