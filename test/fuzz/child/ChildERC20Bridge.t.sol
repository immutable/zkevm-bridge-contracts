// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {
    ChildERC20Bridge,
    IChildERC20Bridge,
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors
} from "../../../src/child/ChildERC20Bridge.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../mocks/root/MockAdaptor.sol";
import {WIMX} from "../../../src/child/WIMX.sol";
import {IChildERC20} from "../../../src/interfaces/child/IChildERC20.sol";

contract ChildERC20BridgeTest is Test, IChildERC20BridgeEvents {
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant DEPOSIT_SIG = keccak256("DEPOSIT");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");
    address public constant NATIVE_ETH = address(0xeee);
    address public constant NATIVE_IMX = address(0xfff);

    address constant ROOT_IMX_TOKEN = address(0xccc);
    ChildERC20 public childTokenTemplate;
    WIMX public wIMX;
    MockAdaptor public mockAdaptor;

    ChildERC20Bridge bridge;

    receive() external payable {}

    function setUp() public {
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this),
            initialDepositor: address(this),
            treasuryManager: address(this)
        });

        bridge = new ChildERC20Bridge(address(this));

        wIMX = new WIMX();

        mockAdaptor = new MockAdaptor();

        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        bridge.initialize(roles, address(mockAdaptor), address(childTokenTemplate), ROOT_IMX_TOKEN, address(wIMX));
    }

    function testFuzz_MapToken(address rootToken, string memory name, string memory symbol, uint8 decimals) public {
        vm.assume(rootToken > address(10) && bytes(name).length != 0 && bytes(symbol).length != 0 && decimals > 0);
        vm.assume(rootToken != bridge.NATIVE_ETH() && rootToken != bridge.NATIVE_IMX() && rootToken != ROOT_IMX_TOKEN);

        // Map token on L1 triggers call on child bridge.
        bytes memory data = abi.encode(MAP_TOKEN_SIG, rootToken, name, symbol, decimals);

        address childTokenAddress = Clones.predictDeterministicAddress(
            address(childTokenTemplate), keccak256(abi.encodePacked(rootToken)), address(bridge)
        );
        vm.expectEmit(address(bridge));
        emit L2TokenMapped(rootToken, childTokenAddress);

        vm.startPrank(address(mockAdaptor));
        bridge.onMessageReceive(data);

        assertEq(
            bridge.rootTokenToChildToken(rootToken),
            childTokenAddress,
            "Child actual token address should match predicated address"
        );

        vm.stopPrank();
    }

    function testFuzz_DepositIMX(address sender, address recipient, uint256 depositAmt) public {
        vm.assume(sender > address(10) && recipient > address(10) && depositAmt > 0);
        vm.assume(sender.code.length == 0 && recipient.code.length == 0);
        vm.assume(recipient.balance == 0);
        vm.deal(address(bridge), depositAmt);

        assertEq(address(bridge).balance, depositAmt, "Bridge should have depositAmt of IMX");

        // Deposit IMX on L1 triggers call on child bridge.
        bytes memory data = abi.encode(DEPOSIT_SIG, bridge.rootIMXToken(), sender, recipient, depositAmt);

        vm.expectEmit(address(bridge));
        emit IMXDeposit(bridge.rootIMXToken(), sender, recipient, depositAmt);
        vm.startPrank(address(mockAdaptor));
        bridge.onMessageReceive(data);

        assertEq(address(bridge).balance, 0, "Bridge should have 0 IMX");
        assertEq(recipient.balance, depositAmt, "User should have depositAmt of IMX");
    }

    function testFuzz_WithdrawIMX(address user, uint256 balance, uint256 gasAmt, uint256 withdrawAmt) public {
        vm.assume(user > address(10));
        vm.assume(user.code.length == 0);
        vm.assume(balance > 0 && withdrawAmt > 0 && gasAmt > 0);
        vm.assume(balance < type(uint256).max - gasAmt);
        vm.assume(balance > withdrawAmt && balance - withdrawAmt > gasAmt);

        // Fund user
        vm.deal(user, balance);
        vm.startPrank(user);

        // Before withdraw
        assertEq(user.balance, balance, "User should have given balance of IMX");
        assertEq(address(bridge).balance, 0, "Bridge should have 0 balance of IMX");

        // Over-withdraw should fail
        vm.expectRevert();
        bridge.withdrawIMX{value: gasAmt + balance}(balance);

        // Normal withdraw should succeed
        bytes memory predictedPayload = abi.encode(WITHDRAW_SIG, bridge.rootIMXToken(), user, user, withdrawAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, user)
        );
        vm.expectEmit(address(bridge));
        emit ChildChainNativeIMXWithdraw(bridge.rootIMXToken(), user, user, withdrawAmt);
        bridge.withdrawIMX{value: gasAmt + withdrawAmt}(withdrawAmt);

        assertEq(
            user.balance, balance - gasAmt - withdrawAmt, "User should have balance - gasAmt - withdrawAmt of balance"
        );

        vm.stopPrank();
    }

    function testFuzz_WithdrawWIMX(address user, uint256 balance, uint256 gasAmt, uint256 withdrawAmt) public {
        vm.assume(user > address(10));
        vm.assume(user.code.length == 0);
        vm.assume(balance > 0 && withdrawAmt > 0 && gasAmt > 0);
        vm.assume(balance < type(uint256).max);
        vm.assume(balance > withdrawAmt && balance - withdrawAmt > gasAmt);

        // Fund user
        vm.deal(user, balance);
        vm.startPrank(user);

        // Wrap IMX
        wIMX.deposit{value: balance}();

        vm.deal(user, gasAmt);

        assertEq(user.balance, gasAmt, "User should have gasAmt of balance");
        assertEq(wIMX.balanceOf(user), balance, "User should have given balance");

        // Withdraw without approval should fail
        vm.expectRevert();
        bridge.withdrawWIMX{value: gasAmt}(withdrawAmt);

        // Over-withdraw should fail
        wIMX.approve(address(bridge), balance + 1);
        vm.expectRevert();
        bridge.withdrawWIMX{value: gasAmt}(balance + 1);

        // Withdraw within balance and allowance should go through
        wIMX.approve(address(bridge), withdrawAmt);

        bytes memory predictedPayload = abi.encode(WITHDRAW_SIG, bridge.rootIMXToken(), user, user, withdrawAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, user)
        );

        vm.expectEmit(address(bridge));
        emit ChildChainWrappedIMXWithdraw(bridge.rootIMXToken(), user, user, withdrawAmt);

        bridge.withdrawWIMX{value: gasAmt}(withdrawAmt);

        assertEq(user.balance, 0, "User should have 0 balance");
        assertEq(wIMX.balanceOf(user), balance - withdrawAmt, "User should have balance - withdrawAmt of wIMX");

        vm.stopPrank();
    }

    function testFuzz_DepositETH(address sender, address recipient, uint256 depositAmt) public {
        vm.assume(sender > address(10) && recipient > address(10) && depositAmt > 0);
        vm.assume(sender.code.length == 0 && recipient.code.length == 0);
        assertEq(IChildERC20(bridge.childETHToken()).balanceOf(recipient), 0, "Recipient should have 0 ETH");

        // Deposit ETH on L1 triggers call on child bridge.
        bytes memory data = abi.encode(DEPOSIT_SIG, bridge.NATIVE_ETH(), sender, recipient, depositAmt);

        vm.expectEmit(address(bridge));
        emit NativeEthDeposit(bridge.NATIVE_ETH(), bridge.childETHToken(), sender, recipient, depositAmt);
        vm.startPrank(address(mockAdaptor));
        bridge.onMessageReceive(data);

        assertEq(
            IChildERC20(bridge.childETHToken()).balanceOf(recipient),
            depositAmt,
            "Recipient should have depositAmt of ETH"
        );
    }

    function testFuzz_WithdrawETH(address user, uint256 balance, uint256 gasAmt, uint256 withdrawAmt) public {
        vm.assume(user > address(10));
        vm.assume(user.code.length == 0);
        vm.assume(balance > 0 && withdrawAmt > 0 && gasAmt > 0);
        vm.assume(balance < type(uint256).max);
        vm.assume(balance > withdrawAmt);

        // Fund user
        vm.deal(user, gasAmt);
        // Mint token to user
        vm.startPrank(address(bridge));
        IChildERC20 childETH = IChildERC20(bridge.childETHToken());
        childETH.mint(user, balance);

        assertEq(user.balance, gasAmt, "User should have given gasAmt of balance");
        assertEq(childETH.balanceOf(user), balance, "User should have given balance of ETH");

        vm.startPrank(user);

        // Over-withdraw should fail
        vm.expectRevert();
        bridge.withdrawETH{value: gasAmt}(balance + 1);

        // Withdraw within balance
        bytes memory predictedPayload = abi.encode(WITHDRAW_SIG, bridge.NATIVE_ETH(), user, user, withdrawAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, user)
        );

        vm.expectEmit(address(bridge));
        emit ChildChainEthWithdraw(user, user, withdrawAmt);

        bridge.withdrawETH{value: gasAmt}(withdrawAmt);

        assertEq(user.balance, 0, "User should have 0 balance");
        assertEq(childETH.balanceOf(user), balance - withdrawAmt, "User should have balance - withdrawAmt of ETH");

        vm.stopPrank();
    }

    function testFuzz_DepositERC20(address rootToken, address sender, address recipient, uint256 depositAmt) public {
        vm.assume(
            rootToken > address(10) && rootToken != bridge.NATIVE_ETH() && rootToken != bridge.NATIVE_IMX()
                && rootToken != ROOT_IMX_TOKEN
        );
        vm.assume(sender > address(10) && recipient > address(10) && depositAmt > 0);

        // Map
        bytes memory data = abi.encode(MAP_TOKEN_SIG, rootToken, "Test token", "Test", 18);
        vm.startPrank(address(mockAdaptor));
        bridge.onMessageReceive(data);

        address childTokenAddr = bridge.rootTokenToChildToken(rootToken);
        IChildERC20 childToken = IChildERC20(childTokenAddr);

        assertEq(childToken.balanceOf(recipient), 0, "Recipient should have 0 token");

        // Map token on L1 triggers call on child bridge.
        data = abi.encode(DEPOSIT_SIG, rootToken, sender, recipient, depositAmt);

        vm.expectEmit(address(bridge));
        emit ChildChainERC20Deposit(rootToken, childTokenAddr, sender, recipient, depositAmt);
        vm.startPrank(address(mockAdaptor));
        bridge.onMessageReceive(data);

        assertEq(childToken.balanceOf(recipient), depositAmt, "Recipient should have depositAmt token");
    }

    function testFuzz_WithdrawERC20(
        address rootToken,
        address user,
        uint256 balance,
        uint256 gasAmt,
        uint256 withdrawAmt
    ) public {
        vm.assume(rootToken != bridge.NATIVE_ETH() && rootToken != bridge.NATIVE_IMX() && rootToken != ROOT_IMX_TOKEN);
        vm.assume(rootToken > address(10) && user > address(10));
        vm.assume(balance > 0 && withdrawAmt > 0 && gasAmt > 0);
        vm.assume(balance < type(uint256).max);
        vm.assume(balance > withdrawAmt);

        // Map
        bytes memory data = abi.encode(MAP_TOKEN_SIG, rootToken, "Test token", "Test", 18);
        vm.startPrank(address(mockAdaptor));
        bridge.onMessageReceive(data);

        address childTokenAddr = bridge.rootTokenToChildToken(rootToken);

        vm.deal(user, gasAmt);
        // Mint token to user
        vm.startPrank(address(bridge));
        IChildERC20 childToken = IChildERC20(childTokenAddr);
        childToken.mint(user, balance);

        assertEq(user.balance, gasAmt, "User should have given gasAmt of balance");
        assertEq(childToken.balanceOf(user), balance, "User should have given balance of token");

        // Over-withdraw
        vm.startPrank(user);
        vm.expectRevert();
        bridge.withdraw{value: gasAmt}(childToken, balance + 1);

        // Withdraw within balance
        bytes memory predictedPayload = abi.encode(WITHDRAW_SIG, rootToken, user, user, withdrawAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, user)
        );

        vm.expectEmit(address(bridge));
        emit ChildChainERC20Withdraw(rootToken, childTokenAddr, user, user, withdrawAmt);

        bridge.withdraw{value: gasAmt}(childToken, withdrawAmt);

        assertEq(user.balance, 0, "User should have 0 balance");
        assertEq(childToken.balanceOf(user), balance - withdrawAmt, "User should have balance - withdrawAmt of token");

        vm.stopPrank();
    }
}
