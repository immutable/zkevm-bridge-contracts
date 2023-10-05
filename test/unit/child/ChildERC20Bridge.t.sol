// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20BridgeEvents,
    IERC20Metadata,
    IChildERC20BridgeErrors
} from "../../../src/child/ChildERC20Bridge.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../utils.t.sol";

contract ChildERC20BridgeUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));
    string constant ROOT_CHAIN_NAME = "test";

    ChildERC20 public childToken;
    ChildERC20 public rootToken;
    ChildERC20Bridge public childBridge;

    function setUp() public {
        rootToken = new ChildERC20();
        rootToken.initialize(address(456), "Test", "TST", 18);

        childToken = new ChildERC20();
        childToken.initialize(address(123), "Test", "TST", 18);

        childBridge = new ChildERC20Bridge();

        childBridge.initialize(address(this), ROOT_BRIDGE_ADAPTOR, address(childToken), ROOT_CHAIN_NAME);
    }

    function test_Initialize() public {
        assertEq(address(childBridge.bridgeAdaptor()), address(address(this)), "bridgeAdaptor not set");
        assertEq(childBridge.rootERC20BridgeAdaptor(), ROOT_BRIDGE_ADAPTOR, "rootERC20BridgeAdaptor not set");
        assertEq(childBridge.childTokenTemplate(), address(childToken), "childTokenTemplate not set");
        assertEq(childBridge.rootChain(), ROOT_CHAIN_NAME, "rootChain not set");
    }

    function test_RevertIfInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        childBridge.initialize(address(this), ROOT_BRIDGE_ADAPTOR, address(childToken), ROOT_CHAIN_NAME);
    }

    function test_RevertIf_InitializeWithAZeroAddress() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(0), ROOT_BRIDGE_ADAPTOR, address(0), ROOT_CHAIN_NAME);
    }

    function test_RevertIf_InitializeWithAnEmptyBridgeAdaptorString() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(InvalidRootERC20BridgeAdaptor.selector);
        bridge.initialize(address(this), "", address(childToken), ROOT_CHAIN_NAME);
    }

    function test_RevertIf_InitializeWithAnEmptyChainNameString() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(InvalidRootChain.selector);
        bridge.initialize(address(this), ROOT_BRIDGE_ADAPTOR, address(childToken), "");
    }

    function test_onMessageReceive_EmitsTokenMappedEvent() public {
        address predictedChildToken = Clones.predictDeterministicAddress(
            address(childToken), keccak256(abi.encodePacked(rootToken)), address(childBridge)
        );

        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );

        vm.expectEmit(true, true, false, false, address(childBridge));
        emit L2TokenMapped(address(rootToken), predictedChildToken);

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_onMessageReceive_SetsTokenMapping() public {
        address predictedChildToken = Clones.predictDeterministicAddress(
            address(childToken), keccak256(abi.encodePacked(rootToken)), address(childBridge)
        );

        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
        assertEq(
            childBridge.rootTokenToChildToken(address(rootToken)),
            predictedChildToken,
            "rootTokenToChildToken mapping not set"
        );
    }

    function test_onMessageReceive_DeploysERC20() public {
        address predictedChildToken = Clones.predictDeterministicAddress(
            address(childToken), keccak256(abi.encodePacked(rootToken)), address(childBridge)
        );

        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);

        assertEq(ChildERC20(predictedChildToken).symbol(), rootToken.symbol(), "token symbol not set");
    }

    function test_RevertIf_onMessageReceiveCalledWithMsgSenderNotBridgeAdaptor() public {
        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );

        vm.expectRevert(NotBridgeAdaptor.selector);
        vm.prank(address(123));
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_onMessageReceiveCalledWithSourceChainNotRootChain() public {
        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );

        vm.expectRevert(InvalidSourceChain.selector);
        childBridge.onMessageReceive("FAKE_CHAIN", ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_onMessageReceiveCalledWithSourceAddressNotRootAdaptor() public {
        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );

        vm.expectRevert(InvalidSourceAddress.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, Strings.toHexString(address(456)), data);
    }

    function test_RevertIf_onMessageReceiveCalledWithDataLengthZero() public {
        bytes memory data = "";
        vm.expectRevert(InvalidData.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_onMessageReceiveCalledWithDataInvalid() public {
        bytes memory data =
            abi.encode("FAKEDATA", address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals());

        vm.expectRevert(InvalidData.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_onMessageReceiveCalledWithZeroAddress() public {
        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(0), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );

        vm.expectRevert(ZeroAddress.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_onMessageReceiveCalledTwice() public {
        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals()
        );
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
        vm.expectRevert(AlreadyMapped.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_updateBridgeAdaptor() public {
        address newAdaptorAddress = address(0x11111);

        assertEq(address(childBridge.bridgeAdaptor()), address(this), "bridgeAdaptor not set");
        childBridge.updateBridgeAdaptor(newAdaptorAddress);
        assertEq(address(childBridge.bridgeAdaptor()), newAdaptorAddress, "bridgeAdaptor not updated");
    }

    function test_RevertIf_updateBridgeAdaptorCalledByNonOwner() public {
        vm.prank(address(0xf00f00));
        vm.expectRevert("Ownable: caller is not the owner");
        childBridge.updateBridgeAdaptor(address(0x11111));
    }

    function test_RevertIf_updateBridgeAdaptorCalledWithZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        childBridge.updateBridgeAdaptor(address(0));
    }

    //Deposit

    function test_onMessageReceive_Deposit_EmitsERC20DepositEvent() public {
        setupChildDeposit(rootToken, childBridge, ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        address childTokenFromMap = childBridge.rootTokenToChildToken(address(rootToken));

        vm.expectEmit(address(childBridge));
        emit ERC20Deposit(address(rootToken), childTokenFromMap, sender, receiver, amount);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_onMessageReceive_Deposit_TransfersTokensToReceiver() public {
        setupChildDeposit(rootToken, childBridge, ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        address childTokenFromMap = childBridge.rootTokenToChildToken(address(rootToken));

        // vm.expectCall(address(childTokenFromMap), 0, abi.encodeWithSelector(childTokenFromMap.transfer.selector, receiver, amount));
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_RevertIf_onMessageReceive_Deposit_NotMapped() public {
        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory data = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        vm.expectRevert(NotMapped.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_onMessageReceive_Deposit_RootZeroAddress() public {
        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(0), sender, receiver, amount);

        vm.expectRevert(ZeroAddress.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }
}
