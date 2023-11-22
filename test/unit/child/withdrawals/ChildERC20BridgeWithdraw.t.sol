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

contract ChildERC20BridgeWithdrawUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    address constant ROOT_BRIDGE = address(3);
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WIMX_TOKEN_ADDRESS = address(0xabc);
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
            treasuryManager: address(this)
        });
        childBridge = new ChildERC20Bridge();
        childBridge.initialize(
            roles, address(mockAdaptor), address(childTokenTemplate), ROOT_IMX_TOKEN, WIMX_TOKEN_ADDRESS
        );

        bytes memory mapTokenData =
            abi.encode(MAP_TOKEN_SIG, rootToken, rootToken.name(), rootToken.symbol(), rootToken.decimals());

        vm.prank(address(mockAdaptor));
        childBridge.onMessageReceive(mapTokenData);

        childToken = ChildERC20(childBridge.rootTokenToChildToken(address(rootToken)));
        vm.prank(address(childBridge));
        childToken.mint(address(this), 1000000 ether);
        childToken.approve(address(childBridge), 1000000 ether);
    }

    /**
     * WITHDRAW
     */

    function test_RevertsIf_WithdrawWhenPaused() public {
        pause(IPausable(address(childBridge)));
        vm.expectRevert("Pausable: paused");
        childBridge.withdraw{value: 1 ether}(IChildERC20(address(childToken)), 100);
    }

    function test_WithdrawResumesFunctionalityAfterUnpausing() public {
        test_RevertsIf_WithdrawWhenPaused();
        unpause(IPausable(address(childBridge)));
        // Expect success case to pass
        test_withdraw_CallsBridgeAdaptor();
    }

    function test_RevertsIf_WithdrawCalledWithZeroFee() public {
        uint256 withdrawAmount = 100;

        vm.expectRevert(NoGas.selector);
        childBridge.withdraw(IChildERC20(address(2222222)), withdrawAmount);
    }

    function test_RevertsIf_WithdrawCalledWithEmptyChildToken() public {
        vm.expectRevert(EmptyTokenContract.selector);
        childBridge.withdraw{value: 1 ether}(IChildERC20(address(2222222)), 100);
    }

    function test_RevertsIf_WithdrawCalledWithUnmappedToken() public {
        ChildERC20 newToken = new ChildERC20();
        newToken.initialize(address(123), "Test", "TST", 18);
        vm.expectRevert(NotMapped.selector);
        childBridge.withdraw{value: 1 ether}(IChildERC20(address(newToken)), 100);
    }

    function test_RevertsIf_WithdrawCalledWithAChildTokenWithUnsetRootToken() public {
        /* First, set rootToken of mapped token to zero */

        // Found by running `forge inspect src/child/ChildERC20.sol:ChildERC20 storageLayout | grep -B3 -A5 -i "rootToken"`
        uint256 rootTokenSlot = 109;
        bytes32 rootTokenSlotBytes32 = bytes32(rootTokenSlot);
        vm.store(address(childToken), rootTokenSlotBytes32, bytes32(uint256(uint160(address(0)))));

        /* Then, set rootTokenToChildToken[address(0)] to the child token (to bypass the NotMapped check) */

        // Slot is 2 because of the Ownable, Initializable contracts coming first.
        // Found by running `forge inspect src/child/ChildERC20Bridge.sol:ChildERC20Bridge storageLayout | grep -B3 -A5 -i "rootTokenToChildToken"`
        uint256 rootTokenToChildTokenMappingSlot = 251;
        bytes32 slot = getMappingStorageSlotFor(address(0), rootTokenToChildTokenMappingSlot);
        bytes32 data = bytes32(uint256(uint160(address(childToken))));

        vm.store(address(childBridge), slot, data);

        vm.expectRevert(ZeroAddressRootToken.selector);
        childBridge.withdraw{value: 1 ether}(IChildERC20(address(childToken)), 100);
    }

    function test_RevertsIf_WithdrawCalledWithAChildTokenThatHasWrongBridge() public {
        // Found by running `forge inspect src/child/ChildERC20.sol:ChildERC20 storageLayout | grep -B3 -A5 -i "bridge"`
        uint256 bridgeSlot = 108;
        bytes32 bridgeSlotBytes32 = bytes32(bridgeSlot);
        vm.store(address(childToken), bridgeSlotBytes32, bytes32(uint256(uint160(address(0x123)))));

        vm.expectRevert(IncorrectBridgeAddress.selector);
        childBridge.withdraw{value: 1 ether}(IChildERC20(address(childToken)), 100);
    }

    function test_RevertsIf_WithdrawWhenBurnFails() public {
        // Replace the childToken with one that always returns `false` on failure.
        deployCodeTo("ChildERC20FailOnBurn.sol", address(childToken));

        vm.expectRevert(BurnFailed.selector);
        childBridge.withdraw{value: 1 ether}(IChildERC20(address(childToken)), 100);
    }

    function test_withdraw_CallsBridgeAdaptor() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        bytes memory predictedPayload =
            abi.encode(WITHDRAW_SIG, address(rootToken), address(this), address(this), withdrawAmount);

        vm.expectCall(
            address(mockAdaptor),
            withdrawFee,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, address(this))
        );

        childBridge.withdraw{value: withdrawFee}(IChildERC20(address(childToken)), withdrawAmount);
    }

    function test_withdraw_EmitsERC20WithdrawEvent() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        vm.expectEmit(address(childBridge));
        emit ChildChainERC20Withdraw(
            address(rootToken), address(childToken), address(this), address(this), withdrawAmount
        );

        childBridge.withdraw{value: withdrawFee}(IChildERC20(address(childToken)), withdrawAmount);
    }

    function test_withdraw_ReducesBalance() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = childToken.balanceOf(address(this));

        childBridge.withdraw{value: withdrawFee}(IChildERC20(address(childToken)), withdrawAmount);

        uint256 postBal = childToken.balanceOf(address(this));
        assertEq(postBal, preBal - withdrawAmount, "Balance not reduced");
    }

    function test_withdraw_ReducesTotalSupply() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preTotalSupply = childToken.totalSupply();

        childBridge.withdraw{value: withdrawFee}(IChildERC20(address(childToken)), withdrawAmount);

        uint256 postTotalSupply = childToken.totalSupply();
        assertEq(postTotalSupply, preTotalSupply - withdrawAmount, "total supply not reduced");
    }

    function test_withdraw_PaysFee() public {
        uint256 withdrawFee = 300;
        uint256 withdrawAmount = 7 ether;

        uint256 preBal = address(mockAdaptor).balance;
        uint256 thisPreBal = address(this).balance;

        childBridge.withdraw{value: withdrawFee}(IChildERC20(address(childToken)), withdrawAmount);

        uint256 postBal = address(mockAdaptor).balance;
        uint256 thisPostBal = address(this).balance;

        assertEq(postBal, preBal + withdrawFee, "Adaptor balance not increased");
        assertEq(thisPostBal, thisPreBal - withdrawFee, "withdrawer's balance not decreased");
    }
}
