// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Root ERC20 Bridge Interface
 * @notice Defines the key functions of an ERC20 bridge on the root chain, which enables bridging of standard ERC20 tokens, ETH, wETH, IMX and wIMX from the root chain to the child chain and back.
 * @dev Features:
 *     - Maps tokens from the root chain to the child chain.
 *     - Deposits tokens from the root chain to the child chain.
 *     - Deposits native ETH from the root chain to the child chain.
 */
interface IRootERC20Bridge {
    /**
     * @notice Holds the addresses of accounts that should be assigned different roles in the bridge, during initialization.
     */
    struct InitializationRoles {
        address defaultAdmin; // The address which will inherit `DEFAULT_ADMIN_ROLE`.
        address pauser; // The address which will inherit `PAUSER_ROLE`.
        address unpauser; // The address which will inherit `UNPAUSER_ROLE`.
        address variableManager; // The address which will inherit `VARIABLE_MANAGER_ROLE`.
        address adaptorManager; // The address which will inherit `ADAPTOR_MANAGER_ROLE`.
    }

    /**
     * @notice Function to revoke `VARIABLE_MANAGER_ROLE` role from an address
     */
    function revokeVariableManagerRole(address account) external;

    /**
     * @notice Function to grant `VARIABLE_MANAGER_ROLE` role to an address
     */
    function grantVariableManagerRole(address account) external;

    /**
     * @notice Updates the root bridge adaptor.
     * @param newRootBridgeAdaptor Address of new root bridge adaptor.
     * @dev Can only be called by ADAPTOR_MANAGER_ROLE.
     */
    function updateRootBridgeAdaptor(address newRootBridgeAdaptor) external;

    /**
     * @notice Receives a bridge message from the child chain.
     * @param data The data payload of the message.
     * @dev This function is called by the underlying bridge adaptor on the root chain, when it receives a validated message from the GMP.
     *         It assumes that the underlying adaptor has already validated the sender chain and sender address.
     */
    function onMessageReceive(bytes calldata data) external;

    /**
     * @notice Initiates sending a mapToken message to the child chain, if the token hasn't been mapped before.
     *         This operation requires the `rootToken` to have the following public getter functions: `name()`, `symbol()`, and `decimals()`.
     *         These functions are optional in the ERC20 standard. If the token does not provide these functions,
     *         the mapping operation will fail and return a `TokenNotSupported` error.
     *
     * @dev The function:
     *      - fails with a `AlreadyMapped` error if the token has already been mapped.
     *      - populates a root token => child token mapping on the root chain before
     *        sending a message telling the child chain to do the same.
     *      - is `payable` because the message passing protocol requires a fee to be paid.
     *
     * @dev The address of the child chain token is deterministic using CREATE2.
     *
     * @param rootToken The address of the token on the root chain.
     * @return childToken The address of the token to be deployed on the child chain.
     */
    function mapToken(IERC20Metadata rootToken) external payable returns (address);

    /**
     * @notice Deposit tokens to the bridge and issue corresponding tokens to `msg.sender` on the child chain.
     * @custom:requires `rootToken` should already have been mapped with `mapToken()`.
     * @param rootToken The address of the token on the root chain.
     * @param amount The amount of tokens to deposit.
     * @dev The function is `payable` because the message passing protocol requires a fee to be paid.
     */
    function deposit(IERC20Metadata rootToken, uint256 amount) external payable;

    /**
     * @notice Deposit tokens to the bridge and issue corresponding tokens to `receiver` address on the child chain.
     * @custom:requires `rootToken` should already have been mapped with `mapToken()`.
     * @param rootToken The address of the token on the root chain.
     * @param receiver The address of the receiver on the child chain, to credit tokens to.
     * @param amount The amount of tokens to deposit.
     * @dev The function is `payable` because the message passing protocol requires a fee to be paid.
     */
    function depositTo(IERC20Metadata rootToken, address receiver, uint256 amount) external payable;

    /**
     * @notice Deposit ETH to the bridge and issue corresponding wrapped ETH to `msg.sender` on the child chain.
     * @param amount The amount of tokens to deposit.
     * @dev The function is `payable` because the message passing protocol requires a fee to be paid.
     * @dev the `msg.value` provided should cover the amount to send as well as the bridge fee.
     */
    function depositETH(uint256 amount) external payable;
    /**
     * @notice Deposit ETH to the bridge and issue corresponding wrapped ETH to `receiver` address on the child chain.
     * @param receiver The address of the receiver on the child chain.
     * @param amount The amount of tokens to deposit.
     * @dev The function is `payable` because the message passing protocol requires a fee to be paid.
     * @dev the `msg.value` provided should cover the amount to send as well as the bridge fee.
     */
    function depositToETH(address receiver, uint256 amount) external payable;
}

/**
 * @title Root ERC20 Bridge Events
 * @notice Defines event types emitted by a Root ERC20 Bridge implementation.
 */
interface IRootERC20BridgeEvents {
    /// @notice Emitted when the root chain bridge adaptor is updated.
    event RootBridgeAdaptorUpdated(address oldRootBridgeAdaptor, address newRootBridgeAdaptor);
    /// @notice Emitted when the IMX deposit limit is updated.
    event NewImxDepositLimit(uint256 oldImxDepositLimit, uint256 newImxDepositLimit);
    /// @notice Emitted when a map token message is sent to the child chain.
    event L1TokenMapped(address indexed rootToken, address indexed childToken);
    /// @notice Emitted when an ERC20 deposit message is sent to the child chain.
    event ChildChainERC20Deposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    /// @notice Emitted when an IMX deposit is initated on the root chain.
    event IMXDeposit(address indexed rootToken, address depositor, address indexed receiver, uint256 amount);
    /// @notice Emitted when a WETH deposit is initiated on the root chain.
    event WETHDeposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    /// @notice Emitted when an ETH deposit initiated on the root chain.
    event NativeEthDeposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    /// @notice Emitted when an ERC20 withdrawal is executed on the root chain.
    event RootChainERC20Withdraw(
        address indexed rootToken,
        address indexed childToken,
        address withdrawer,
        address indexed receiver,
        uint256 amount
    );
    /// @notice Emitted when an ETH withdrawal is executed on the root chain.
    event RootChainETHWithdraw(
        address indexed rootToken,
        address indexed childToken,
        address withdrawer,
        address indexed receiver,
        uint256 amount
    );
}

/**
 * @notice Root ERC20 Bridge Errors
 * @notice Defines error types emitted by a Root ERC20 Bridge implementation.
 */
interface IRootERC20BridgeErrors {
    /// @notice Error when the amount requested is less than the value sent.
    error InsufficientValue();
    /// @notice Error when there is no gas payment received.
    error ZeroAmount();
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
    /// @notice Error when a message is sent with no gas payment.
    error NoGas();
    /// @notice Error when the child chain name is invalid.
    error InvalidChildChain();
    /// @notice Error when a token is already mapped.
    error AlreadyMapped();
    /// @notice Error when a token is not mapped when it should be.
    error NotMapped();
    /// @notice Error when attempting to map IMX.
    error CantMapIMX();
    /// @notice Error when attempting to map ETH.
    error CantMapETH();
    /// @notice Error when attempting to map wETH.
    error CantMapWETH();
    /// @notice Error when token balance invariant check fails.
    error BalanceInvariantCheckFailed(uint256 actualBalance, uint256 expectedBalance);
    /// @notice Error when a message received has invalid data.
    error InvalidData(string reason);
    /// @notice Error when caller is not the root bridge adaptor but should be.
    error NotBridgeAdaptor();
    /// @notice Error when the total IMX deposit limit is exceeded
    error ImxDepositLimitExceeded();
    /// @notice Error when the IMX deposit limit is set below the amount of IMX already deposited
    error ImxDepositLimitTooLow();
    /// @notice Error when native transfer is sent to contract from non wrapped-token address.
    error NonWrappedNativeTransfer();
    /// @notice Error when the an unauthorized initializer tries to initialize the contract.
    error UnauthorizedInitializer();
    /// @notice Error when attempt to map a ERC20 token that doesn't support name(), symbol() or decimals().
    error TokenNotSupported();
}
