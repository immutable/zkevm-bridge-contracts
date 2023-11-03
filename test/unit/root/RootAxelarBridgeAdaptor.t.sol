// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {MockAxelarGateway} from "../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../src/test/root/MockAxelarGasService.sol";
import {
    RootAxelarBridgeAdaptor,
    IRootAxelarBridgeAdaptorEvents,
    IRootAxelarBridgeAdaptorErrors
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

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();
        stubRootBridge = new StubRootBridge();
        childBridgeAdaptor = stubRootBridge.childBridgeAdaptor();

        axelarAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        axelarAdaptor.initialize(address(stubRootBridge), CHILD_CHAIN_NAME, address(axelarGasService));
        vm.deal(address(stubRootBridge), 99999999999);
    }

    function test_Constructor() public {
        assertEq(address(axelarAdaptor.rootBridge()), address(stubRootBridge), "rootBridge not set");
        assertEq(axelarAdaptor.childChain(), CHILD_CHAIN_NAME, "childChain not set");
        assertEq(address(axelarAdaptor.gateway()), address(mockAxelarGateway), "axelarGateway not set");
        assertEq(address(axelarAdaptor.gasService()), address(axelarGasService), "axelarGasService not set");
    }

    function test_RevertWhen_InitializerGivenZeroAddress() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(ZeroAddresses.selector);
        newAdaptor.initialize(address(0), CHILD_CHAIN_NAME, address(axelarGasService));
    }

    function test_RevertWhen_ConstructorGivenEmptyChildChainName() public {
        RootAxelarBridgeAdaptor newAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));
        vm.expectRevert(InvalidChildChain.selector);
        newAdaptor.initialize(address(this), "", address(axelarGasService));
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

    function test_sendMessage_EmitsAxelarMessageEvent() public {
        bytes memory payload = abi.encode(MAP_TOKEN_SIG, address(token), token.name(), token.symbol(), token.decimals());
        uint256 callValue = 300;

        vm.expectEmit(true, true, true, false, address(axelarAdaptor));
        emit AxelarMessage(CHILD_CHAIN_NAME, childBridgeAdaptor, payload);
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
