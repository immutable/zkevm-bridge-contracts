// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../src/child/ChildERC20.sol";
import {WIMX} from "../../src/child/WIMX.sol";
import {WETH} from "../../src/lib/WETH.sol";
import {IChildERC20Bridge, ChildERC20Bridge} from "../../src/child/ChildERC20Bridge.sol";
import {IRootERC20Bridge, IERC20Metadata} from "../../src/root/RootERC20Bridge.sol";
import {RootERC20BridgeFlowRate} from "../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {MockAdaptor} from "./MockAdaptor.sol";
import {ChildHelper} from "./child/ChildHelper.sol";
import {RootHelper} from "./root/RootHelper.sol";
import {IChainManager} from "./IChainManager.sol";
import {ChildERC20BridgeHandler} from "./child/ChildERC20BridgeHandler.sol";
import {RootERC20BridgeFlowRateHandler} from "./root/RootERC20BridgeFlowRateHandler.sol";
import "forge-std/console.sol";

contract InvariantBridge is Test, IChainManager {
    string public constant CHAIN_URL = "http://127.0.0.1:8500";
    uint256 public constant IMX_DEPOSIT_LIMIT = 10000 ether;
    uint256 public constant MAX_AMOUNT = 10000;
    address public constant ADMIN = address(0x111);
    address public constant RESERVER = address(0x222);
    uint256 public constant NO_OF_USERS = 20;
    uint256 public constant NO_OF_TOKENS = 10;

    address[] users;
    address[] rootTokens;

    uint256 childId;
    uint256 rootId;
    uint256 resetId;
    ChildERC20Bridge childBridge;
    RootERC20BridgeFlowRate rootBridge;
    MockAdaptor childAdaptor;
    MockAdaptor rootAdaptor;
    ChildHelper childHelper;
    RootHelper rootHelper;
    ChildERC20BridgeHandler childBridgeHandler;
    RootERC20BridgeFlowRateHandler rootBridgeHandler;

    uint256 mappingGas;

    function switchToChain(uint256 chainId) external {
        vm.selectFork(chainId);
    }

    function setUp() public {
        childId = vm.createFork(CHAIN_URL);
        rootId = vm.createFork(CHAIN_URL);
        // Forge has an issue that fails to reset state at the end of each run.
        // For example, we found out that if the context stays at child chain at the end of setUp(),
        // the state on child chain will not be reset or if the context stays at root chain, the state
        // on the root chain will not be reset, which causes subsequent runs to fail.
        // We introduced a third chain called reset chain and we make the context to stay on the reset chain
        // in order to reset state on both child chain and root chain.
        resetId = vm.createFork(CHAIN_URL);

        // Deploy contracts on child chain.
        vm.selectFork(childId);
        vm.startPrank(ADMIN);
        ChildERC20 childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);
        childAdaptor = new MockAdaptor();
        vm.stopPrank();

        childBridge = new ChildERC20Bridge(address(this));
        WIMX wIMX = new WIMX();

        // Deploy contracts on root chain.
        vm.selectFork(rootId);
        vm.startPrank(ADMIN);
        ChildERC20 rootTokenTemplate = new ChildERC20();
        rootTokenTemplate.initialize(address(123), "Test", "TST", 18);
        rootAdaptor = new MockAdaptor();
        vm.stopPrank();

        rootBridge = new RootERC20BridgeFlowRate(address(this));
        ChildERC20 rootIMXToken = new ChildERC20();
        rootIMXToken.initialize(address(123), "Immutable X", "IMX", 18);
        WETH wETH = new WETH();

        // Configure contracts on child chain.
        vm.selectFork(childId);
        childAdaptor.initialize(rootId, address(childBridge), address(this));
        IChildERC20Bridge.InitializationRoles memory childRoles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this),
            initialDepositor: address(this),
            treasuryManager: address(this)
        });
        childBridge.initialize(
            childRoles, address(childAdaptor), address(childTokenTemplate), address(rootIMXToken), address(wIMX)
        );
        vm.deal(address(childBridge), IMX_DEPOSIT_LIMIT);

        // Configure contracts on root chain.
        vm.selectFork(rootId);
        rootAdaptor.initialize(childId, address(rootBridge), address(this));
        IRootERC20Bridge.InitializationRoles memory rootRoles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        rootBridge.initialize(
            rootRoles,
            address(rootAdaptor),
            address(childBridge),
            address(rootTokenTemplate),
            address(rootIMXToken),
            address(wETH),
            IMX_DEPOSIT_LIMIT,
            ADMIN
        );

        // Create users.
        vm.selectFork(rootId);
        for (uint256 i = 0; i < NO_OF_USERS; i++) {
            address user = vm.addr(0x10000 + i);
            // Mint ETH token
            vm.deal(user, MAX_AMOUNT);
            // Mint IMX token
            rootIMXToken.mint(user, MAX_AMOUNT);
            users.push(user);
        }
        // Create tokens.
        for (uint256 i = 0; i < NO_OF_TOKENS; i++) {
            vm.startPrank(address(0x234));
            ChildERC20 rootToken = new ChildERC20();
            rootToken.initialize(address(123), "Test", "TST", 18);
            // Mint token to user
            for (uint256 j = 0; j < NO_OF_USERS; j++) {
                rootToken.mint(users[j], MAX_AMOUNT);
            }
            vm.stopPrank();
            // Configure rate for half tokens
            if (i % 2 == 0) {
                vm.prank(ADMIN);
                rootBridge.setRateControlThreshold(address(rootToken), MAX_AMOUNT, MAX_AMOUNT / 3600, MAX_AMOUNT / 2);
            }
            rootTokens.push(address(rootToken));
        }

        // Deploy helpers and handlers on all chains.
        vm.selectFork(childId);
        vm.startPrank(ADMIN);
        childHelper = new ChildHelper(payable(childBridge));
        address temp = address(new RootHelper(ADMIN, payable(rootBridge)));
        vm.stopPrank();
        vm.startPrank(RESERVER);
        childBridgeHandler = new ChildERC20BridgeHandler(childId, rootId, users, rootTokens, address(childHelper), temp);
        new RootERC20BridgeFlowRateHandler(childId, rootId, users, rootTokens, address(childHelper), temp);
        vm.stopPrank();

        vm.selectFork(rootId);
        vm.startPrank(ADMIN);
        new ChildHelper(payable(childBridge));
        rootHelper = new RootHelper(ADMIN, payable(rootBridge));
        vm.stopPrank();
        vm.startPrank(RESERVER);
        new ChildERC20BridgeHandler(childId, rootId, users, rootTokens, address(childHelper), address(rootHelper));
        rootBridgeHandler = new RootERC20BridgeFlowRateHandler(
            childId, rootId, users, rootTokens, address(childHelper), address(rootHelper)
        );
        vm.stopPrank();
        
        vm.selectFork(resetId);
        vm.startPrank(RESERVER);
        new ChildERC20BridgeHandler(childId, rootId, users, rootTokens, address(0), address(0));
        new RootERC20BridgeFlowRateHandler(childId, rootId, users, rootTokens, address(0), address(0));
        vm.stopPrank();

        // Map tokens
        vm.selectFork(rootId);
        for (uint256 i = 0; i < NO_OF_TOKENS; i++) {
            address rootToken = rootTokens[i];
            rootBridge.mapToken{value: 1}(IERC20Metadata(rootToken));
            mappingGas += 1;
            // Verify
            address childTokenL1 = rootBridge.rootTokenToChildToken(address(rootToken));

            vm.selectFork(childId);
            address childTokenL2 = childBridge.rootTokenToChildToken(address(rootToken));
            vm.selectFork(rootId);

            assertEq(childTokenL1, childTokenL2, "Child token address mismatch between L1 and L2");
        }

        vm.selectFork(childId);
        for (uint256 j = 0; j < NO_OF_USERS; j++) {
            address user = users[j];
            // Note: Foundry has issue resetting user balance without the next line.
            assertEq(user.balance, 0);
        }

        // Target contracts
        bytes4[] memory childSelectors = new bytes4[](8);
        childSelectors[0] = childBridgeHandler.withdraw.selector;
        childSelectors[1] = childBridgeHandler.withdrawTo.selector;
        childSelectors[2] = childBridgeHandler.withdrawIMX.selector;
        childSelectors[3] = childBridgeHandler.withdrawIMXTo.selector;
        childSelectors[4] = childBridgeHandler.withdrawWIMX.selector;
        childSelectors[5] = childBridgeHandler.withdrawWIMXTo.selector;
        childSelectors[6] = childBridgeHandler.withdrawETH.selector;
        childSelectors[7] = childBridgeHandler.withdrawETHTo.selector;
        targetSelector(FuzzSelector({addr: address(childBridgeHandler), selectors: childSelectors}));

        bytes4[] memory rootSelectors = new bytes4[](8);
        rootSelectors[0] = rootBridgeHandler.deposit.selector;
        rootSelectors[1] = rootBridgeHandler.depositTo.selector;
        rootSelectors[2] = rootBridgeHandler.depositIMX.selector;
        rootSelectors[3] = rootBridgeHandler.depositIMXTo.selector;
        rootSelectors[4] = rootBridgeHandler.depositETH.selector;
        rootSelectors[5] = rootBridgeHandler.depositETHTo.selector;
        rootSelectors[6] = rootBridgeHandler.depositWETH.selector;
        rootSelectors[7] = rootBridgeHandler.depositWETHTo.selector;
        targetSelector(FuzzSelector({addr: address(rootBridgeHandler), selectors: rootSelectors}));

        targetContract(address(childBridgeHandler));
        targetContract(address(rootBridgeHandler));

        vm.selectFork(resetId);
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_ERC20TokenBalanced() external {
        for (uint256 i = 0; i < NO_OF_TOKENS; i++) {
            address rootToken = rootTokens[i];

            vm.selectFork(rootId);
            uint256 bridgeBalance = ChildERC20(rootToken).balanceOf(address(rootBridge));
            address childToken = rootBridge.rootTokenToChildToken(rootToken);

            vm.selectFork(childId);
            uint256 totalSupply = ChildERC20(childToken).totalSupply();

            uint256 userBalanceSum = 0;
            for (uint256 j = 0; j < NO_OF_USERS; j++) {
                address user = users[j];
                userBalanceSum += ChildERC20(childToken).balanceOf(user);
            }

            assertEq(bridgeBalance, totalSupply);
            assertEq(bridgeBalance, userBalanceSum);
        }
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_IndividualERC20TokenBalanced() external {
        for (uint256 i = 0; i < NO_OF_TOKENS; i++) {
            address rootToken = rootTokens[i];
            vm.selectFork(rootId);
            address childToken = rootBridge.rootTokenToChildToken(rootToken);
            for (uint256 j = 0; j < NO_OF_USERS; j++) {
                address user = users[j];

                vm.selectFork(rootId);
                uint256 balanceL1 = ChildERC20(rootToken).balanceOf(user);

                vm.selectFork(childId);
                uint256 balanceL2 = ChildERC20(childToken).balanceOf(user);

                assertEq(balanceL1 + balanceL2, MAX_AMOUNT);
            }
        }
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_IMXBalanced() external {
        vm.selectFork(rootId);
        uint256 bridgeBalance = ChildERC20(rootBridge.rootIMXToken()).balanceOf(address(rootBridge));

        vm.selectFork(childId);
        uint256 totalSupply = IMX_DEPOSIT_LIMIT - address(childBridge).balance;

        uint256 userBalanceSum = 0;
        for (uint256 j = 0; j < NO_OF_USERS; j++) {
            address user = users[j];
            userBalanceSum += user.balance;
        }

        assertEq(bridgeBalance, totalSupply);
        assertEq(bridgeBalance, userBalanceSum);
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_IndividualIMXBalanced() external {
        for (uint256 j = 0; j < NO_OF_USERS; j++) {
            address user = users[j];

            vm.selectFork(rootId);
            uint256 balanceL1 = ChildERC20(rootBridge.rootIMXToken()).balanceOf(user);

            vm.selectFork(childId);
            uint256 balanceL2 = user.balance;

            assertEq(balanceL1 + balanceL2, MAX_AMOUNT);
        }
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_ETHBalanced() external {
        vm.selectFork(rootId);
        uint256 bridgeBalance = address(rootBridge).balance;

        vm.selectFork(childId);
        uint256 totalSupply = ChildERC20(childBridge.childETHToken()).totalSupply();

        uint256 userBalanceSum = 0;
        for (uint256 j = 0; j < NO_OF_USERS; j++) {
            address user = users[j];
            userBalanceSum += ChildERC20(childBridge.childETHToken()).balanceOf(user);
        }

        assertEq(bridgeBalance, totalSupply);
        assertEq(bridgeBalance, userBalanceSum);
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_IndividualETHBalanced() external {
        for (uint256 j = 0; j < NO_OF_USERS; j++) {
            address user = users[j];

            vm.selectFork(rootId);
            uint256 balanceL1 = user.balance;

            vm.selectFork(childId);
            uint256 balanceL2 = ChildERC20(childBridge.childETHToken()).balanceOf(user);

            assertEq(balanceL1 + balanceL2, MAX_AMOUNT);
        }
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_NoRemainingWETH() external {
        vm.selectFork(rootId);
        assertEq(rootBridge.rootWETHToken().balance, 0);
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_NoRemainingWIMX() external {
        vm.selectFork(childId);
        assertEq(childBridge.wIMXToken().balance, 0);
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 15
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_GasBalanced() external {
        vm.selectFork(rootId);
        assertEq(address(rootAdaptor).balance - mappingGas, rootHelper.totalGas());
        vm.selectFork(childId);
        assertEq(address(childAdaptor).balance, childHelper.totalGas());
    }
}
