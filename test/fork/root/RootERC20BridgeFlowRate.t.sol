// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {IFlowRateWithdrawalQueueErrors} from "../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/Console.sol";

import {Utils} from "../../utils.t.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 *  @dev This test suite evaluates the flow rate functionality of already deployed RootERC20BridgeFlowRate contracts.
 *    The tests are executed against forked chains for each deployment (e.g., mainnet, testnet).
 *    This test suite's objective is not to exhaustively test the flow rate functionality, as this is adequately
 *    addressed in unit and integration tests. Instead, it aims to ensure that the functionality works as expected
 *    in each deployed environment. Conducting live E2E tests on the flow rate capability in a mainnet environment
 *    for each configured token would be complex, expensive, and potentially disruptive.
 *    Therefore, these tests provide an alternative way to verify that these capabilities function correctly in
 *    the deployed environment. They can help identify any issues related to deployment parameters or
 *    specific tokens or deployment conditions that may not have been captured in unit and integration tests.
 *
 *    The test suite is parameterized by the following environment variables:
 *      - DEPLOYMENTS: comma-separated list of deployments to test (e.g., MAINNET, TESTNET)
 *      - <DEPLOYMENT>_RPC_URL: RPC URL for the forked chain for the deployment (e.g., MAINNET_RPC_URL)
 *      - <DEPLOYMENT>_BRIDGE_ADDRESS: address of the RootERC20BridgeFlowRate contract for the deployment (e.g., MAINNET_BRIDGE_ADDRESS)
 *      - <DEPLOYMENT>_FLOW_RATED_TOKENS: comma-separated list of tokens to test for the deployment (e.g., MAINNET_FLOW_RATED_TOKENS)
 *
 *    NOTE: Foundry's deal() function does not currently support contracts that use the proxy pattern, such as USDC.
 *          Hence this test is limited to ETH and ERC20 tokens that do not use the proxy pattern.
 */
contract RootERC20BridgeFlowRateForkTest is Test, Utils {
    address private constant ETH = address(0xeee);

    string[] private deployments = vm.envString("DEPLOYMENTS", ",");
    mapping(string => string) private rpcURLForEnv;
    mapping(string => uint256) private forkOfEnv;
    mapping(string => RootERC20BridgeFlowRate) private bridgeForEnv;
    mapping(string => address[]) private tokensForEnv;

    string private deployment;

    /**
     * @dev runs a given test function for each deployment in the DEPLOYMENTS environment variable (e.g. MAINNET, TESTNET)
     */
    modifier forEachDeployment() {
        for (uint256 i; i < deployments.length; i++) {
            deployment = deployments[i];
            vm.selectFork(forkOfEnv[deployment]);
            _;
        }
    }

    function setUp() public {
        for (uint256 i; i < deployments.length; i++) {
            string memory dep = deployments[i];
            rpcURLForEnv[dep] = vm.envString(string.concat(dep, "_RPC_URL"));
            bridgeForEnv[dep] = RootERC20BridgeFlowRate(payable(vm.envAddress(string.concat(dep, "_BRIDGE_ADDRESS"))));
            tokensForEnv[dep] = vm.envAddress(string.concat(dep, "_FLOW_RATED_TOKENS"), ",");
            forkOfEnv[dep] = vm.createFork(rpcURLForEnv[dep]);
        }
    }

    /**
     * @dev Tests that that exceeding the flow rate parameters for any of the configured tokens in a given deployment, triggers the withdrawal delays.
     *        This test is run for each deployment environment, and against each configured token.
     *        The test also checks that flow rate parameters configured are valid.
     */
    function test_withdrawalQueueEnforcedWhenFlowRateExceeded() public forEachDeployment {
        RootERC20BridgeFlowRate bridge = bridgeForEnv[deployment];
        address[] memory tokens = tokensForEnv[deployment];
        // preconditions
        assertFalse(bridge.withdrawalQueueActivated());
        assertGt(bridge.withdrawalDelay(), 0);

        address receiver1 = createAddress(1);
        address receiver2 = createAddress(2);
        uint256 snapshotId = vm.snapshot();
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            // exceed flow rate for any token
            _exceedFlowRateParameters(bridge, token, receiver1);

            // Verify that any subsequent withdrawal by other users for other tokens gets queued
            address otherToken = tokens[(i + 1) % tokens.length];
            _sendWithdrawalMessage(bridge, otherToken, receiver2, 1 ether);
            _verifyWithdrawalWasQueued(bridge, otherToken, receiver2, 1 ether);
            _verifyBalance(otherToken, receiver2, 0);

            // roll back state for subsequent test
            vm.revertTo(snapshotId);
        }
    }

    /**
     * @dev Tests that withdrawal of non-flow rated tokens are queued.
     *        This test is run for each deployment environment.
     */
    function test_nonFlowRatedTokenWithdrawalsAreQueued() public forEachDeployment {
        RootERC20BridgeFlowRate bridge = bridgeForEnv[deployment];
        address receiver = createAddress(1);

        // preconditions
        assertFalse(bridge.withdrawalQueueActivated(), "Precondition: Withdrawal queue should not activate");

        // deploy and map a token
        ERC20 erc20 = new ERC20("Test Token", "TEST");
        bridge.mapToken{value: 100 gwei}(erc20);
        _giveBridgeFunds(address(erc20), address(erc20), 1 ether);

        // ensure withdrawals for the token, which does not have flow rate configured, is queued
        _sendWithdrawalMessage(bridge, address(erc20), receiver, 1 ether);
        _verifyWithdrawalWasQueued(bridge, address(erc20), receiver, 1 ether);

        // The queue should only affect the specific token
        assertFalse(bridge.withdrawalQueueActivated());
    }

    /**
     *   @dev Tests that for queued withdrawal the mandatory delay is enforced. Also ensures that the withdrawal delay parameters for a deployment are valid.
     */
    function test_withdrawalQueueDelayEnforced() public forEachDeployment {
        uint256 snapshotId = vm.snapshot();
        address[] memory tokens = tokensForEnv[deployment];
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            RootERC20BridgeFlowRate bridge = bridgeForEnv[deployment];

            assertTrue(
                bridge.withdrawalDelay() > 0 days && bridge.withdrawalDelay() <= 3 days,
                "Precondition: Withdrawal delay appears either too low or too high"
            );

            address receiver = address(12234);
            uint256 amount = bridge.largeTransferThresholds(token) + 1;

            _sendWithdrawalMessage(bridge, token, receiver, amount);
            _verifyWithdrawalWasQueued(bridge, token, receiver, amount);

            // check that early withdrawal attempt fails
            vm.expectRevert();
            bridge.finaliseQueuedWithdrawal(receiver, 0);

            // check that timely withdrawal succeeds
            vm.warp(block.timestamp + bridge.withdrawalDelay());
            bridge.finaliseQueuedWithdrawal(receiver, 0);
            _verifyBalance(token, receiver, amount);

            // roll back state for subsequent test
            vm.revertTo(snapshotId);
        }
    }

    function test_withdrawalIsQueuedIfSizeThresholdForTokenExceeded() public forEachDeployment {
        address[] memory tokens = tokensForEnv[deployment];
        RootERC20BridgeFlowRate bridge = bridgeForEnv[deployment];
        address receiver = createAddress(1);

        uint256 snapshotId = vm.snapshot();
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 largeAmount = bridge.largeTransferThresholds(token) + 1;

            // preconditions
            _checkIsValidLargeThreshold(token, largeAmount);

            _sendWithdrawalMessage(bridge, token, receiver, largeAmount);
            _verifyWithdrawalWasQueued(bridge, token, receiver, largeAmount);

            // The queue should only affect the specific token
            assertFalse(bridge.withdrawalQueueActivated());

            // roll back state for subsequent test
            vm.revertTo(snapshotId);
        }
    }

    // check that the large transfer threshold for the token is at least greater than 1 whole unit of the token
    function _checkIsValidLargeThreshold(address token, uint256 amount) private {
        if (token == ETH) {
            assertGe(amount, 1 ether);
        } else {
            assertGe(amount, 1 ^ IERC20Metadata(token).decimals());
        }
    }

    function _exceedFlowRateParameters(RootERC20BridgeFlowRate bridge, address token, address receiver) private {
        (uint256 capacity, uint256 depth,, uint256 refillRate) = bridge.flowRateBuckets(token);

        uint256 oneUnit = token == ETH ? 1 ether : 1 ^ IERC20Metadata(token).decimals();
        // Check if the thresholds are within reasonable range
        assertGt(
            bridge.largeTransferThresholds(token),
            oneUnit,
            "Precondition: Large transfer threshold should be greater than 1 unit of token"
        );
        assertLt(
            bridge.largeTransferThresholds(token),
            capacity,
            "Precondition: Large transfer threshold should be less than capacity"
        );
        assertGt(capacity, oneUnit);
        assertGt(refillRate, 0);
        assertEq(bridge.getPendingWithdrawalsLength(receiver), 0);

        uint256 txValue = bridge.largeTransferThresholds(token) - 1;
        uint256 numTxs = depth > txValue ? (depth / txValue) + 2 : 1;

        _giveBridgeFunds(address(bridge), token, numTxs * txValue);

        // withdraw until flow rate is exceeded
        for (uint256 i = 0; i < numTxs; i++) {
            (, depth,,) = bridge.flowRateBuckets(token);
            _sendWithdrawalMessage(bridge, token, receiver, txValue);
        }

        assertTrue(bridge.withdrawalQueueActivated());
        _verifyWithdrawalWasQueued(bridge, token, receiver, txValue);
        _verifyBalance(token, receiver, (numTxs - 1) * txValue);
    }

    function _giveBridgeFunds(address bridge, address token, uint256 amount) private {
        if (token == ETH) {
            deal(bridge, amount);
        } else {
            deal(token, bridge, amount);
        }
    }

    function _verifyWithdrawalWasQueued(
        RootERC20BridgeFlowRate bridge,
        address token,
        address receiver,
        uint256 txValue
    ) private {
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        assertEq(bridge.getPendingWithdrawalsLength(receiver), 1, "Expected 1 pending withdrawal");
        RootERC20BridgeFlowRate.PendingWithdrawal[] memory pending = bridge.getPendingWithdrawals(receiver, indices);
        assertEq(pending[0].withdrawer, receiver, "Unexpected withdrawer");
        assertEq(pending[0].token, token, "Unexpected token");
        assertEq(pending[0].amount, txValue, "Unexpected amount");
    }

    function _verifyBalance(address token, address receiver, uint256 expectedAmount) private {
        if (token == ETH) {
            assertEq(receiver.balance, expectedAmount);
        } else {
            assertEq(ERC20(token).balanceOf(receiver), expectedAmount);
        }
    }

    function _sendWithdrawalMessage(RootERC20BridgeFlowRate bridge, address token, address sender, uint256 txValue)
        private
    {
        //prank as axelar sending a message to the adapter
        vm.startPrank(address(bridge.rootBridgeAdaptor()));
        bytes memory predictedPayload = abi.encode(bridge.WITHDRAW_SIG(), token, sender, sender, txValue);
        bridge.onMessageReceive(predictedPayload);
        vm.stopPrank();
    }

    function createAddress(uint256 index) private view returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked("root-bridge-fork-test", index, blockhash(block.number)))))
        );
    }
}
