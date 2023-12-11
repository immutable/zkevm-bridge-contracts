// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import "./FlowRateDetection.sol";
import "./FlowRateWithdrawalQueue.sol";
import "../RootERC20Bridge.sol";

import {
    IRootERC20BridgeFlowRateEvents,
    IRootERC20BridgeFlowRateErrors
} from "../../interfaces/root/flowrate/IRootERC20BridgeFlowRate.sol";

/**
 * @title  Root ERC 20 Bridge Flow Rate
 * @author Immutable Pty Ltd (Peter Robinson @drinkcoffee, Craig MacGregor @proletesseract)
 * @notice Adds security features to the `RootERC20Bridge` implementation help prevent or reduce the scope of attacks.
 * @dev    Features: In addition the features of the `RootERC20Bridge`, this contract adds the following capabilities:
 *         - A withdrawal queue is defined. In certain situations, a crosschain transfer results
 *           in a withdrawal being put in a "queue". Users can withdraw the amount after a delay.
 *           The default delay is one day. The queue is implemented as an array. Users can choose
 *           which queued withdrawals they want to process.
 *         - An account with `RATE` role can enable or disable the withdrawal queue, and configure
 *           parameters for each token related to the withdrawal queue.
 *         - Withdrawals of tokens whose amount is greater than a token specific threshold are
 *           put into the withdrawal queue. This just affects an individual withdrawal. It does
 *           not affect other withdrawals by that user or by any other user.
 *         - Withdrawals are put into the withdrawal queue when no thresholds have been defined
 *           for the token being withdrawn. This just affects an individual withdrawal. It does
 *           not affect other withdrawals by that user or by any other user.
 *         - If the rate of withdrawal of any token is over a token specific threshold, then all
 *           withdrwals are put into the withdrawal queue.
 *
 *         Almost all users will be unaffected by these changes, and for them the bridge will
 *         appear to operate as if `RootERC20Bridge` contract had been deployed. That is,
 *         almost all withdrawals will not go into a withdrawal queue if the
 *         RootERC20BridgeFlowRate contract has been configured for all tokens
 *         that are likely to be used on the bridge with appropriate thresholds.
 *
 *         Note: This is an upgradeable contract that should be operated behind OpenZeppelin's
 *               TransparentUpgradeableProxy.sol.
 *         Note: The initialize function is susceptible to front running. To prevent this,
 *               call the function when TransparentUpgradeableProxy.sol is deployed by passing
 *               in the function call data in TransparentUpgradeableProxy's constructor.
 *               Alternatively, deploy TransparentUpgradeableProxy, call initialize, and then
 *               check the contract's configuration. If the initialize call has been front run,
 *               deploy a new instance of TransparentUpgradeableProxy and repeat the process.
 *         Note: Administrators should take care when configuring flow rate values for tokens.
 *               The configuration should be reviewed from time to time. For example, an
 *               attacker could cheaply trigger the withdrawal queue if one token has a flow rate
 *               configuration (capacity and refill rate) that has a substantially lower value
 *               than other tokens. The attacker could trigger the withdrawal queue, hope that
 *               administrators will reduce the withdrawal delay, to expedite the clearance of
 *               legitimate transactions in the withdrawal queue, and then execute their main
 *               attack, withdrawing a large sum via some other unrelated bridge attack. The
 *               way to protect against this is to have flow rate configurations for all
 *               configured tokens to be for similar amounts and be wary of reducing the withdrawal
 *               delay.
 *               Another consideration is that an attacker could observe pending withdrawals,
 *               and grief a legitimate user's withdrawal. They could do this by withdrawing a
 *               sum, which when combined with the users, is just about the flow rate that will
 *               trigger the withdrawal queue, immediately before the legitimate user. The
 *               legitimate user's withdrawal would then trigger the withdrawal queue. The
 *               mitigation for this is to make the flow rate configurations such that an
 *               attacker would need to invest substantial amounts to attack the system in
 *               this way. This requires monitoring what typical bridge flows are, and
 *               understanding how they change with time.
 */
contract RootERC20BridgeFlowRate is
    RootERC20Bridge,
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

    constructor() RootERC20Bridge() {}

    function initialize(
        InitializationRoles memory newRoles,
        address newRootBridgeAdaptor,
        address newChildERC20Bridge,
        address newChildTokenTemplate,
        address newRootIMXToken,
        address newRootWETHToken,
        uint256 newImxCumulativeDepositLimit,
        address rateAdmin
    ) external initializer {
        if (rateAdmin == address(0)) {
            revert ZeroAddress();
        }

        __RootERC20Bridge_init(
            newRoles,
            newRootBridgeAdaptor,
            newChildERC20Bridge,
            newChildTokenTemplate,
            newRootIMXToken,
            newRootWETHToken,
            newImxCumulativeDepositLimit
        );

        __FlowRateWithdrawalQueue_init();
        _grantRole(RATE_CONTROL_ROLE, rateAdmin);
    }

    // Ensure initialize from RootERC20Bridge can not be called.
    function initialize(InitializationRoles memory, address, address, address, address, address, uint256)
        external
        pure
        override
    {
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
     * @param delay The number of seconds between when the AxelarAdapter is called to
     *         complete a crosschain transfer.
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
        emit RateControlThresholdSet(
            token,
            capacity,
            refillRate,
            largeTransferThreshold,
            previousCapacity,
            previousRefillRate,
            previousLargeTransferThreshold
        );
    }

    /**
     * @notice Complete crosschain transfer of funds.
     * @param data Contains the crosschain transfer information:
     *         - token: Token address on the root chain.
     *         - withdrawer: Account that initiated the transfer on the child chain.
     *         - receiver: Account to transfer tokens to.
     *         - amount: The number of tokens to transfer.
     * @dev Called by the AxelarAdapter.
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
    uint256[50] private __gapRootERC20BridgeFlowRate;
}
