// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {ChildAxelarBridgeAdaptor} from "../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {MockChildERC20Bridge} from "../../../src/test/child/MockChildERC20Bridge.sol";
import {MockChildAxelarGateway} from "../../../src/test/child/MockChildAxelarGateway.sol";
import {MockChildAxelarGasService} from "../../../src/test/child/MockChildAxelarGasService.sol";
import {
    IChildAxelarBridgeAdaptorErrors,
    IChildAxelarBridgeAdaptorEvents
} from "../../../src/interfaces/child/IChildAxelarBridgeAdaptor.sol";

contract ChildAxelarBridgeAdaptorUnitTest is Test, IChildAxelarBridgeAdaptorErrors, IChildAxelarBridgeAdaptorEvents {
    address public GATEWAY_ADDRESS = address(1);
    string public constant ROOT_CHAIN_NAME = "root";
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");

    ERC20PresetMinterPauser public token;
    ChildAxelarBridgeAdaptor public axelarAdaptor;
    MockChildERC20Bridge public mockChildERC20Bridge;
    MockChildAxelarGateway public mockChildAxelarGateway;
    MockChildAxelarGasService public mockChildAxelarGasService;

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        mockChildERC20Bridge = new MockChildERC20Bridge();
        mockChildAxelarGateway = new MockChildAxelarGateway();
        mockChildAxelarGasService = new MockChildAxelarGasService();
        axelarAdaptor = new ChildAxelarBridgeAdaptor(address(mockChildAxelarGateway));
        axelarAdaptor.initialize(ROOT_CHAIN_NAME, address(mockChildERC20Bridge), address(mockChildAxelarGasService));
    }

    function test_Initialize() public {
        assertEq(address(axelarAdaptor.childBridge()), address(mockChildERC20Bridge), "childBridge not set");
        assertEq(address(axelarAdaptor.gateway()), address(mockChildAxelarGateway), "gateway not set");
        assertEq(axelarAdaptor.rootChain(), ROOT_CHAIN_NAME, "rootChain not set");
    }

    // TODO add more initialize tests
    function test_RevertIf_InitializeGivenZeroAddress() public {
        ChildAxelarBridgeAdaptor newAdaptor = new ChildAxelarBridgeAdaptor(GATEWAY_ADDRESS);
        vm.expectRevert(ZeroAddress.selector);
        newAdaptor.initialize("root", address(0), address(mockChildAxelarGasService));
    }

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
}
