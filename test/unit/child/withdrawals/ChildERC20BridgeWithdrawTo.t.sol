// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20Bridge,
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors
} from "../../../../src/child/ChildERC20Bridge.sol";
import {IChildERC20, ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../mocks/root/MockAdaptor.sol";
import {Utils, IPausable} from "../../../utils.t.sol";

contract ChildERC20BridgeWithdrawToUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));
    string constant ROOT_CHAIN_NAME = "test";
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant WIMX_TOKEN_ADDRESS = address(0xabc);
    address constant NATIVE_ETH = address(0xeee);
    ChildERC20 public childTokenTemplate;
    ChildERC20 public rootToken;
    ChildERC20 public childToken;
    address public childETHToken;
    ChildERC20Bridge public childBridge;
    MockAdaptor public mockAdaptor;

    function setUp() public {
        rootToken = new ChildERC20();
        rootToken.initialize(address(456), "Test", "TST", 18);

        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        mockAdaptor = new MockAdaptor();

        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: pauser,
            unpauser: unpauser,
            adaptorManager: address(this),
            initialDepositor: address(this),
            treasuryManager: address(this)
        });
        childBridge = new ChildERC20Bridge();
        childBridge.initialize(
            roles,
            address(mockAdaptor),
            ROOT_BRIDGE_ADAPTOR,
            address(childTokenTemplate),
            ROOT_CHAIN_NAME,
            ROOT_IMX_TOKEN,
            WIMX_TOKEN_ADDRESS
        );

        bytes memory mapTokenData =
            abi.encode(MAP_TOKEN_SIG, rootToken, rootToken.name(), rootToken.symbol(), rootToken.decimals());

        vm.prank(address(mockAdaptor));
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, mapTokenData);

        childToken = ChildERC20(childBridge.rootTokenToChildToken(address(rootToken)));
        vm.prank(address(childBridge));
        childToken.mint(address(this), 1000000 ether);
        childToken.approve(address(childBridge), 1000000 ether);
    }

    /**
     * WITHDRAW  TO
     */

    function test_RevertsIf_WithdrawToWhenPaused() public {
        pause(IPausable(address(childBridge)));
        vm.expectRevert("Pausable: paused");
        childBridge.withdrawTo{value: 1 ether}(IChildERC20(address(childToken)), address(this), 100);
    }

    function test_WithdrawToResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_WithdrawToWhenPaused();
        unpause(IPausable(address(childBridge)));
        // Expect success case to pass
        test_withdrawTo_CallsBridgeAdaptor();
    }

    function test_RevertsIf_WithdrawToCalledWithZeroReceiver() public {
        uint256 withdrawAmount = 300;

        vm.expectRevert(ZeroAddress.selector);
        childBridge.withdrawTo{value: 1 ether}(IChildERC20(address(2222222)), address(0), withdrawAmount);
    }

    function test_RevertsIf_WithdrawToCalledWithZeroFee() public {
        uint256 withdrawAmount = 300;

        vm.expectRevert(NoGas.selector);
        childBridge.withdrawTo(IChildERC20(address(2222222)), address(this), withdrawAmount);
    }

    function test_RevertsIf_WithdrawToCalledWithEmptyChildToken() public {
        vm.expectRevert(EmptyTokenContract.selector);
        childBridge.withdrawTo{value: 1 ether}(IChildERC20(address(2222222)), address(this), 100);
    }

    function test_RevertsIf_WithdrawToCalledWithUnmappedToken() public {
        ChildERC20 newToken = new ChildERC20();
        newToken.initialize(address(123), "Test", "TST", 18);
        vm.expectRevert(NotMapped.selector);
        childBridge.withdrawTo{value: 1 ether}(IChildERC20(address(newToken)), address(this), 100);
    }

    function test_RevertsIf_WithdrawToCalledWithAChildTokenWithUnsetRootToken() public {
        /* First, set rootToken of mapped token to zero */

        // Found by running `forge inspect src/child/ChildERC20.sol:ChildERC20 storageLayout | grep -B3 -A5 -i "rootToken"`
        uint256 rootTokenSlot = 109;
        bytes32 rootTokenSlotBytes32 = bytes32(rootTokenSlot);
        vm.store(address(childToken), rootTokenSlotBytes32, bytes32(uint256(uint160(address(0)))));

        /* Then, set rootTokenToChildToken[address(0)] to the child token (to bypass the NotMapped check) */

        // Found by running `forge inspect src/child/ChildERC20Bridge.sol:ChildERC20Bridge storageLayout | grep -B3 -A5 -i "rootTokenToChildToken"`
        uint256 rootTokenToChildTokenMappingSlot = 251;
        bytes32 slot = getMappingStorageSlotFor(address(0), rootTokenToChildTokenMappingSlot);
        bytes32 data = bytes32(uint256(uint160(address(childToken))));

        vm.store(address(childBridge), slot, data);

        vm.expectRevert(ZeroAddressRootToken.selector);
        childBridge.withdrawTo{value: 1 ether}(IChildERC20(address(childToken)), address(this), 100);
    }

    function test_RevertsIf_WithdrawToCalledWithAChildTokenThatHasWrongBridge() public {
        // Found by running `forge inspect src/child/ChildERC20.sol:ChildERC20 storageLayout | grep -B3 -A5 -i "bridge"`
        uint256 bridgeSlot = 108;
        bytes32 bridgeSlotBytes32 = bytes32(bridgeSlot);
        vm.store(address(childToken), bridgeSlotBytes32, bytes32(uint256(uint160(address(0x123)))));

        vm.expectRevert(IncorrectBridgeAddress.selector);
        childBridge.withdrawTo{value: 1 ether}(IChildERC20(address(childToken)), address(this), 100);
    }

    function test_RevertsIf_WithdrawToWhenBurnFails() public {
        // Replace the childToken with one that always returns `false` on failure.
        deployCodeTo("ChildERC20FailOnBurn.sol", address(childToken));

        vm.expectRevert(BurnFailed.selector);
        childBridge.withdrawTo{value: 1 ether}(IChildERC20(address(childToken)), address(this), 100);
    }

    function test_withdrawTo_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, address(rootToken), address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdrawTo{value: withdrawFee}(IChildERC20(address(childToken)), address(this), withdrawAmount);
    }

    function test_withdrawTo_EmitsERC20WithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainERC20Withdraw(
            address(rootToken), address(childToken), address(this), address(this), withdrawAmount
        );

        childBridge.withdrawTo{value: withdrawFee}(IChildERC20(address(childToken)), address(this), withdrawAmount);
    }

    function test_withdrawTo_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = childToken.balanceOf(address(this));

        childBridge.withdrawTo{value: withdrawFee}(IChildERC20(address(childToken)), address(this), withdrawAmount);

        uint256 postBal = childToken.balanceOf(address(this));
        assertEq(postBal, preBal - withdrawAmount);
    }

    function test_withdrawTo_ReducesTotalSupply() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preTotalSupply = childToken.totalSupply();

        childBridge.withdrawTo{value: withdrawFee}(IChildERC20(address(childToken)), address(this), withdrawAmount);

        uint256 postTotalSupply = childToken.totalSupply();
        assertEq(postTotalSupply, preTotalSupply - withdrawAmount);
    }

    function test_withdrawTo_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(mockAdaptor).balance;
        uint256 thisPreBal = address(this).balance;

        childBridge.withdrawTo{value: withdrawFee}(IChildERC20(address(childToken)), address(this), withdrawAmount);

        uint256 postBal = address(mockAdaptor).balance;
        uint256 thisPostBal = address(this).balance;

        assertEq(postBal, preBal + withdrawFee);
        assertEq(thisPostBal, thisPreBal - withdrawFee);
    }

    function test_withdrawTo_ToDifferentReceiverCallsMockAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;
        address receiver = address(123);

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, address(rootToken), address(this), receiver, withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdrawTo{value: withdrawFee}(IChildERC20(address(childToken)), receiver, withdrawAmount);
    }
}
