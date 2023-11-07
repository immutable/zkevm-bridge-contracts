// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    RootERC20Bridge,
    IRootERC20BridgeEvents,
    IRootERC20BridgeErrors,
    IRootERC20Bridge
} from "../../../../src/root/RootERC20Bridge.sol";
import {MockAxelarGateway} from "../../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../../src/test/root/MockAxelarGasService.sol";
import {MockAdaptor} from "../../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../../utils.t.sol";

contract RootERC20BridgeWithdrawUnitTest is Test, IRootERC20BridgeEvents, IRootERC20BridgeErrors, Utils {
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string CHILD_BRIDGE_ADAPTOR_STRING = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    string constant CHILD_CHAIN_NAME = "test";
    address constant IMX_TOKEN = address(0xccc);
    address constant WRAPPED_ETH = address(0xddd);
    uint256 constant mapTokenFee = 300;
    uint256 constant withdrawAmount = 0.5 ether;
    uint256 constant UNLIMITED_IMX_DEPOSIT_LIMIT = 0;

    ERC20PresetMinterPauser public token;
    RootERC20Bridge public rootBridge;
    MockAdaptor public mockAxelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(this), 100 ether);
        deployCodeTo("ERC20PresetMinterPauser.sol", abi.encode("ImmutableX", "IMX"), IMX_TOKEN);

        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        rootBridge = new RootERC20Bridge();
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();

        mockAxelarAdaptor = new MockAdaptor();

        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        // The specific ERC20 token template does not matter for these unit tests
        rootBridge.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR_STRING,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            CHILD_CHAIN_NAME,
            UNLIMITED_IMX_DEPOSIT_LIMIT
        );
    }

    function test_RevertsIf_WithdrawWithInvalidSender() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.expectRevert(NotBridgeAdaptor.selector);
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
    }

    function test_RevertsIf_OnMessageReceiveWithInvalidSourceChain() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectRevert(InvalidSourceChain.selector);
        rootBridge.onMessageReceive("ding_dong", CHILD_BRIDGE_ADAPTOR_STRING, data);
    }

    function test_RevertsIf_OnMessageReceiveWithInvalidSourceAddress() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN, address(this), address(this), withdrawAmount);

        console2.log(CHILD_CHAIN_NAME);
        console2.log(rootBridge.childChain());
        vm.prank(address(mockAxelarAdaptor));
        vm.expectRevert(InvalidSourceAddress.selector);
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, "DING_DONG", data);
    }

    function test_RevertsIf_OnMessageReceiveWithZeroDataLength() public {
        bytes memory data;

        vm.prank(address(mockAxelarAdaptor));
        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Data too short"));

        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
    }

    function test_RevertsIf_OnMessageReceiveWithInvalidSignature() public {
        bytes memory data = abi.encode(keccak256("RANDOM"), IMX_TOKEN, address(this), address(this), withdrawAmount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Unsupported action signature"));
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
    }

    function test_RevertsIf_OnMessageReceiveWithUnmappedToken() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN, address(this), address(this), withdrawAmount);
        vm.prank(address(mockAxelarAdaptor));
        vm.expectRevert(NotMapped.selector);
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
    }

    function test_onMessageReceive_TransfersTokens() public {
        // Need to first map the token.
        rootBridge.mapToken(token);
        // And give the bridge some tokens
        token.transfer(address(rootBridge), 100 ether);

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        bytes memory data = abi.encode(WITHDRAW_SIG, token, address(this), address(this), withdrawAmount);
        vm.prank(address(mockAxelarAdaptor));
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        assertEq(token.balanceOf(address(this)), thisPreBal + withdrawAmount, "Tokens not transferred to receiver");
        assertEq(
            token.balanceOf(address(rootBridge)), bridgePreBal - withdrawAmount, "Tokens not transferred from bridge"
        );
    }

    function test_onMessageReceive_TransfersTokens_DifferentReceiver() public {
        address receiver = address(123456);
        // Need to first map the token.
        rootBridge.mapToken(token);
        // And give the bridge some tokens
        token.transfer(address(rootBridge), 100 ether);

        uint256 receiverPreBal = token.balanceOf(receiver);
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        bytes memory data = abi.encode(WITHDRAW_SIG, token, address(this), receiver, withdrawAmount);
        vm.prank(address(mockAxelarAdaptor));
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        assertEq(token.balanceOf(receiver), receiverPreBal + withdrawAmount, "Tokens not transferred to receiver");
        assertEq(
            token.balanceOf(address(rootBridge)), bridgePreBal - withdrawAmount, "Tokens not transferred from bridge"
        );
    }

    function test_onMessageReceive_EmitsRootChainERC20WithdrawEvent() public {
        // Need to first map the token.
        rootBridge.mapToken(token);
        // And give the bridge some tokens
        token.transfer(address(rootBridge), 100 ether);

        bytes memory data = abi.encode(WITHDRAW_SIG, token, address(this), address(this), withdrawAmount);
        vm.expectEmit();
        emit RootChainERC20Withdraw(
            address(token),
            rootBridge.rootTokenToChildToken(address(token)),
            address(this),
            address(this),
            withdrawAmount
        );
        vm.prank(address(mockAxelarAdaptor));
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
    }

    function test_onMessageReceive_EmitsRootChainERC20WithdrawEvent_DifferentReceiver() public {
        address receiver = address(123456);
        // Need to first map the token.
        rootBridge.mapToken(token);
        // And give the bridge some tokens
        token.transfer(address(rootBridge), 100 ether);

        bytes memory data = abi.encode(WITHDRAW_SIG, token, address(this), receiver, withdrawAmount);
        vm.expectEmit();
        emit RootChainERC20Withdraw(
            address(token), rootBridge.rootTokenToChildToken(address(token)), address(this), receiver, withdrawAmount
        );
        vm.prank(address(mockAxelarAdaptor));
        rootBridge.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
    }
}
