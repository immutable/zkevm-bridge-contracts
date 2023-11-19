// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    RootERC20BridgeFlowRate,
    IRootERC20BridgeFlowRateEvents,
    IRootERC20BridgeFlowRateErrors,
    IRootERC20Bridge
} from "../../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {
    IFlowRateWithdrawalQueueEvents,
    IFlowRateWithdrawalQueueErrors
} from "../../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";
import {IRootERC20BridgeEvents, IRootERC20BridgeErrors} from "../../../../src/root/RootERC20Bridge.sol";
import {FlowRateWithdrawalQueue} from "../../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";
import {MockAxelarGateway} from "../../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../../src/test/root/MockAxelarGasService.sol";
import {MockAdaptor} from "../../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WETH} from "../../../../src/test/root/WETH.sol";
import {MockERC20} from "../../../../src/test/root/MockERC20.sol";

contract ReentrancyAttackERC20 is MockERC20 {
    RootERC20BridgeFlowRate bridge;
    uint256 rerun = 0;
    uint256 idx;
    uint256[] idxs;
    bool attackWithdrawal;

    constructor(address payable _bridge) {
        bridge = RootERC20BridgeFlowRate(_bridge);
    }

    function prepareAttackWithdrawal(uint256 index) external {
        idx = index;
        attackWithdrawal = true;
    }

    function prepareAttackWithdrawalAggregated(uint256[] calldata indices) external {
        idxs = indices;
        attackWithdrawal = false;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (msg.sender == address(bridge)) {
            if (rerun++ < 3) {
                if (attackWithdrawal) {
                    bridge.finaliseQueuedWithdrawal(to, idx);
                } else {
                    bridge.finaliseQueuedWithdrawalsAggregated(to, address(this), idxs);
                }
            } else {
                rerun = 0;
            }
        }

        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
}

contract RootERC20BridgeFlowRateUnitTest is
    Test,
    IRootERC20BridgeFlowRateEvents,
    IRootERC20BridgeFlowRateErrors,
    IRootERC20BridgeEvents,
    IRootERC20BridgeErrors,
    IFlowRateWithdrawalQueueEvents,
    IFlowRateWithdrawalQueueErrors,
    Utils
{
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string CHILD_BRIDGE_ADAPTOR_STRING = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    string constant CHILD_CHAIN_NAME = "test";
    address constant IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);
    uint256 constant mapTokenFee = 300;
    uint256 constant depositFee = 200;
    uint256 constant UNLIMITED_IMX_DEPOSITS = 0;

    uint256 constant CAPACITY = 1000000;
    uint256 constant REFILL_RATE = 277; // Refill each hour.
    uint256 constant LARGE = 100000;

    uint256 constant CAPACITY_ETH = 1000000 ether;
    uint256 constant REFILL_RATE_ETH = 277 ether; // Refill each hour.
    uint256 constant LARGE_ETH = 100000 ether;

    uint256 constant CHARLIE_REMAINDER = 17;
    uint256 constant BANK_OF_CHARLIE_TREASURY = BRIDGED_VALUE + CHARLIE_REMAINDER;

    uint256 constant BRIDGED_VALUE = CAPACITY * 100;
    uint256 constant BRIDGED_VALUE_ETH = CAPACITY_ETH * 100;

    bytes32 internal constant RATE_CONTROL_ROLE = keccak256("RATE");
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER");
    bytes32 internal constant UNPAUSER_ROLE = keccak256("UNPAUSER");

    address alice;
    address bob;
    address charlie;

    address rateAdmin;
    address pauseAdmin;
    address unpauseAdmin;
    address nonAdmin;
    address superAdmin;

    uint256 withdrawalDelay;

    ERC20PresetMinterPauser public token;
    ERC20PresetMinterPauser public imxToken;
    RootERC20BridgeFlowRate public rootBridgeFlowRate;
    MockAdaptor public mockAxelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(this), 100 ether);
        deployCodeTo("ERC20PresetMinterPauser.sol", abi.encode("ImmutableX", "IMX"), IMX_TOKEN);
        imxToken = ERC20PresetMinterPauser(IMX_TOKEN);
        imxToken.mint(address(this), 100 ether);

        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        rateAdmin = makeAddr("rateadmin");
        pauseAdmin = makeAddr("pauseadmin");
        unpauseAdmin = makeAddr("unpauseadmin");
        nonAdmin = makeAddr("nonadmin");
        superAdmin = makeAddr("superadmin");

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        rootBridgeFlowRate = new RootERC20BridgeFlowRate();
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();

        mockAxelarAdaptor = new MockAdaptor();

        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: superAdmin,
            pauser: pauseAdmin,
            unpauser: unpauseAdmin,
            variableManager: address(this),
            adaptorManager: address(this)
        });

        // The specific ERC20 token template does not matter for these unit tests
        rootBridgeFlowRate.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR_STRING,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            CHILD_CHAIN_NAME,
            UNLIMITED_IMX_DEPOSITS,
            rateAdmin
        );

        withdrawalDelay = rootBridgeFlowRate.withdrawalDelay();
    }

    function activateWithdrawalQueue() internal {
        vm.startPrank(rateAdmin);
        rootBridgeFlowRate.activateWithdrawalQueue();
        vm.stopPrank();
    }

    function configureFlowRate() internal {
        vm.startPrank(rateAdmin);
        rootBridgeFlowRate.setRateControlThreshold(address(token), CAPACITY, REFILL_RATE, LARGE);
        rootBridgeFlowRate.setRateControlThreshold(NATIVE_ETH, CAPACITY_ETH, REFILL_RATE_ETH, LARGE_ETH);
        vm.stopPrank();
    }

    function transferTokensToChild() internal {
        vm.deal(address(this), 1 ether);
        // Need to first map the token.
        rootBridgeFlowRate.mapToken{value: 100}(token);
        // And give the bridge some tokens
        token.transfer(address(rootBridgeFlowRate), BRIDGED_VALUE);
    }

    function transferEtherToChild() internal {
        vm.deal(address(rootBridgeFlowRate), BRIDGED_VALUE_ETH);
    }

    function pause() internal {
        vm.prank(pauseAdmin);
        rootBridgeFlowRate.pause();
    }

    function enableQueue() internal {
        vm.prank(rateAdmin);
        rootBridgeFlowRate.activateWithdrawalQueue();
    }

    /**
     * INITIALIZE
     */

    function test_InitializeBridgeFlowRate() public {
        assertEq(address(rootBridgeFlowRate.rootBridgeAdaptor()), address(mockAxelarAdaptor), "bridgeAdaptor not set");
        assertEq(rootBridgeFlowRate.childERC20Bridge(), CHILD_BRIDGE, "childERC20Bridge not set");
        assertEq(rootBridgeFlowRate.childTokenTemplate(), address(token), "childTokenTemplate not set");
        assert(Strings.equal(rootBridgeFlowRate.childChain(), CHILD_CHAIN_NAME));
        assert(Strings.equal(CHILD_BRIDGE_ADAPTOR_STRING, rootBridgeFlowRate.childBridgeAdaptor()));
        assertEq(address(token), rootBridgeFlowRate.childTokenTemplate(), "childTokenTemplate not set");
        assertEq(rootBridgeFlowRate.rootIMXToken(), IMX_TOKEN, "rootIMXToken not set");
        assertEq(rootBridgeFlowRate.rootWETHToken(), WRAPPED_ETH, "rootWETHToken not set");
    }

    function test_RevertIfInitializedTwice() public {
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: pauseAdmin,
            unpauser: unpauseAdmin,
            variableManager: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert("Initializable: contract is already initialized");
        rootBridgeFlowRate.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR_STRING,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            CHILD_CHAIN_NAME,
            UNLIMITED_IMX_DEPOSITS,
            address(this)
        );
    }

    function test_RevertIfRootBridgeInitializedDirectly() public {
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert(WrongInitializer.selector);
        rootBridgeFlowRate.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR_STRING,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            CHILD_CHAIN_NAME,
            UNLIMITED_IMX_DEPOSITS
        );
    }

    function test_RevertIf_InitializeWithAZeroAddressRateAdmin() public {
        RootERC20BridgeFlowRate newRootBridgeFlowRate = new RootERC20BridgeFlowRate();
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(0),
            adaptorManager: address(this)
        });
        vm.expectRevert(ZeroAddress.selector);
        newRootBridgeFlowRate.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR_STRING,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            CHILD_CHAIN_NAME,
            UNLIMITED_IMX_DEPOSITS,
            address(0)
        );
    }

    /**
     * RATE ROLE ACTIONS
     */

    function testActivateWithdrawalQueue() public {
        vm.prank(rateAdmin);
        rootBridgeFlowRate.activateWithdrawalQueue();
        assertTrue(rootBridgeFlowRate.withdrawalQueueActivated());
    }

    function testActivateWithdrawalQueueBadAuth() public {
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(nonAdmin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(RATE_CONTROL_ROLE), 32)
            )
        );
        rootBridgeFlowRate.activateWithdrawalQueue();
    }

    function testDeactivateWithdrawalQueue() public {
        activateWithdrawalQueue();
        vm.prank(rateAdmin);
        rootBridgeFlowRate.deactivateWithdrawalQueue();
        assertFalse(rootBridgeFlowRate.withdrawalQueueActivated());
    }

    function testDeactivateWithdrawalQueueBadAuth() public {
        activateWithdrawalQueue();
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(nonAdmin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(RATE_CONTROL_ROLE), 32)
            )
        );
        rootBridgeFlowRate.deactivateWithdrawalQueue();
    }

    function testSetWithdrawalDelay() public {
        uint256 delay = 1000;
        vm.prank(rateAdmin);
        rootBridgeFlowRate.setWithdrawalDelay(delay);
        assertEq(rootBridgeFlowRate.withdrawalDelay(), delay);
    }

    function testSetWithdrawalDelayBadAuth() public {
        uint256 delay = 1000;
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(nonAdmin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(RATE_CONTROL_ROLE), 32)
            )
        );
        rootBridgeFlowRate.setWithdrawalDelay(delay);
    }

    function testSetRateControlThreshold() public {
        vm.prank(rateAdmin);
        vm.expectEmit(true, true, false, true);
        emit RateControlThresholdSet(address(token), CAPACITY, REFILL_RATE, LARGE, 0, 0, 0);
        rootBridgeFlowRate.setRateControlThreshold(address(token), CAPACITY, REFILL_RATE, LARGE);
        assertEq(rootBridgeFlowRate.largeTransferThresholds(address(token)), LARGE);
        uint256 capacity;
        uint256 refillRate;
        (capacity,,, refillRate) = rootBridgeFlowRate.flowRateBuckets(address(token));
        assertEq(capacity, CAPACITY, "Capacity");
        assertEq(refillRate, REFILL_RATE, "Refill rate");
    }

    function testSetRateControlThresholdBadAuth() public {
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(nonAdmin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(RATE_CONTROL_ROLE), 32)
            )
        );
        rootBridgeFlowRate.setRateControlThreshold(address(token), CAPACITY, REFILL_RATE, LARGE);
    }

    function testGrantRole() public {
        bytes32 role = RATE_CONTROL_ROLE;
        vm.prank(superAdmin);
        rootBridgeFlowRate.grantRole(role, pauseAdmin);
        assertTrue(rootBridgeFlowRate.hasRole(role, pauseAdmin));
    }

    function testGrantRoleBadAuth() public {
        bytes32 role = RATE_CONTROL_ROLE;
        vm.prank(pauseAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(pauseAdmin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(0x00), 32)
            )
        );
        rootBridgeFlowRate.grantRole(role, pauseAdmin);
    }

    function testPause() public {
        vm.prank(pauseAdmin);
        rootBridgeFlowRate.pause();
        assertTrue(rootBridgeFlowRate.paused());
    }

    function testPauseBadAuth() public {
        vm.prank(unpauseAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(unpauseAdmin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(PAUSER_ROLE), 32)
            )
        );
        rootBridgeFlowRate.pause();
    }

    function testUnpause() public {
        vm.prank(pauseAdmin);
        rootBridgeFlowRate.pause();
        vm.prank(unpauseAdmin);
        rootBridgeFlowRate.unpause();
        assertFalse(rootBridgeFlowRate.paused());
    }

    function testUnpauseBadAuth() public {
        vm.startPrank(pauseAdmin);
        rootBridgeFlowRate.pause();
        vm.startPrank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(nonAdmin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(UNPAUSER_ROLE), 32)
            )
        );
        rootBridgeFlowRate.unpause();
    }

    function testWithdrawalWhenPaused() public {
        configureFlowRate();
        transferTokensToChild();

        pause();

        uint256 amount = 5;

        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectRevert("Pausable: paused");
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
    }

    function testFinaliseQueuedWithdrawalWhenPaused() public {
        configureFlowRate();
        enableQueue();
        transferTokensToChild();

        uint256 now1 = 100;
        vm.warp(now1);

        uint256 amount = 5;
        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true);
        emit EnQueuedWithdrawal(address(token), alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        pause();

        vm.warp(now1 + withdrawalDelay);

        vm.expectRevert("Pausable: paused");
        rootBridgeFlowRate.finaliseQueuedWithdrawal(bob, 0);
    }

    function testFinaliseQueuedWithdrawalAggregatedWhenPaused() public {
        configureFlowRate();
        enableQueue();
        transferTokensToChild();

        uint256 now1 = 100;
        vm.warp(now1);

        uint256 amount = 5;
        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true);
        emit EnQueuedWithdrawal(address(token), alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        pause();

        vm.warp(now1 + withdrawalDelay);

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        vm.expectRevert("Pausable: paused");
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(token), indices);
    }

    /**
     * FLOW RATE WITHDRAW
     */

    function testWithdrawalUnconfiguredToken() public {
        transferTokensToChild();

        uint256 amount = 5;

        uint256 now1 = 100;
        vm.warp(now1);

        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));

        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit QueuedWithdrawal(address(token), alice, bob, amount, false, true, false);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        //assertEq(token.balanceOf(address(charlie)), CHARLIE_REMAINDER, "charlie");
        assertEq(token.balanceOf(address(alice)), 0, "alice");
        assertEq(token.balanceOf(address(bob)), 0, "bob");
        assertEq(token.balanceOf(address(rootBridgeFlowRate)), BRIDGED_VALUE, "rootBridgeFlowRate");

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        FlowRateWithdrawalQueue.PendingWithdrawal[] memory pending =
            rootBridgeFlowRate.getPendingWithdrawals(bob, indices);
        assertEq(pending.length, 1, "Pending withdrawal length");
        assertEq(pending[0].withdrawer, address(alice), "Withdrawer");
        assertEq(pending[0].token, address(token), "Token");
        assertEq(pending[0].amount, amount, "Amount");
        assertEq(pending[0].timestamp, now1, "Timestamp");
    }

    function testWithdrawalLargeWithdrawal() public {
        configureFlowRate();
        transferTokensToChild();

        uint256 amount = LARGE;

        uint256 now1 = 100;
        vm.warp(now1);

        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));

        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit QueuedWithdrawal(address(token), alice, bob, amount, true, false, false);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        assertEq(token.balanceOf(address(alice)), 0, "alice");
        assertEq(token.balanceOf(address(bob)), 0, "bob");
        assertEq(token.balanceOf(address(rootBridgeFlowRate)), BRIDGED_VALUE, "rootBridgeFlowRate");

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        FlowRateWithdrawalQueue.PendingWithdrawal[] memory pending =
            rootBridgeFlowRate.getPendingWithdrawals(bob, indices);
        assertEq(pending.length, 1, "Pending withdrawal length");
        assertEq(pending[0].withdrawer, address(alice), "Withdrawer");
        assertEq(pending[0].token, address(token), "Token");
        assertEq(pending[0].amount, amount, "Amount");
        assertEq(pending[0].timestamp, now1, "Timestamp");
    }

    function testHighFlowRate() public {
        vm.warp(100);
        configureFlowRate();
        transferTokensToChild();

        uint256 amount = LARGE - 1;
        uint256 timesBeforeHighFlowRate = CAPACITY / amount;

        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        address childERC20Token = rootBridgeFlowRate.rootTokenToChildToken(address(token));
        uint256 total;
        for (uint256 i = 0; i < timesBeforeHighFlowRate; i++) {
            vm.prank(address(mockAxelarAdaptor));
            vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
            emit RootChainERC20Withdraw(address(token), childERC20Token, alice, bob, amount);
            rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
            assertFalse(rootBridgeFlowRate.withdrawalQueueActivated(), "queue activated!");
            total += amount;
            assertEq(token.balanceOf(address(bob)), total, "bob");
        }
        assertFalse(rootBridgeFlowRate.withdrawalQueueActivated(), "queue activated!");

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit QueuedWithdrawal(address(token), alice, bob, amount, false, false, true);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
        assertTrue(rootBridgeFlowRate.withdrawalQueueActivated(), "queue not activated!");
        assertEq(token.balanceOf(address(bob)), total, "bob");
    }

    function testFinaliseQueuedWithdrawalERC20() public {
        configureFlowRate();
        transferTokensToChild();
        activateWithdrawalQueue();

        uint256 amount = 5;

        uint256 now1 = 100;
        vm.warp(now1);

        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        address childERC20Token = rootBridgeFlowRate.rootTokenToChildToken(address(token));
        //emit log_named_address("Child ERC 20 token", childERC20Token);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit EnQueuedWithdrawal(address(token), alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        uint256 now2 = now1 + withdrawalDelay;
        vm.warp(now2);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, amount, 0);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit RootChainERC20Withdraw(address(token), childERC20Token, alice, bob, amount);
        rootBridgeFlowRate.finaliseQueuedWithdrawal(bob, 0);

        queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        assertEq(token.balanceOf(address(alice)), 0, "alice");
        assertEq(token.balanceOf(address(bob)), amount, "bob");
        assertEq(token.balanceOf(address(rootBridgeFlowRate)), BRIDGED_VALUE - amount, "rootBridgeFlowRate");
    }

    function testFinaliseQueuedWithdrawalEther() public {
        configureFlowRate();
        transferEtherToChild();
        activateWithdrawalQueue();

        uint256 amount = 5 ether;

        uint256 now1 = 100;
        vm.warp(now1);

        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, NATIVE_ETH, alice, bob, amount);

        address childERC20Token = rootBridgeFlowRate.rootTokenToChildToken(NATIVE_ETH);
        //emit log_named_address("Child ERC 20 token", childERC20Token);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit EnQueuedWithdrawal(NATIVE_ETH, alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        uint256 now2 = now1 + withdrawalDelay;
        vm.warp(now2);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, amount, 0);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit RootChainETHWithdraw(NATIVE_ETH, childERC20Token, alice, bob, amount);
        rootBridgeFlowRate.finaliseQueuedWithdrawal(bob, 0);

        queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        assertEq(address(rootBridgeFlowRate).balance, BRIDGED_VALUE_ETH - amount, "after Root ERC20 Predicate");
        assertEq(bob.balance, amount, "after bob");
    }

    function testFinaliseQueuedWithdrawalOutOfBounds() public {
        configureFlowRate();
        transferTokensToChild();
        activateWithdrawalQueue();

        uint256 amount = 5;

        uint256 now1 = 100;
        vm.warp(now1);

        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit EnQueuedWithdrawal(address(token), alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        uint256 outOfBoundsIndex = 1;

        uint256 now2 = now1 + withdrawalDelay;
        vm.warp(now2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowRateWithdrawalQueueErrors.IndexOutsideWithdrawalQueue.selector, 1, outOfBoundsIndex
            )
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawal(bob, outOfBoundsIndex);
    }

    function testFinaliseQueuedWithdrawalAlreadyProcessed() public {
        testFinaliseQueuedWithdrawalERC20();
        vm.expectRevert(
            abi.encodeWithSelector(IFlowRateWithdrawalQueueErrors.WithdrawalAlreadyProcessed.selector, bob, 0)
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawal(bob, 0);
    }

    function testFinaliseQueuedWithdrawalERC20TooEarly() public {
        configureFlowRate();
        transferTokensToChild();
        activateWithdrawalQueue();

        uint256 amount = 5;

        uint256 now1 = 100;
        vm.warp(now1);

        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit EnQueuedWithdrawal(address(token), alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        uint256 now2 = now1 + withdrawalDelay - 1;
        vm.warp(now2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector, now2, now1 + withdrawalDelay
            )
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawal(bob, 0);
    }

    function prepareForERC20AggregatedTest() public returns (uint256) {
        configureFlowRate();
        transferTokensToChild();
        activateWithdrawalQueue();

        uint256 numWithdrawalsToQueue = 10;
        uint256 now1 = 1000;
        uint256 amount = 100;
        uint256 total = 0;

        for (uint256 i = 0; i < numWithdrawalsToQueue; i++) {
            now1 += 100;
            vm.warp(now1);
            amount += 1;
            total += amount;

            // Fake a crosschain transfer from the child chain to the root chain.
            bytes memory data = abi.encode(WITHDRAW_SIG, token, alice, bob, amount);

            vm.prank(address(mockAxelarAdaptor));
            vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
            emit EnQueuedWithdrawal(address(token), alice, bob, amount, now1, i);
            rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
        }

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, numWithdrawalsToQueue, "bob's array length");

        return total;
    }

    function prepareForEtherAggregatedTest() public returns (uint256) {
        configureFlowRate();
        transferEtherToChild();
        activateWithdrawalQueue();

        uint256 numWithdrawalsToQueue = 10;
        uint256 now1 = 1000;
        uint256 amount = 100;
        uint256 total = 0;

        for (uint256 i = 0; i < numWithdrawalsToQueue; i++) {
            now1 += 100;
            vm.warp(now1);
            amount += 1;
            total += amount;

            // Fake a crosschain transfer from the child chain to the root chain.
            bytes memory data = abi.encode(WITHDRAW_SIG, NATIVE_ETH, alice, bob, amount);

            vm.prank(address(mockAxelarAdaptor));
            vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
            emit EnQueuedWithdrawal(address(NATIVE_ETH), alice, bob, amount, now1, i);
            rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);
        }

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, numWithdrawalsToQueue, "bob's array length");

        return total;
    }

    function testFinaliseQueuedWithdrawalsAggregatedERC20() public {
        uint256 total = prepareForERC20AggregatedTest();

        uint256[] memory indices = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            indices[i] = i;
        }

        vm.warp(block.timestamp + withdrawalDelay);

        address childERC20Token = rootBridgeFlowRate.rootTokenToChildToken(address(token));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 101, 0);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 102, 1);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 103, 2);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 104, 3);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 105, 4);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 106, 5);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 107, 6);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 108, 7);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 109, 8);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(token), alice, bob, 110, 9);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit RootChainERC20Withdraw(address(token), childERC20Token, alice, bob, total);
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(token), indices);

        assertEq(token.balanceOf(address(bob)), total, "bob");
    }

    function testFinaliseQueuedWithdrawalsAggregatedEther() public {
        uint256 total = prepareForEtherAggregatedTest();

        uint256[] memory indices = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            indices[i] = i;
        }

        vm.warp(block.timestamp + withdrawalDelay);

        address childERC20Token = rootBridgeFlowRate.rootTokenToChildToken(address(NATIVE_ETH));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 101, 0);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 102, 1);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 103, 2);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 104, 3);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 105, 4);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 106, 5);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 107, 6);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 108, 7);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 109, 8);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit ProcessedWithdrawal(address(NATIVE_ETH), alice, bob, 110, 9);
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit RootChainETHWithdraw(address(NATIVE_ETH), childERC20Token, alice, bob, total);
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(NATIVE_ETH), indices);

        assertEq(bob.balance, total, "bob");
    }

    function testFinaliseQueuedWithdrawalsAggregatedOutOfBounds() public {
        prepareForEtherAggregatedTest();

        uint256[] memory indices = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            indices[i] = i;
        }
        uint256 outOfBoundsIndex = 15;
        indices[7] = outOfBoundsIndex;

        vm.warp(block.timestamp + withdrawalDelay);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowRateWithdrawalQueueErrors.IndexOutsideWithdrawalQueue.selector, 10, outOfBoundsIndex
            )
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(NATIVE_ETH), indices);
    }

    function testFinaliseQueuedWithdrawalsAggregatedAlreadyProcessed() public {
        prepareForEtherAggregatedTest();

        uint256[] memory indices = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            indices[i] = i;
        }
        uint256 alreadyProcessed = 5;
        indices[7] = alreadyProcessed;

        vm.warp(block.timestamp + withdrawalDelay);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowRateWithdrawalQueueErrors.WithdrawalAlreadyProcessed.selector, bob, alreadyProcessed
            )
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(NATIVE_ETH), indices);
    }

    function testFinaliseQueuedWithdrawalsAggregatedTooEarly() public {
        prepareForEtherAggregatedTest();

        uint256[] memory indices = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            indices[i] = i;
        }
        uint256 timeOfFirstQueuedWithdrawal = 1100;
        uint256 timeFirstQueuedWithdrawalReady = timeOfFirstQueuedWithdrawal + withdrawalDelay;

        vm.expectRevert(
            abi.encodeWithSelector(
                IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector,
                block.timestamp,
                timeFirstQueuedWithdrawalReady
            )
        );
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(NATIVE_ETH), indices);
    }

    function testFinaliseQueuedWithdrawalsAggregatedMismatch() public {
        prepareForERC20AggregatedTest();
        transferEtherToChild();

        uint256 amount = 6;

        // Fake a crosschain transfer a different token: Ether.
        bytes memory data = abi.encode(WITHDRAW_SIG, NATIVE_ETH, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit EnQueuedWithdrawal(address(NATIVE_ETH), alice, bob, amount, block.timestamp, 10);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        // Indices for a withdrawal for the ERC 20 token and one for Ether
        uint256[] memory indices = new uint256[](2);
        indices[0] = 3;
        indices[1] = 10;

        vm.warp(block.timestamp + withdrawalDelay);
        vm.expectRevert(abi.encodeWithSelector(MixedTokens.selector, address(token), address(NATIVE_ETH)));
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(token), indices);
    }

    function testFinaliseQueuedWithdrawalsAggregatedNoIndices() public {
        prepareForERC20AggregatedTest();
        transferEtherToChild();

        uint256[] memory indices = new uint256[](0);

        vm.warp(block.timestamp + withdrawalDelay);
        vm.expectRevert(abi.encodeWithSelector(ProvideAtLeastOneIndex.selector));
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(token), indices);
    }

    function testFinaliseQueuedWithdrawalReentrancy() public {
        // Don't bother configuring the token.  - it will end up in the queue

        // Mock transfer tokens to child
        ReentrancyAttackERC20 attackToken = new ReentrancyAttackERC20(payable(address(rootBridgeFlowRate)));
        attackToken.mint(charlie, BANK_OF_CHARLIE_TREASURY);
        vm.startPrank(charlie);
        vm.deal(charlie, 1 ether);
        // Need to first map the token.
        rootBridgeFlowRate.mapToken{value: 100}(attackToken);
        attackToken.approve(address(rootBridgeFlowRate), BRIDGED_VALUE);
        rootBridgeFlowRate.deposit{value: 100}(attackToken, BRIDGED_VALUE);
        vm.stopPrank();

        uint256 amount = 5;

        uint256 now1 = 100;
        vm.warp(now1);

        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, attackToken, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit EnQueuedWithdrawal(address(attackToken), alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        attackToken.prepareAttackWithdrawal(0);

        uint256 now2 = now1 + withdrawalDelay;
        vm.warp(now2);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        rootBridgeFlowRate.finaliseQueuedWithdrawal(bob, 0);
    }

    function testFinaliseQueuedWithdrawalsAggregatedReentrancy() public {
        // Don't bother configuring the token.  - it will end up in the queue

        // Mock transfer tokens to child
        ReentrancyAttackERC20 attackToken = new ReentrancyAttackERC20(payable(address(rootBridgeFlowRate)));
        attackToken.mint(charlie, BANK_OF_CHARLIE_TREASURY);
        vm.startPrank(charlie);
        vm.deal(charlie, 1 ether);
        // Need to first map the token.
        rootBridgeFlowRate.mapToken{value: 100}(attackToken);
        attackToken.approve(address(rootBridgeFlowRate), BRIDGED_VALUE);
        rootBridgeFlowRate.deposit{value: 100}(attackToken, BRIDGED_VALUE);
        vm.stopPrank();

        uint256 amount = 5;

        uint256 now1 = 100;
        vm.warp(now1);

        // Fake a crosschain transfer from the child chain to the root chain.
        bytes memory data = abi.encode(WITHDRAW_SIG, attackToken, alice, bob, amount);

        vm.prank(address(mockAxelarAdaptor));
        vm.expectEmit(true, true, true, true, address(rootBridgeFlowRate));
        emit EnQueuedWithdrawal(address(attackToken), alice, bob, amount, now1, 0);
        rootBridgeFlowRate.onMessageReceive(CHILD_CHAIN_NAME, CHILD_BRIDGE_ADAPTOR_STRING, data);

        uint256 queueLen = rootBridgeFlowRate.getPendingWithdrawalsLength(bob);
        assertEq(queueLen, 1, "bob's queue length");

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        attackToken.prepareAttackWithdrawalAggregated(indices);

        uint256 now2 = now1 + withdrawalDelay;
        vm.warp(now2);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        rootBridgeFlowRate.finaliseQueuedWithdrawalsAggregated(bob, address(attackToken), indices);
    }
}
