// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./FlowRateDetection.sol";
import "./FlowRateWithdrawalQueue.sol";
import "../RootERC20Bridge.sol";

import {
    IRootERC20BridgeFlowRateEvents,
    IRootERC20BridgeFlowRateErrors
} from "../../interfaces/root/flowrate/IRootERC20BridgeFlowRate.sol";

contract RootERC20BridgeFlowRate is
    RootERC20Bridge,
    ReentrancyGuardUpgradeable,
    FlowRateDetection,
    FlowRateWithdrawalQueue,
    IRootERC20BridgeFlowRateEvents,
    IRootERC20BridgeFlowRateErrors
{
    // Constants used for access control
    bytes32 private constant RATE_CONTROL_ROLE = keccak256("RATE");

    // Threshold for large transfers
    // Map ERC 20 token address to threshold
    mapping(address => uint256) public largeTransferThresholds;

    function initialize(
        InitializationRoles memory newRoles,
        address newRootBridgeAdaptor,
        address newChildERC20Bridge,
        string memory newChildBridgeAdaptor,
        address newChildTokenTemplate,
        address newRootIMXToken,
        address newRootWETHToken,
        string memory newChildChain,
        uint256 newImxCumulativeDepositLimit,
        address rateAdmin,
        address superAdmin
    ) external initializer {
        __RootERC20Bridge_init(
            newRoles,
            newRootBridgeAdaptor,
            newChildERC20Bridge,
            newChildBridgeAdaptor,
            newChildTokenTemplate,
            newRootIMXToken,
            newRootWETHToken,
            newChildChain,
            newImxCumulativeDepositLimit
        );

        __FlowRateWithdrawalQueue_init();

        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(RATE_CONTROL_ROLE, rateAdmin);
    }

    // Ensure initialize from RootERC20Bridge can not be called.
    function initialize(
        InitializationRoles memory,
        address,
        address,
        string memory,
        address,
        address,
        address,
        string memory,
        uint256
    ) external pure override {
        revert WrongInitializer();
    }

    /**
     * @notice Activate the withdrawal queue for all tokens.
     * @dev This function manually activates the withdrawal queue. However the
     *      queue is automatically activated when the flow rate detection code
     *      determines that there is a large outflow of any token.
     *      Only RATE role.
     */
    function activateWithdrawalQueue() external onlyRole(RATE_CONTROL_ROLE) {
        _activateWithdrawalQueue();
    }

    /**
     * @notice Deactivate the withdrawal queue for all tokens.
     * @dev This function manually deactivates the withdrawal queue.
     *      Only RATE role.
     */
    function deactivateWithdrawalQueue() external onlyRole(RATE_CONTROL_ROLE) {
        _deactivateWithdrawalQueue();
    }

    /**
     * @notice Set the time in the queue for queued withdrawals.
     * @param delay The number of seconds between when the ExitHelper is called to
     *         complete a crosschain transfer and when finaliseHeldTransfers can be
     *         called.
     * @dev Only RATE role.
     * NOTE: There is no range checking on delay. Delay could be inadvertently be set to
     *       a very large value, representing a large delay. If this is done, the withdrawal
     *       delay should be set again.
     *       Another possible scenario is that the withdrawal queue has been enabled
     *       inadvertently. In this case, the withdrawal queue could be disabled,
     *       and the withdrawal delay could be set to 0, the queued withdrawals could
     *       all be finalised, and then the withdrawal delay could be set to the desired
     *       value.
     */
    function setWithdrawalDelay(uint256 delay) external onlyRole(RATE_CONTROL_ROLE) {
        _setWithdrawalDelay(delay);
    }

    /**
     * @notice Set the thresholds to use for a certain token.
     * @param token The token to apply the thresholds to.
     * @param capacity The size of the bucket in tokens.
     * @param refillRate How quickly the bucket refills in tokens per second.
     * @param largeTransferThreshold Threshold over which a withdrawal is deemed to be large,
     *         and will be put in the withdrawal queue.
     * @dev Only RATE role.
     *
     * Example parameter values:
     *  Assume the desired configuration is:
     *  - large transfer threshold is 100,000 IMX.
     *  - high flow rate threshold is 1,000,000 IMX per hour.
     *  Further assume the ERC 20 contract has been configured with 18 decimals. This is true
     *  for IMX and MATIC.
     *
     *  The capacity should be set to the flow rate number. In this example, 1,000,000 IMX.
     *  The refill rate should be the capacity divided by the flow rate period in seconds.
     *   In this example, 1,000,000 IMX divided by 3600 seconds in an hour.
     *
     *  Hence, the configuration should be set to:
     *  - capacity = 1,000,000,000,000,000,000,000,000
     *  - refillRate =     277,777,777,777,777,777,777
     *  - largeTransferThreshold = 100,000,000,000,000,000,000,000
     *
     * NOTE: Beyond checking that capacity and refillRate are not zero, no range checking is
     *       undertaken on capacity, refillRate, or largeTransferThreshold. Setting
     *       largeTransferThreshold to zero (or a very low value) would cause all (or most)
     *       withdrawals to be put the with withdrawal queue. Having a very large value for
     *       largeTransferThreshold or capacity will either reduce the effectiveness of
     *       the flow rate detection mechanism or prevent it from working altogether. As such,
     *       the values of capacity, refillRate and largeTransferThreshold should be chosen
     *       carefully.
     */
    function setRateControlThreshold(
        address token,
        uint256 capacity,
        uint256 refillRate,
        uint256 largeTransferThreshold
    ) external onlyRole(RATE_CONTROL_ROLE) {
        uint256 previousCapacity = flowRateBuckets[token].capacity;
        uint256 previousRefillRate = flowRateBuckets[token].refillRate;
        uint256 previousLargeTransferThreshold = largeTransferThresholds[token];
        _setFlowRateThreshold(token, capacity, refillRate);
        largeTransferThresholds[token] = largeTransferThreshold;
        emit RateControlThresholdSet(token, capacity, refillRate, largeTransferThreshold, previousCapacity, previousRefillRate, previousLargeTransferThreshold);
    }

    /**
     * @notice Complete crosschain transfer of funds.
     * @param data Contains the crosschain transfer information:
     *         - token: Token address on the root chain.
     *         - withdrawer: Account that initiated the transfer on the child chain.
     *         - receiver: Account to transfer tokens to.
     *         - amount: The number of tokens to transfer.
     * @dev Called by the ExitHelper.
     *      Only when not paused.
     */
    function _withdraw(bytes memory data) internal override {
        (address rootToken, address childToken, address withdrawer, address receiver, uint256 amount) =
            _decodeAndValidateWithdrawal(data);

        // Update the flow rate checking. Delay the withdrawal if the request was
        // for a token that has not been configured.
        bool delayWithdrawalUnknownToken = _updateFlowRateBucket(rootToken, amount);
        bool delayWithdrawalLargeAmount = false;

        // Delay the withdrawal if the amount is greater than the threshold.
        if (!delayWithdrawalUnknownToken) {
            delayWithdrawalLargeAmount = (amount >= largeTransferThresholds[rootToken]);
        }

        // Ensure storage variable is cached on the stack.
        bool queueActivated = withdrawalQueueActivated;

        if (delayWithdrawalLargeAmount || delayWithdrawalUnknownToken || queueActivated) {
            _enqueueWithdrawal(receiver, withdrawer, rootToken, amount);
            emit QueuedWithdrawal(
                rootToken,
                withdrawer,
                receiver,
                amount,
                delayWithdrawalLargeAmount,
                delayWithdrawalUnknownToken,
                queueActivated
            );
        } else {
            _executeTransfer(rootToken, childToken, withdrawer, receiver, amount);
        }
    }

    /**
     * @notice Withdraw a queued withdrawal.
     * @param receiver Address to withdraw value for.
     * @param index Offset into array of queued withdrawals.
     * @dev Only when not paused.
     */
    function finaliseQueuedWithdrawal(address receiver, uint256 index) external nonReentrant {
        (address withdrawer, address token, uint256 amount) = _processWithdrawal(receiver, index);
        address childToken = rootTokenToChildToken[token];
        _executeTransfer(token, childToken, withdrawer, receiver, amount);
    }

    /**
     * @notice Withdraw one or more queued withdrawals for a specific token, aggregating the amounts.
     * @param receiver Address to withdraw value for.
     * @param token Token to do the aggregated withdrawal for.
     * @param indices Offsets into array of queued withdrawals.
     * @dev Only when not paused.
     *   Note that withdrawer in the ERC20Withdraw event emitted in the _executeTransfer function
     *   will represent the withdrawer of the last bridge transfer.
     */
    function finaliseQueuedWithdrawalsAggregated(address receiver, address token, uint256[] calldata indices)
        external
        nonReentrant
    {
        if (indices.length == 0) {
            revert ProvideAtLeastOneIndex();
        }
        uint256 total = 0;
        address withdrawer = address(0);
        for (uint256 i = 0; i < indices.length; i++) {
            address actualToken;
            uint256 amount;
            (withdrawer, actualToken, amount) = _processWithdrawal(receiver, indices[i]);
            if (actualToken != token) {
                revert MixedTokens(token, actualToken);
            }
            total += amount;
        }
        address childToken = rootTokenToChildToken[token];
        _executeTransfer(token, childToken, withdrawer, receiver, total);
    }

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gapRootERC20PredicateFlowRate;
}
