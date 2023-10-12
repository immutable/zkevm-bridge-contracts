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

    address constant IMX_TOKEN = address(99);
    ChildERC20 public childTokenTemplate;
    ChildERC20 public rootToken;
    ChildERC20Bridge public childBridge;

    function setUp() public {
        rootToken = new ChildERC20();
        rootToken.initialize(address(456), "Test", "TST", 18);

        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        childBridge = new ChildERC20Bridge();

        childBridge.initialize(address(this), ROOT_BRIDGE_ADAPTOR, address(childTokenTemplate), ROOT_CHAIN_NAME, IMX_TOKEN);
    }

    function test_Initialize() public {
        assertEq(address(childBridge.bridgeAdaptor()), address(address(this)), "bridgeAdaptor not set");
        assertEq(childBridge.rootERC20BridgeAdaptor(), ROOT_BRIDGE_ADAPTOR, "rootERC20BridgeAdaptor not set");
        assertEq(childBridge.childTokenTemplate(), address(childTokenTemplate), "childTokenTemplate not set");
        assertEq(childBridge.rootChain(), ROOT_CHAIN_NAME, "rootChain not set");
    }

    function test_RevertIfInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        childBridge.initialize(address(this), ROOT_BRIDGE_ADAPTOR, address(childTokenTemplate), ROOT_CHAIN_NAME, IMX_TOKEN);
    }

    function test_RevertIf_InitializeWithAZeroAddressAdapter() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(0), ROOT_BRIDGE_ADAPTOR, address(1), ROOT_CHAIN_NAME, address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressChildTemplate() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), ROOT_BRIDGE_ADAPTOR, address(0), ROOT_CHAIN_NAME, address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressIMXToken() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(1), ROOT_BRIDGE_ADAPTOR, address(1), ROOT_CHAIN_NAME, address(0));
    }

    function test_RevertIf_InitializeWithAZeroAddressAll() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(address(0), ROOT_BRIDGE_ADAPTOR, address(0), ROOT_CHAIN_NAME, address(0));
    }

    function test_RevertIf_InitializeWithAnEmptyBridgeAdaptorString() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(InvalidRootERC20BridgeAdaptor.selector);
        bridge.initialize(address(this), "", address(childTokenTemplate), ROOT_CHAIN_NAME, IMX_TOKEN);
    }

    function test_RevertIf_InitializeWithAnEmptyChainNameString() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        vm.expectRevert(InvalidRootChain.selector);
        bridge.initialize(address(this), ROOT_BRIDGE_ADAPTOR, address(childTokenTemplate), "", IMX_TOKEN);
    }

    function test_onMessageReceive_EmitsTokenMappedEvent() public {
        address predictedChildToken = Clones.predictDeterministicAddress(
            address(childTokenTemplate), keccak256(abi.encodePacked(rootToken)), address(childBridge)
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
            address(childTokenTemplate), keccak256(abi.encodePacked(rootToken)), address(childBridge)
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
            address(childTokenTemplate), keccak256(abi.encodePacked(rootToken)), address(childBridge)
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

    function test_RevertIf_mapTokenCalledWithIMXAddress() public {
        bytes memory data = abi.encode(
            childBridge.MAP_TOKEN_SIG(), IMX_TOKEN, "ImmutableX", "IMX", 18
        );
        vm.expectRevert(WontMap.selector);
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

    function test_onMessageReceive_DepositIMX_EmitsIMXDepositEvent() public {

        uint256 fundedAmount = 10 ether;
        vm.deal(address(childBridge), fundedAmount);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1 ether;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), IMX_TOKEN, sender, receiver, amount);

        vm.expectEmit(address(childBridge));
        emit IMXDeposit(IMX_TOKEN, sender, receiver, amount);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_onMessageReceive_DepositIMX_BalancesChanged() public {
        uint256 fundedAmount = 10 ether;
        vm.deal(address(childBridge), fundedAmount);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1 ether;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), IMX_TOKEN, sender, receiver, amount);

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);

        assertEq(address(childBridge).balance, fundedAmount - amount, "contract balance not decreased");
        assertEq(receiver.balance, amount, "receiver balance not increased");
    }

     function test_RevertIf_onMessageReceive_DepositIMX_InsufficientBalance() public {
        uint256 fundedAmount = 1 ether;
        vm.deal(address(childBridge), fundedAmount);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 10 ether;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), IMX_TOKEN, sender, receiver, amount);

        vm.expectRevert("Address: insufficient balance");
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_onMessageReceive_Deposit_EmitsERC20DepositEvent() public {
        setupChildDeposit(rootToken, childBridge, ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        address childToken = childBridge.rootTokenToChildToken(address(rootToken));

        vm.expectEmit(address(childBridge));
        emit ERC20Deposit(address(rootToken), childToken, sender, receiver, amount);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_onMessageReceive_Deposit_TransfersTokensToReceiver() public {
        setupChildDeposit(rootToken, childBridge, ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        address childToken = childBridge.rootTokenToChildToken(address(rootToken));

        uint256 receiverPreBal = ChildERC20(childTokenTemplate).balanceOf(receiver);

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);

        assertEq(ChildERC20(childToken).balanceOf(receiver), receiverPreBal + amount, "receiver balance not increased");
    }

    function test_onMessageReceive_Deposit_IncreasesTotalSupply() public {
        setupChildDeposit(rootToken, childBridge, ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        address childToken = childBridge.rootTokenToChildToken(address(rootToken));

        uint256 totalSupplyPre = ChildERC20(childToken).totalSupply();

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);

        assertEq(ChildERC20(childToken).totalSupply(), totalSupplyPre + amount, "totalSupply not increased");
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

    function test_RevertIf_onMessageReceive_Deposit_ReceiverZeroAddress() public {
        address sender = address(100);
        address receiver = address(0);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        vm.expectRevert(ZeroAddress.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_RevertIf_onMessageReceive_DepositWithEmptyContract() public {
        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        address rootAddress = address(0x123);
        {
            // Slot is 6 because of the Ownable, Initializable contracts coming first.
            uint256 rootTokenToChildTokenMappingSlot = 6;
            address childAddress = address(444444);
            bytes32 slot = getMappingStorageSlotFor(rootAddress, rootTokenToChildTokenMappingSlot);
            bytes32 data = bytes32(uint256(uint160(childAddress)));
            vm.store(address(childBridge), slot, data);
        }

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), rootAddress, sender, receiver, amount);

        vm.expectRevert(EmptyTokenContract.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }
}
