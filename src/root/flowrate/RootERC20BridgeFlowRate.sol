// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./FlowRateDetection.sol";
import "./FlowRateWithdrawalQueue.sol";
import "../RootERC20Bridge.sol";

import {IRootERC20BridgeFlowRateEvents, IRootERC20BridgeFlowRateErrors} from "../../interfaces/root/flowrate/IRootERC20BridgeFlowRate.sol";

contract RootERC20BridgeFlowRate is 
    RootERC20Bridge,
    AccessControlUpgradeable,
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
        address newRootBridgeAdaptor, 
        address newChildERC20Bridge, 
        string memory newChildBridgeAdaptor, 
        address newChildTokenTemplate, 
        address newRootIMXToken, 
        address newRootWETHToken, 
        string memory newChildChain, 
        address newImxCumulativeDepositLimit,
        address rateAdmin
        ) external initializer {

        __RootERC20Bridge_init(
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

        _grantRole(RATE_CONTROL_ROLE, rateAdmin);
    }

     // Ensure initialize from RootERC20Predicate can not be called.
    function initialize(address, address, string memory, address, address, address, string memory, uint256) external pure override {
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
        _setFlowRateThreshold(token, capacity, refillRate);
        largeTransferThresholds[token] = largeTransferThreshold;
        emit RateControlThresholdSet(token, capacity, refillRate, largeTransferThreshold);
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
    function _withdraw(bytes calldata data) internal override {
        (address rootToken, address withdrawer, address receiver, uint256 amount) =
            abi.decode(data, (address, address, address, uint256));
        address childToken = rootTokenToChildToken[rootToken];
        if (childToken == address(0)) {
            revert NotMapped();
        }

        _executeTransfer(rootToken, childToken, withdrawer, receiver, amount);
    }
 
}