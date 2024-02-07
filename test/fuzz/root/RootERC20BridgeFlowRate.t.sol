// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {
    IRootERC20BridgeEvents,
    IERC20Metadata,
    IRootERC20BridgeErrors,
    IRootERC20Bridge
} from "../../../src/root/RootERC20Bridge.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {WETH} from "../../../src/lib/WETH.sol";
import {MockAdaptor} from "../../mocks/root/MockAdaptor.sol";

contract RootERC20BridgeFlowRateTest is Test {
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant DEPOSIT_SIG = keccak256("DEPOSIT");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");
    address constant CHILD_BRIDGE = address(3);
    uint256 constant IMX_DEPOSITS_LIMIT = 10000 ether;

    ChildERC20 childTokenTemplate;
    ChildERC20 imxToken;
    WETH wETH;
    MockAdaptor mockAdaptor;
    RootERC20BridgeFlowRate bridge;

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

        bridge = new RootERC20BridgeFlowRate(address(this));
        bridge.initialize(
            roles,
            address(mockAdaptor),
            CHILD_BRIDGE,
            address(childTokenTemplate),
            address(imxToken),
            address(wETH),
            IMX_DEPOSITS_LIMIT,
            address(this)
        );
    }

    function testFuzz_RateLimitForIMX(uint256 capacity) public {
        vm.assume(capacity < 1000 ether && capacity > 86400);
        uint256 refillRate = capacity / 86400;
        uint256 largeTransferThreshold = capacity / 2;

        // bridge.setRateControlThreshold(, capacity, refillRate, largeTransferThreshold);
    }
}
