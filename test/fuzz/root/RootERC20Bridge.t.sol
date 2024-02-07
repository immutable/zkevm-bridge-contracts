// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {
    RootERC20Bridge,
    IRootERC20BridgeEvents,
    IERC20Metadata,
    IRootERC20BridgeErrors,
    IRootERC20Bridge
} from "../../../src/root/RootERC20Bridge.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {WETH} from "../../../src/lib/WETH.sol";
import {MockAdaptor} from "../../mocks/root/MockAdaptor.sol";

contract RootERC20BridgeTest is Test, IRootERC20BridgeEvents {
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant DEPOSIT_SIG = keccak256("DEPOSIT");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");
    address constant CHILD_BRIDGE = address(3);
    uint256 constant IMX_DEPOSITS_LIMIT = 10000 ether;

    ChildERC20 childTokenTemplate;
    ChildERC20 imxToken;
    WETH wETH;
    MockAdaptor mockAdaptor;
    RootERC20Bridge bridge;

    function setUp() public {
        mockAdaptor = new MockAdaptor();

        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        imxToken = new ChildERC20();
        imxToken.initialize(address(234), "IMX Token", "IMX", 18);

        wETH = new WETH();

        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        bridge = new RootERC20Bridge(address(this));
        bridge.initialize(
            roles,
            address(mockAdaptor),
            CHILD_BRIDGE,
            address(childTokenTemplate),
            address(imxToken),
            address(wETH),
            IMX_DEPOSITS_LIMIT
        );
    }

    function testFuzz_MapToken(address user, uint256 gasAmt, string memory name, string memory symbol, uint8 decimals)
        public
    {
        vm.assume(user != address(0));
        vm.assume(gasAmt > 0);
        vm.assume(bytes(name).length != 0 && bytes(symbol).length != 0 && decimals > 0);

        ChildERC20 rootToken = new ChildERC20();
        rootToken.initialize(address(123), name, symbol, decimals);

        // Map token on L1 triggers call to child bridge.
        vm.deal(user, gasAmt);
        vm.startPrank(user);

        address childTokenAddress = Clones.predictDeterministicAddress(
            address(childTokenTemplate), keccak256(abi.encodePacked(rootToken)), CHILD_BRIDGE
        );

        bytes memory predictedPayload = abi.encode(MAP_TOKEN_SIG, address(rootToken), name, symbol, decimals);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, user)
        );
        vm.expectEmit(address(bridge));
        emit L1TokenMapped(address(rootToken), childTokenAddress);
        bridge.mapToken{value: gasAmt}(IERC20Metadata(address(rootToken)));

        vm.stopPrank();
    }

    function testFuzz_DepositIMX(address sender, address recipient, uint256 balance, uint256 gasAmt, uint256 depositAmt)
        public
    {
        vm.assume(sender != address(0) && recipient != address(0));
        vm.assume(balance > 0 && depositAmt > 0 && gasAmt > 0);
        vm.assume(balance > depositAmt && balance < type(uint256).max);
        vm.assume(depositAmt <= IMX_DEPOSITS_LIMIT);

        // Fund user
        vm.deal(sender, gasAmt);
        imxToken.mint(sender, balance);
        vm.startPrank(sender);

        // Before deposit
        assertEq(sender.balance, gasAmt, "Sender should have gasAmt of balance");
        assertEq(imxToken.balanceOf(sender), balance, "Sender should have given balance of IMX");

        // Deposit without approval should fail
        vm.expectRevert();
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(imxToken)), recipient, depositAmt);

        // Deposit out of balance should fail
        imxToken.approve(address(bridge), balance + 1);
        vm.expectRevert();
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(imxToken)), recipient, balance + 1);

        // Deposit within balance and allowance should go through
        imxToken.approve(address(bridge), depositAmt);

        bytes memory predictedPayload = abi.encode(DEPOSIT_SIG, address(imxToken), sender, recipient, depositAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, sender)
        );
        vm.expectEmit(address(bridge));
        emit IMXDeposit(address(imxToken), sender, recipient, depositAmt);
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(imxToken)), recipient, depositAmt);

        // After deposit
        assertEq(sender.balance, 0, "Sender should have 0 balance");
        assertEq(imxToken.balanceOf(sender), balance - depositAmt, "Sender should have balance - depositAmt of IMX");

        assertEq(address(imxToken), bridge.rootIMXToken());

        vm.stopPrank();
    }

    function testFuzz_WithdrawIMX(address sender, address recipient, uint256 withdrawAmt) public {
        vm.assume(sender != address(0) && recipient != address(0) && withdrawAmt > 0);

        imxToken.mint(address(bridge), withdrawAmt);

        assertEq(imxToken.balanceOf(address(bridge)), withdrawAmt, "Bridge should have withdrawAmt balance");
        assertEq(imxToken.balanceOf(recipient), 0, "Recipient should have 0 balance");

        bytes memory data = abi.encode(WITHDRAW_SIG, address(imxToken), sender, recipient, withdrawAmt);

        vm.expectEmit(address(bridge));
        emit RootChainERC20Withdraw(address(imxToken), bridge.NATIVE_IMX(), sender, recipient, withdrawAmt);

        vm.startPrank(address(mockAdaptor));

        bridge.onMessageReceive(data);

        assertEq(imxToken.balanceOf(address(bridge)), 0, "Bridge should have 0 balance");
        assertEq(imxToken.balanceOf(recipient), withdrawAmt, "Recipient should have withdrawAmt balance");

        vm.stopPrank();
    }

    function testFuzz_DepositETH(address sender, address recipient, uint256 balance, uint256 gasAmt, uint256 depositAmt)
        public
    {
        vm.assume(sender != address(0) && recipient != address(0));
        vm.assume(balance > 0 && depositAmt > 0 && gasAmt > 0);
        vm.assume(balance > depositAmt && balance < type(uint256).max - gasAmt && balance - depositAmt > gasAmt);

        // Fund user
        vm.deal(sender, balance);
        vm.startPrank(sender);

        // Before deposit
        assertEq(sender.balance, balance, "Sender should have given balance");
        assertEq(address(bridge).balance, 0, "Bridge should have 0 balance");

        // Deposit out of balance should fail
        vm.expectRevert();
        bridge.depositToETH{value: balance + gasAmt + 1}(recipient, balance + 1);

        // Deposit within balance should go through
        bytes memory predictedPayload = abi.encode(DEPOSIT_SIG, bridge.NATIVE_ETH(), sender, recipient, depositAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, sender)
        );
        vm.expectEmit(address(bridge));
        emit NativeEthDeposit(bridge.NATIVE_ETH(), bridge.childETHToken(), sender, recipient, depositAmt);
        bridge.depositToETH{value: depositAmt + gasAmt}(recipient, depositAmt);

        // Before deposit
        assertEq(sender.balance, balance - gasAmt - depositAmt, "Sender should have balance - gasAmt - depositAmt");
        assertEq(address(bridge).balance, depositAmt, "Bridge should have depositAmt");

        vm.stopPrank();
    }

    function testFuzz_DepositWETH(
        address sender,
        address recipient,
        uint256 balance,
        uint256 gasAmt,
        uint256 depositAmt
    ) public {
        vm.assume(sender != address(0) && recipient != address(0));
        vm.assume(balance > 0 && depositAmt > 0 && gasAmt > 0);
        vm.assume(balance > depositAmt && balance < type(uint256).max - gasAmt && balance - depositAmt > gasAmt);

        // Fund user
        vm.deal(sender, balance);
        vm.startPrank(sender);
        wETH.deposit{value: balance}();

        vm.deal(sender, gasAmt);

        // Before deposit
        assertEq(sender.balance, gasAmt, "Sender should have gasAmt");
        assertEq(wETH.balanceOf(sender), balance, "Sender should have given balance of WETH");
        assertEq(wETH.balanceOf(address(bridge)), 0, "Bridge should have 0 balance of WETH");

        // Deposit without approval should fail
        vm.expectRevert();
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(wETH)), recipient, depositAmt);

        // Deposit out of balance should fail
        wETH.approve(address(bridge), balance + 1);
        vm.expectRevert();
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(wETH)), recipient, balance + 1);

        // Deposit within balance and allowance should go through
        wETH.approve(address(bridge), depositAmt);
        bytes memory predictedPayload = abi.encode(DEPOSIT_SIG, bridge.NATIVE_ETH(), sender, recipient, depositAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, sender)
        );
        vm.expectEmit(address(bridge));
        emit WETHDeposit(address(wETH), bridge.childETHToken(), sender, recipient, depositAmt);
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(wETH)), recipient, depositAmt);

        // After deposit
        assertEq(sender.balance, 0, "Sender should have 0");
        assertEq(wETH.balanceOf(sender), balance - depositAmt, "Sender should have balance - depositAmt of WETH");
        assertEq(address(bridge).balance, depositAmt, "Bridge should have depositAmt of ETH");

        vm.stopPrank();
    }

    function testFuzz_WithdrawETH(address sender, address recipient, uint256 withdrawAmt) public {
        vm.assume(sender != address(0) && recipient != address(0) && withdrawAmt > 0);

        vm.deal(address(bridge), withdrawAmt);

        assertEq(address(bridge).balance, withdrawAmt, "Bridge should have withdrawAmt balance");
        assertEq(recipient.balance, 0, "Recipient should have 0 balance");

        bytes memory data = abi.encode(WITHDRAW_SIG, bridge.NATIVE_ETH(), sender, recipient, withdrawAmt);

        vm.expectEmit(address(bridge));
        emit RootChainETHWithdraw(bridge.NATIVE_ETH(), bridge.childETHToken(), sender, recipient, withdrawAmt);

        vm.startPrank(address(mockAdaptor));

        bridge.onMessageReceive(data);

        assertEq(address(bridge).balance, 0, "Bridge should have 0 balance");
        assertEq(recipient.balance, withdrawAmt, "Recipient should have withdrawAmt balance");

        vm.stopPrank();
    }

    function testFuzz_DepositERC20(
        address sender,
        address recipient,
        uint256 balance,
        uint256 gasAmt,
        uint256 depositAmt
    ) public {
        vm.assume(sender != address(0) && recipient != address(0));
        vm.assume(balance > 0 && depositAmt > 0 && gasAmt > 0);
        vm.assume(balance > depositAmt && balance < type(uint256).max);
        vm.assume(gasAmt < 100);

        // Map token
        ChildERC20 rootToken = new ChildERC20();
        rootToken.initialize(address(123), "Test token", "TEST", 18);

        vm.deal(sender, gasAmt);
        rootToken.mint(sender, balance);
        vm.startPrank(sender);

        bridge.mapToken{value: gasAmt}(IERC20Metadata(address(rootToken)));

        vm.deal(sender, gasAmt);

        // Before deposit
        assertEq(rootToken.balanceOf(sender), balance, "Sender should have given balance of ERC20");
        assertEq(rootToken.balanceOf(address(bridge)), 0, "Bridge should have 0 balance of ERC20");

        // Deposit without approval should fail
        vm.expectRevert();
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(rootToken)), recipient, depositAmt);

        // Deposit out of balance should fail
        rootToken.approve(address(bridge), balance + 1);
        vm.expectRevert();
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(rootToken)), recipient, balance + 1);

        // Deposit within balance and allowance should go through
        rootToken.approve(address(bridge), depositAmt);
        bytes memory predictedPayload = abi.encode(DEPOSIT_SIG, address(rootToken), sender, recipient, depositAmt);
        vm.expectCall(
            address(mockAdaptor),
            gasAmt,
            abi.encodeWithSelector(mockAdaptor.sendMessage.selector, predictedPayload, sender)
        );
        vm.expectEmit(address(bridge));
        emit ChildChainERC20Deposit(
            address(rootToken), bridge.rootTokenToChildToken(address(rootToken)), sender, recipient, depositAmt
        );
        bridge.depositTo{value: gasAmt}(IERC20Metadata(address(rootToken)), recipient, depositAmt);

        // After deposit
        assertEq(rootToken.balanceOf(sender), balance - depositAmt, "Sender should have balance - depositAmt of ERC20");
        assertEq(rootToken.balanceOf(address(bridge)), depositAmt, "Bridge should have depositAmt of ERC20");

        vm.stopPrank();
    }

    function testFuzz_WithdrawERC20(address sender, address recipient, uint256 withdrawAmt) public {
        vm.assume(sender != address(0) && recipient != address(0) && withdrawAmt > 0);

        // Map token
        ChildERC20 rootToken = new ChildERC20();
        rootToken.initialize(address(123), "Test token", "TEST", 18);
        rootToken.mint(address(bridge), withdrawAmt);
        vm.deal(sender, 100);
        vm.startPrank(sender);
        bridge.mapToken{value: 100}(IERC20Metadata(address(rootToken)));

        address childTokenAddr = bridge.rootTokenToChildToken(address(rootToken));

        assertEq(rootToken.balanceOf(recipient), 0, "Recipient should have 0 balance of ERC20");
        assertEq(rootToken.balanceOf(address(bridge)), withdrawAmt, "Bridge should have withdrawAmt of ERC20");

        bytes memory data = abi.encode(WITHDRAW_SIG, address(rootToken), sender, recipient, withdrawAmt);

        vm.expectEmit(address(bridge));
        emit RootChainERC20Withdraw(address(rootToken), childTokenAddr, sender, recipient, withdrawAmt);

        vm.startPrank(address(mockAdaptor));

        bridge.onMessageReceive(data);

        assertEq(rootToken.balanceOf(recipient), withdrawAmt, "Recipient should have withdrawAmt of ERC20");
        assertEq(rootToken.balanceOf(address(bridge)), 0, "Bridge should have 0 of ERC20");

        vm.stopPrank();
    }
}
