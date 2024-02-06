// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {IFlowRateWithdrawalQueueErrors} from "../../../src/root/flowrate/FlowRateWithdrawalQueue.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Utils} from "../../utils.t.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 *  @dev This test suite tests the flow rate control functionality of already deployed RootERC20BridgeFlowRate contracts.
 *    The tests are executed against forked chains for each deployment (e.g., mainnet, testnet).
 *    The objective of this test suite is not to exhaustively test the flow rate functionality, as this is adequately
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
 *          Details: https://github.com/foundry-rs/forge-std/issues/318#issuecomment-1452463876
 */
contract RootERC20BridgeFlowRateForkTest is Test, Utils {
    address private constant ETH = address(0xeee);

    string[] private deployments = vm.envString("DEPLOYMENTS", ",");

    // rpc endpoints to the root chain for each environment
    mapping(string => string) private rpcURLForEnv;
    // the fork id for each environment
    mapping(string => uint256) private forkIdForEnv;
    // the list of tokens for which flow rate parameters have been configured, in each environment
    mapping(string => address[]) private tokensForEnv;
    // the root bridge address in each environment
    mapping(string => RootERC20BridgeFlowRate) private bridgeInEnv;

    // the deployment environment currently being tested
    string private deployment;

    /**
     * @dev Runs a test function against each deployment listed in the DEPLOYMENTS environment variable (e.g. MAINNET, TESTNET)
     */
    modifier forEachDeployment() {
        for (uint256 i; i < deployments.length; i++) {
            deployment = deployments[i];
            vm.selectFork(forkIdForEnv[deployment]);
            _;
        }
    }

    function setUp() public {
        // extract the rpc endpoint, bridge address, and tokens for each deployment
        for (uint256 i; i < deployments.length; i++) {
            string memory dep = deployments[i];
            rpcURLForEnv[dep] = vm.envString(string.concat(dep, "_RPC_URL"));
            bridgeInEnv[dep] = RootERC20BridgeFlowRate(payable(vm.envAddress(string.concat(dep, "_BRIDGE_ADDRESS"))));
            tokensForEnv[dep] = vm.envAddress(string.concat(dep, "_FLOW_RATED_TOKENS"), ",");
            forkIdForEnv[dep] = vm.createFork(rpcURLForEnv[dep]);
        }
    }

    /**
     * @dev Tests that that exceeding the flow rate parameters for any of the configured tokens in a given deployment, triggers the withdrawal delays.
     *        This test is run for each deployment environment, and against each configured token.
     *        The test also checks that flow rate parameters configured are valid.
     */
    function test_withdrawalQueueEnforcedWhenFlowRateExceeded() public forEachDeployment {
        RootERC20BridgeFlowRate bridge = bridgeInEnv[deployment];
        address[] memory tokens = tokensForEnv[deployment];
        // precondition: sanity check on the the current state and parameters of the bridge
        assertFalse(bridge.withdrawalQueueActivated(), "Precondition: Withdrawal queue should not already be active");
        assertGt(bridge.withdrawalDelay(), 0, "Precondition: Withdrawal delay should be greater than 0");

        address withdrawer1 = createAddress(1);
        address withdrawer2 = createAddress(2);
        uint256 snapshotId = vm.snapshot();
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            // exceed flow rate for token
            _exceedFlowRateParameters(bridge, token, withdrawer1);

            // Verify that any subsequent withdrawal by other users for other tokens gets queued
            address otherToken = tokens[(i + 1) % tokens.length];
            _sendWithdrawalMessage(bridge, otherToken, withdrawer2, 1 ether);
            _verifyWithdrawalWasQueued(bridge, otherToken, withdrawer2, 1 ether);
            _verifyBalance(otherToken, withdrawer2, 0);

            // roll back state for subsequent test
            vm.revertTo(snapshotId);
        }
    }

    /**
     * @dev Tests that withdrawal of non-flow rated tokens get queued.
     *      This test is run for each deployment environment.
     */
    function test_nonFlowRatedTokenWithdrawalsAreQueued() public forEachDeployment {
        RootERC20BridgeFlowRate bridge = bridgeInEnv[deployment];
        address withdrawer = createAddress(1);

        // preconditions
        assertFalse(bridge.withdrawalQueueActivated(), "Precondition: Withdrawal queue should not activate");

        // deploy and map a token
        ERC20 nonFlowRatedToken = new ERC20("Test Token", "TEST");
        bridge.mapToken{value: 100 gwei}(nonFlowRatedToken);
        _giveBridgeFunds(address(bridge), address(nonFlowRatedToken), 1 ether);

        // ensure withdrawals for the token, which does not have flow rate configured, is queued
        _sendWithdrawalMessage(bridge, address(nonFlowRatedToken), withdrawer, 1 ether);
        _verifyWithdrawalWasQueued(bridge, address(nonFlowRatedToken), withdrawer, 1 ether);

        // The queue should only affect the specific token
        assertFalse(bridge.withdrawalQueueActivated());
    }

    /**
     *   @dev Tests that for queued withdrawal the mandatory delay is enforced.
     *        Also ensures that the withdrawal delay parameters for a deployment are valid.
     */
    function test_withdrawalQueueDelayEnforced() public forEachDeployment {
        RootERC20BridgeFlowRate bridge = bridgeInEnv[deployment];
        // preconditions: sanity check on the current state and parameters of the bridge
        assertGt(bridge.withdrawalDelay(), 0 days, "Precondition: Withdrawal delay should be greater than 0");

        address[] memory tokens = tokensForEnv[deployment];
        uint256 snapshotId = vm.snapshot();
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = bridge.largeTransferThresholds(token) + 1;
            _giveBridgeFunds(address(bridge), token, amount);

            address withdrawer = createAddress(1);
            _sendWithdrawalMessage(bridge, token, withdrawer, amount);
            RootERC20BridgeFlowRate.PendingWithdrawal memory pending =
                _verifyWithdrawalWasQueued(bridge, token, withdrawer, amount);

            // check that early withdrawal attempt fails
            vm.expectRevert(
                abi.encodeWithSelector(
                    IFlowRateWithdrawalQueueErrors.WithdrawalRequestTooEarly.selector,
                    block.timestamp,
                    pending.timestamp + bridge.withdrawalDelay()
                )
            );
            bridge.finaliseQueuedWithdrawal(withdrawer, 0);

            // check that timely withdrawal succeeds
            vm.warp(block.timestamp + bridge.withdrawalDelay());
            bridge.finaliseQueuedWithdrawal(withdrawer, 0);
            _verifyBalance(token, withdrawer, amount);

            // roll back state for subsequent test
            vm.revertTo(snapshotId);
        }
    }

    /**
     *   @dev Tests that withdrawals that exceed the size threshold for a given token get queued.
     *        Also ensures that the threshold parameters for a token are valid.
     */
    function test_withdrawalIsQueuedIfSizeThresholdForTokenExceeded() public forEachDeployment {
        address[] memory tokens = tokensForEnv[deployment];
        RootERC20BridgeFlowRate bridge = bridgeInEnv[deployment];
        address withdrawer = createAddress(1);

        uint256 snapshotId = vm.snapshot();
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 largeAmount = bridge.largeTransferThresholds(token) + 1;

            // preconditions
            _checkIsValidLargeThreshold(token, largeAmount);

            _sendWithdrawalMessage(bridge, token, withdrawer, largeAmount);
            _verifyWithdrawalWasQueued(bridge, token, withdrawer, largeAmount);

            // The queue should only affect the specific token
            assertFalse(bridge.withdrawalQueueActivated());

            // roll back state for subsequent test
            vm.revertTo(snapshotId);
        }
    }

    /// @dev check that the large transfer threshold for the token is at least greater than 1 whole unit of the token
    function _checkIsValidLargeThreshold(address token, uint256 amount) private {
        if (token == ETH) {
            assertGe(amount, 1 ether);
        } else {
            assertGe(amount, 1 ^ IERC20Metadata(token).decimals());
        }
    }

    /// @dev sends a number of withdrawal messages to the bridge that exceeds the flow rate parameters for a given token
    function _exceedFlowRateParameters(RootERC20BridgeFlowRate bridge, address token, address withdrawer) private {
        (uint256 capacity, uint256 depth,, uint256 refillRate) = bridge.flowRateBuckets(token);

        // Check if the thresholds are within reasonable range
        assertGt(
            bridge.largeTransferThresholds(token),
            0,
            "Precondition: Large transfer threshold should be greater than zero"
        );
        assertLt(
            bridge.largeTransferThresholds(token),
            capacity,
            "Precondition: Large transfer threshold should be less than capacity"
        );
        assertGt(capacity, 0);
        assertGt(refillRate, 0);
        assertEq(bridge.getPendingWithdrawalsLength(withdrawer), 0);

        uint256 largeTransferThreshold = bridge.largeTransferThresholds(token);
        uint256 totalWithdrawals;
        uint256 amount;
        while (depth > 0) {
            amount = depth > largeTransferThreshold ? largeTransferThreshold - 1 : depth + 1;
            _giveBridgeFunds(address(bridge), token, amount);
            _sendWithdrawalMessage(bridge, token, withdrawer, amount);
            (, depth,,) = bridge.flowRateBuckets(token);
            totalWithdrawals += amount;
        }

        assertTrue(bridge.withdrawalQueueActivated());
        _verifyWithdrawalWasQueued(bridge, token, withdrawer, amount);
        _verifyBalance(token, withdrawer, totalWithdrawals - amount);
    }

    /// @dev sends an amount of a given token to the bridge.
    function _giveBridgeFunds(address bridge, address token, uint256 amount) private {
        if (token == ETH) {
            deal(bridge, amount);
        } else {
            deal(token, bridge, amount);
        }
    }

    /// @dev checks that a withdrawal was queued for a given token and user
    function _verifyWithdrawalWasQueued(
        RootERC20BridgeFlowRate bridge,
        address token,
        address withdrawer,
        uint256 txValue
    ) private returns (RootERC20BridgeFlowRate.PendingWithdrawal memory) {
        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;
        assertEq(bridge.getPendingWithdrawalsLength(withdrawer), 1, "Expected 1 pending withdrawal");
        RootERC20BridgeFlowRate.PendingWithdrawal[] memory pending = bridge.getPendingWithdrawals(withdrawer, indices);
        assertEq(pending[0].withdrawer, withdrawer, "Unexpected withdrawer");
        assertEq(pending[0].token, token, "Unexpected token");
        assertEq(pending[0].amount, txValue, "Unexpected amount");
        return pending[0];
    }

    function _verifyBalance(address token, address withdrawer, uint256 expectedAmount) private {
        if (token == ETH) {
            assertEq(withdrawer.balance, expectedAmount, "Balance does not match expected");
        } else {
            assertEq(ERC20(token).balanceOf(withdrawer), expectedAmount, "Balance does not match expected");
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
