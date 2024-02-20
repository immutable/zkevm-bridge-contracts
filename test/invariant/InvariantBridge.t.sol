// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../src/child/ChildERC20.sol";
import {WIMX} from "../../src/child/WIMX.sol";
import {IChildERC20Bridge, ChildERC20Bridge} from "../../src/child/ChildERC20Bridge.sol";
import {IRootERC20Bridge, IERC20Metadata} from "../../src/root/RootERC20Bridge.sol";
import {RootERC20BridgeFlowRate} from "../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {MockAdaptor} from "./MockAdaptor.sol";
import {ChildHelper} from "./child/ChildHelper.sol";
import {RootHelper} from "./root/RootHelper.sol";
import {ChildERC20BridgeHandler} from "./child/ChildERC20BridgeHandler.sol";
import {RootERC20BridgeFlowRateHandler} from "./root/RootERC20BridgeFlowRateHandler.sol";
import "forge-std/console.sol";

contract InvariantBridge is Test {
    string public constant CHILD_CHAIN_URL = "http://127.0.0.1:8500";
    string public constant ROOT_CHAIN_URL = "http://127.0.0.1:8501";
    uint256 public constant IMX_DEPOSIT_LIMIT = 10000 ether;
    uint256 public constant MAX_AMOUNT = 10000;
    address public constant ADMIN = address(0x111);
    uint256 public constant NO_OF_USERS = 5;
    uint256 public constant NO_OF_TOKENS = 4;

    address[] users;
    address[] rootTokens;

    uint256 childId;
    uint256 rootId;
    ChildERC20Bridge childBridge;
    RootERC20BridgeFlowRate rootBridge;
    MockAdaptor childAdaptor;
    MockAdaptor rootAdaptor;
    ChildHelper childHelper;
    RootHelper rootHelper;
    ChildERC20BridgeHandler childBridgeHandler;
    RootERC20BridgeFlowRateHandler rootBridgeHandler;

    function setUp() public {
        childId = vm.createFork(CHILD_CHAIN_URL);
        rootId = vm.createFork(ROOT_CHAIN_URL);

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
        WIMX wETH = new WIMX();

        // Configure contracts on child chain.
        vm.selectFork(childId);
        childAdaptor.initialize(rootId, address(childBridge));
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
        rootAdaptor.initialize(childId, address(rootBridge));
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
            vm.prank(address(0x234));
            ChildERC20 rootToken = new ChildERC20();
            vm.prank(address(0x234));
            rootToken.initialize(address(123), "Test", "TST", 18);
            // Mint token to user
            for (uint256 j = 0; j < NO_OF_USERS; j++) {
                vm.prank(address(0x234));
                rootToken.mint(users[j], MAX_AMOUNT);
            }
            // Configure rate for half tokens
            if (i % 2 == 0) {
                vm.prank(ADMIN);
                rootBridge.setRateControlThreshold(address(rootToken), MAX_AMOUNT, MAX_AMOUNT / 3600, MAX_AMOUNT / 2);
            }
            rootTokens.push(address(rootToken));
        }

        // Deploy helpers and handlers on both chains.
        vm.selectFork(childId);
        vm.startPrank(ADMIN);
        childHelper = new ChildHelper(payable(childBridge));
        address temp = address(new RootHelper(ADMIN, payable(rootBridge)));
        childBridgeHandler =
            new ChildERC20BridgeHandler(childId, rootId, users, rootTokens, address(childHelper), temp);
        new RootERC20BridgeFlowRateHandler(childId, rootId, users, rootTokens, address(childHelper), temp);
        vm.stopPrank();

        vm.selectFork(rootId);
        vm.startPrank(ADMIN);
        new ChildHelper(payable(childBridge));
        rootHelper = new RootHelper(ADMIN, payable(rootBridge));
        new ChildERC20BridgeHandler(childId, rootId, users, rootTokens, address(childHelper), address(rootHelper));
        rootBridgeHandler =
            new RootERC20BridgeFlowRateHandler(childId, rootId, users, rootTokens, address(childHelper), address(rootHelper));
        vm.stopPrank();

        // Map tokens
        vm.selectFork(rootId);
        for (uint256 i = 0; i < NO_OF_TOKENS; i++) {
            address rootToken = rootTokens[i];
            rootBridge.mapToken{value: 1}(IERC20Metadata(rootToken));
            // Verify
            address childTokenL1 = rootBridge.rootTokenToChildToken(address(rootToken));

            vm.selectFork(childId);
            address childTokenL2 = childBridge.rootTokenToChildToken(address(rootToken));
            vm.selectFork(rootId);

            assertEq(childTokenL1, childTokenL2, "Child token address mismatch between L1 and L2");
        }

        // Target contracts
        bytes4[] memory childSelectors = new bytes4[](1);
        childSelectors[0] = childBridgeHandler.withdraw.selector;
        targetSelector(FuzzSelector({addr: address(childBridgeHandler), selectors: childSelectors}));

        bytes4[] memory rootSelectors = new bytes4[](1);
        rootSelectors[0] = rootBridgeHandler.deposit.selector;
        targetSelector(FuzzSelector({addr: address(rootBridgeHandler), selectors: rootSelectors}));

        targetContract(address(childBridgeHandler));
        targetContract(address(rootBridgeHandler));
    }

    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_A() external {
    }
}