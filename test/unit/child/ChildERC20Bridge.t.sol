// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20Bridge,
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors
} from "../../../src/child/ChildERC20Bridge.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {Utils, IPausable} from "../../utils.t.sol";

contract ChildERC20BridgeUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));
    string constant ROOT_CHAIN_NAME = "test";
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant CHILD_WIMX_TOKEN = address(0xabc);
    address constant NATIVE_ETH = address(0xeee);
    ChildERC20 public childTokenTemplate;
    ChildERC20 public rootToken;
    address public childETHToken;
    ChildERC20Bridge public childBridge;

    function setUp() public {
        rootToken = new ChildERC20();
        rootToken.initialize(address(456), "Test", "TST", 18);

        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        childBridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: pauser,
            unpauser: unpauser,
            adaptorManager: address(this)
        });
        childBridge.initialize(
            roles,
            address(this),
            ROOT_BRIDGE_ADAPTOR,
            address(childTokenTemplate),
            ROOT_CHAIN_NAME,
            ROOT_IMX_TOKEN,
            CHILD_WIMX_TOKEN
        );
    }

    /**
     * RECEIVE
     */

    function test_NativeTransferFromWIMX() public {
        address caller = address(0x123a);
        payable(caller).transfer(2 ether);
        // forge inspect src/child/ChildERC20Bridge.sol:ChildERC20Bridge storageLayout | grep -B3 -A5 -i "wIMXToken"
        uint256 wIMXStorageSlot = 208;
        vm.store(address(childBridge), bytes32(wIMXStorageSlot), bytes32(uint256(uint160(caller))));

        vm.startPrank(caller);
        uint256 bal = address(childBridge).balance;
        (bool ok,) = address(childBridge).call{value: 1 ether}("");
        assert(ok);
        uint256 postBal = address(childBridge).balance;

        assertEq(bal + 1 ether, postBal, "balance not increased");
    }

    function test_RevertIf_NativeTransferIsFromNonWIMX() public {
        vm.expectRevert(NonWrappedNativeTransfer.selector);
        (bool ok,) = address(childBridge).call{value: 1 ether}("");
        assert(ok);
    }

    function test_RevertIf_NativeTransferWhenPaused() public {
        pause(IPausable(address(childBridge)));
        vm.expectRevert("Pausable: paused");
        (bool ok,) = address(childBridge).call{value: 1 ether}("");
        assert(ok);
    }

    function test_NativeTransferResumesFunctionalityAfterUnpausing() public {
        test_RevertIf_NativeTransferWhenPaused();
        unpause(IPausable(address(childBridge)));
        // Expect success case to pass
        test_NativeTransferFromWIMX();
    }

    /**
     * INITIALIZE
     */

    function test_Initialize() public {
        assertEq(address(childBridge.bridgeAdaptor()), address(address(this)), "bridgeAdaptor not set");
        assertEq(childBridge.rootERC20BridgeAdaptor(), ROOT_BRIDGE_ADAPTOR, "rootERC20BridgeAdaptor not set");
        assertEq(childBridge.childTokenTemplate(), address(childTokenTemplate), "childTokenTemplate not set");
        assertEq(childBridge.rootChain(), ROOT_CHAIN_NAME, "rootChain not set");
        assertEq(childBridge.rootIMXToken(), ROOT_IMX_TOKEN, "rootIMXToken not set");
        assertTrue(childBridge.hasRole(childBridge.ADAPTOR_MANAGER_ROLE(), address(this)), "adaptorManager not set");
        assertTrue(childBridge.hasRole(childBridge.PAUSER_ROLE(), pauser), "pauser not set");
        assertTrue(childBridge.hasRole(childBridge.UNPAUSER_ROLE(), unpauser), "unpauser not set");
        assertTrue(childBridge.hasRole(childBridge.ADAPTOR_MANAGER_ROLE(), address(this)), "adaptorManager not set");
        assertFalse(address(childBridge.childETHToken()) == address(0), "childETHToken not set");
        assertFalse(address(childBridge.childETHToken()).code.length == 0, "childETHToken contract empty");
    }

    function test_RevertIfInitializeTwice() public {
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });
        vm.expectRevert("Initializable: contract is already initialized");
        childBridge.initialize(
            roles,
            address(this),
            ROOT_BRIDGE_ADAPTOR,
            address(childTokenTemplate),
            ROOT_CHAIN_NAME,
            ROOT_IMX_TOKEN,
            CHILD_WIMX_TOKEN
        );
    }

    function test_RevertIf_InitializeWithAZeroAddressDefaultAdmin() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(0),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), ROOT_BRIDGE_ADAPTOR, address(1), ROOT_CHAIN_NAME, address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressPauser() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(0),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), ROOT_BRIDGE_ADAPTOR, address(1), ROOT_CHAIN_NAME, address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressUnpauser() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(0),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), ROOT_BRIDGE_ADAPTOR, address(1), ROOT_CHAIN_NAME, address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressAdapter() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(0), ROOT_BRIDGE_ADAPTOR, address(1), ROOT_CHAIN_NAME, address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressChildTemplate() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), ROOT_BRIDGE_ADAPTOR, address(0), ROOT_CHAIN_NAME, address(1), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressIMXToken() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(1), ROOT_BRIDGE_ADAPTOR, address(1), ROOT_CHAIN_NAME, address(0), address(1));
    }

    function test_RevertIf_InitializeWithAZeroAddressAll() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(ZeroAddress.selector);
        bridge.initialize(roles, address(0), ROOT_BRIDGE_ADAPTOR, address(0), ROOT_CHAIN_NAME, address(0), address(0));
    }

    function test_RevertIf_InitializeWithAnEmptyBridgeAdaptorString() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(InvalidRootERC20BridgeAdaptor.selector);
        bridge.initialize(
            roles, address(this), "", address(childTokenTemplate), ROOT_CHAIN_NAME, ROOT_IMX_TOKEN, CHILD_WIMX_TOKEN
        );
    }

    function test_RevertIf_InitializeWithAnEmptyChainNameString() public {
        ChildERC20Bridge bridge = new ChildERC20Bridge();
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(InvalidRootChain.selector);
        bridge.initialize(
            roles, address(this), ROOT_BRIDGE_ADAPTOR, address(childTokenTemplate), "", ROOT_IMX_TOKEN, CHILD_WIMX_TOKEN
        );
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

    /**
     * UPDATE CHILD BRIDGE ADAPTOR
     */

    function test_updateChildBridgeAdaptor_UpdatesChildBridgeAdaptor() public {
        address newAdaptorAddress = address(0x11111);

        assertEq(address(childBridge.bridgeAdaptor()), address(this), "bridgeAdaptor not set");
        childBridge.updateChildBridgeAdaptor(newAdaptorAddress);
        assertEq(address(childBridge.bridgeAdaptor()), newAdaptorAddress, "bridgeAdaptor not updated");
    }

    function test_updateChildBridgeAdpator_EmitsEvent() public {
        address newAdaptorAddress = address(0x11111);

        vm.expectEmit(true, true, false, false, address(childBridge));
        emit ChildBridgeAdaptorUpdated(address(childBridge.bridgeAdaptor()), newAdaptorAddress);

        childBridge.updateChildBridgeAdaptor(newAdaptorAddress);
    }

    function test_RevertIf_updateChildBridgeAdaptorCalledByNotAdaptorManager() public {
        address caller = address(0xf00f00);
        bytes32 role = childBridge.ADAPTOR_MANAGER_ROLE();
        vm.prank(caller);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(caller),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        childBridge.updateChildBridgeAdaptor(address(0x11111));
    }

    function test_RevertIf_updateChildBridgeAdaptorCalledWithZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        childBridge.updateChildBridgeAdaptor(address(0));
    }

    /**
     * UPDATE ROOT BRIDGE ADAPTOR
     */

    function test_updateRootBridgeAdaptor_UpdatesRootBridgeAdaptor() public {
        string memory newAdaptor = "newAdaptor";

        assertEq(childBridge.rootERC20BridgeAdaptor(), ROOT_BRIDGE_ADAPTOR, "rootERC20BridgeAdaptor not set");
        childBridge.updateRootBridgeAdaptor(newAdaptor);
        assertEq(childBridge.rootERC20BridgeAdaptor(), newAdaptor, "rootERC20BridgeAdaptor not updated");
    }

    function test_updateRootBridgeAdaptor_EmitsEvent() public {
        string memory newAdaptor = "newAdaptor";

        vm.expectEmit(true, true, false, false, address(childBridge));
        emit RootBridgeAdaptorUpdated(childBridge.rootERC20BridgeAdaptor(), newAdaptor);

        childBridge.updateRootBridgeAdaptor(newAdaptor);
    }

    function test_RevertIf_updateRootBridgeAdaptorCalledByNotTargetManager() public {
        address caller = address(0xf00f00);
        bytes32 role = childBridge.ADAPTOR_MANAGER_ROLE();
        vm.prank(caller);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(caller),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        childBridge.updateRootBridgeAdaptor("newAdaptor");
    }

    function test_RevertIf_updateRootBridgeAdaptorCalledWithEmptyString() public {
        vm.expectRevert(InvalidRootERC20BridgeAdaptor.selector);
        childBridge.updateRootBridgeAdaptor("");
    }

    /**
     * ON MESSAGE RECIEVE
     */

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
        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Data too short"));
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_onMessageReceiveCalledWithDataInvalid() public {
        bytes memory data =
            abi.encode("FAKEDATA", address(rootToken), rootToken.name(), rootToken.symbol(), rootToken.decimals());

        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Unsupported action signature"));
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
        bytes memory data = abi.encode(childBridge.MAP_TOKEN_SIG(), ROOT_IMX_TOKEN, "ImmutableX", "IMX", 18);
        vm.expectRevert(CantMapIMX.selector);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, data);
    }

    function test_RevertIf_mapTokenCalledWithETHAddress() public {
        bytes memory data = abi.encode(childBridge.MAP_TOKEN_SIG(), NATIVE_ETH, "Ethereum", "ETH", 18);
        vm.expectRevert(CantMapETH.selector);
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

    /**
     * DEPOSIT ETH
     */

    function test_RevertsIf_OnMessageReceiveWhenPaused() public {
        pause(IPausable(address(childBridge)));
        bytes memory depositData =
            abi.encode(childBridge.DEPOSIT_SIG(), address(NATIVE_ETH), address(100), address(200), 1000);
        vm.expectRevert("Pausable: paused");
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_OnMessageReceiveResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_OnMessageReceiveWhenPaused();
        unpause(IPausable(address(childBridge)));
        // Expect success case to pass
        test_onMessageReceive_DepositETH_EmitsETHDepositEvent();
    }

    function test_onMessageReceive_DepositETH_EmitsETHDepositEvent() public {
        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(NATIVE_ETH), sender, receiver, amount);

        address predictedChildETHToken = Clones.predictDeterministicAddress(
            address(childTokenTemplate), keccak256(abi.encodePacked(NATIVE_ETH)), address(childBridge)
        );

        vm.expectEmit(address(childBridge));
        emit NativeEthDeposit(address(NATIVE_ETH), predictedChildETHToken, sender, receiver, amount);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_onMessageReceive_DepositETH_TransfersTokensToReceiver() public {
        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(NATIVE_ETH), sender, receiver, amount);

        address predictedChildETHToken = Clones.predictDeterministicAddress(
            address(childTokenTemplate), keccak256(abi.encodePacked(NATIVE_ETH)), address(childBridge)
        );

        uint256 receiverPreBal = ChildERC20(predictedChildETHToken).balanceOf(receiver);

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);

        assertEq(
            ChildERC20(predictedChildETHToken).balanceOf(receiver),
            receiverPreBal + amount,
            "receiver balance not increased"
        );
    }

    function test_onMessageReceive_DepositETH_IncreasesTotalSupply() public {
        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(NATIVE_ETH), sender, receiver, amount);

        address predictedChildETHToken = Clones.predictDeterministicAddress(
            address(childTokenTemplate), keccak256(abi.encodePacked(NATIVE_ETH)), address(childBridge)
        );
        uint256 totalSupplyPre = ChildERC20(predictedChildETHToken).totalSupply();

        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);

        assertEq(ChildERC20(predictedChildETHToken).totalSupply(), totalSupplyPre + amount, "totalSupply not increased");
    }

    /**
     * DEPOSIT
     */

    function test_onMessageReceive_DepositIMX_EmitsIMXDepositEvent() public {
        uint256 fundedAmount = 10 ether;
        vm.deal(address(childBridge), fundedAmount);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1 ether;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), ROOT_IMX_TOKEN, sender, receiver, amount);

        vm.expectEmit(address(childBridge));
        emit IMXDeposit(ROOT_IMX_TOKEN, sender, receiver, amount);
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_onMessageReceive_DepositIMX_BalancesChanged() public {
        uint256 fundedAmount = 10 ether;
        vm.deal(address(childBridge), fundedAmount);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1 ether;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), ROOT_IMX_TOKEN, sender, receiver, amount);

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

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), ROOT_IMX_TOKEN, sender, receiver, amount);

        vm.expectRevert("Address: insufficient balance");
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, depositData);
    }

    function test_onMessageReceive_Deposit_EmitsChildChainERC20DepositEvent() public {
        setupChildDeposit(rootToken, childBridge, ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR);

        address sender = address(100);
        address receiver = address(200);
        uint256 amount = 1000;

        bytes memory depositData = abi.encode(childBridge.DEPOSIT_SIG(), address(rootToken), sender, receiver, amount);

        address childToken = childBridge.rootTokenToChildToken(address(rootToken));

        vm.expectEmit(address(childBridge));
        emit ChildChainERC20Deposit(address(rootToken), childToken, sender, receiver, amount);
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
            // Found by running `forge inspect src/child/ChildERC20Bridge.sol:ChildERC20Bridge storageLayout | grep -B3 -A5 -i "rootTokenToChildToken"`
            uint256 rootTokenToChildTokenMappingSlot = 201;
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
