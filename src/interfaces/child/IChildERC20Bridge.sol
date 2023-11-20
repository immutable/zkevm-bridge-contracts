// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {IChildERC20} from "./IChildERC20.sol";

/**
 * @title Child ERC20 Bridge Interface
 * @notice Defines the key functions of an ERC20 bridge on the child chain, which enables transfers of bridged ERC20 tokens and native IMX from the child chain to the child chain.
 * @dev Features:
 *  - Withdraw already bridged tokens from the child chain to the root chain.
 *  - Withdraw native IMX from the child chain to the root chain.
 *  - Withdraw wrapped IMX from the child chain to the root chain.
 *  - Withdraw wrapped ETH from the child chain to the root chain.
 */
interface IChildERC20Bridge {
    /**
     * @notice Holds the addresses of accounts that should be assigned different roles in the bridge, during initialization.
     */
    struct InitializationRoles {
        address defaultAdmin; // The address which will inherit `DEFAULT_ADMIN_ROLE`.
        address pauser; // The address which will inherit `PAUSER_ROLE`.
        address unpauser; // The address which will inherit `UNPAUSER_ROLE`.
        address adaptorManager; // The address which will inherit `ADAPTOR_MANAGER_ROLE`.
    }

    /**
     * @notice Get the address of the bridge adaptor on the root chain.
     * @return address of the bridge adaptor on the root chain.
     */
    function rootERC20BridgeAdaptor() external view returns (string memory);

    /**
     * @notice Receives a bridge message from the root chain.
     * @param sourceChain The id of the chain the message originated from.
     * @param sourceAddress The address of the contract on the root chain that sent the message.
     * @param data The data payload of the message.
     * @dev This function is called by the underlying bridge adaptor on the Child chain, when it receives a validated message from the GMP.
     */
    function onMessageReceive(string calldata sourceChain, string calldata sourceAddress, bytes calldata data)
        external;

    /**
     * @notice Sets a new bridge adaptor address to receive and send function calls for L1 messages
     * @param newBridgeAdaptor The new child chain bridge adaptor address.
     */
    function updateChildBridgeAdaptor(address newBridgeAdaptor) external;

    /**
     * @notice Sets a new root chain bridge adaptor address to receive and send function calls for L2 messages
     * @param newRootBridgeAdaptor The new root chain bridge adaptor address.
     */
    function updateRootBridgeAdaptor(string memory newRootBridgeAdaptor) external;

    /**
     * @notice Withdraws `amount` of `childToken` to `msg.sender` on the rootchain.
     * @param childToken The address of the child token to withdraw.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(IChildERC20 childToken, uint256 amount) external payable;

    /**
     * @notice Withdraws `amount` of `childToken` to `receiver` on the rootchain.
     * @param childToken The address of the child token to withdraw.
     * @param receiver The address to withdraw the tokens to.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawTo(IChildERC20 childToken, address receiver, uint256 amount) external payable;

    /**
     * @notice Withdraws `amount` of IMX to `msg.sender` on the rootchain.
     * @param amount The amount of IMX to withdraw.
     */
    function withdrawIMX(uint256 amount) external payable;

    /**
     * @notice Withdraws `amount` of IMX to `receiver` on the rootchain.
     * @param receiver The address to withdraw the IMX to.
     * @param amount The amount of IMX to withdraw.
     */
    function withdrawIMXTo(address receiver, uint256 amount) external payable;

    /**
     * @notice Withdraws `amount` of wrapped IMX to `msg.sender` on the rootchain.
     * @param amount The amount of wrapped IMX to withdraw.
     */
    function withdrawWIMX(uint256 amount) external payable;

    /**
     * @notice Withdraws `amount` of wrapped IMX to `receiver` on the rootchain.
     * @param receiver The address to withdraw the wrapped IMX to.
     * @param amount The amount of wrapped IMX to withdraw.
     */
    function withdrawWIMXTo(address receiver, uint256 amount) external payable;

    /**
     * @notice Withdraws `amount` of ETH to `msg.sender` on the rootchain.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawETH(uint256 amount) external payable;

    /**
     * @notice Withdraws `amount` of ETH to `receiver` on the rootchain.
     * @param receiver The address to withdraw the ETH to.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawETHTo(address receiver, uint256 amount) external payable;
}

/**
 * @title Child ERC20 Bridge Events
 * @notice Defines event types emitted by a Child ERC20 Bridge implementation.
 */
interface IChildERC20BridgeEvents {
    /// @notice Emitted when a map token message is received from the root chain and executed successfully.
    event L2TokenMapped(address rootToken, address childToken);
    /// @notice Emitted when a child chain ERC20 token withdrawal is initiated.
    event ChildChainERC20Withdraw(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    /// @notice Emitted when a child chain native IMX token withdrawal is initiated.
    event ChildChainNativeIMXWithdraw(
        address indexed rootToken, address indexed depositor, address indexed receiver, uint256 amount
    );
    /// @notice Emitted when a child chain wrapped IMX withdrawal is initiated.
    event ChildChainWrappedIMXWithdraw(
        address indexed rootToken, address indexed depositor, address indexed receiver, uint256 amount
    );
    /// @notice Emitted when a child chain ETH withdrawal is initiated.
    event ChildChainEthWithdraw(address indexed depositor, address indexed receiver, uint256 amount);
    /// @notice Emitted when a root chain ERC20 deposit is completed on the child chain.
    event ChildChainERC20Deposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    /// @notice Emitted when a root chain IMX deposit is completed on the child chain.
    event IMXDeposit(address indexed rootToken, address indexed depositor, address indexed receiver, uint256 amount);
    /// @notice Emitted when a root chain ETH deposit is completed on the child chain.
    event NativeEthDeposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    /// @notice Emitted when the child chain bridge adaptor is updated.
    event ChildBridgeAdaptorUpdated(address oldChildBridgeAdaptor, address newChildBridgeAdaptor);
    /// @notice Emitted when the root chain bridge adaptor is updated.
    event RootBridgeAdaptorUpdated(string oldRootBridgeAdaptor, string newRootBridgeAdaptor);
}

/**
 * @notice Child ERC20 Bridge Errors
 * @notice Defines error types emitted by a Child ERC20 Bridge implementation.
 */
interface IChildERC20BridgeErrors {
    /// @notice Error when the amount requested is less than the value sent.
    error InsufficientValue();
    /// @notice Error when the withdrawal amount is zero
    error ZeroAmount();
    /// @notice Error when a message is sent with no gas payment.
    error NoGas();
    /// @notice Error when the contract to mint had no bytecode.
    error EmptyTokenContract();
    /// @notice Error when the mint operation failed.
    error MintFailed();
    /// @notice Error when the given root chain name is invalid.
    error InvalidRootChain();
    /// @notice Error when the given bridge adaptor is invalid.
    error InvalidRootERC20BridgeAdaptor();
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
    /// @notice Error when a token is not mapped.
    error NotMapped();
    /// @notice Error when attempting to map IMX.
    error CantMapIMX();
    /// @notice Error when attempting to map ETH.
    error CantMapETH();
    /// @notice Error when a token is already mapped.
    error AlreadyMapped();
    /// @notice Error when a message is given to the bridge from an address not the designated bridge adaptor.
    error NotBridgeAdaptor();
    /// @notice Error when the message's payload is not valid.
    error InvalidData(string reason);
    /// @notice Error when the message's source chain is not valid.
    error InvalidSourceChain();
    /// @notice Error when the source chain's message sender is not a recognised address.
    error InvalidSourceAddress();
    /// @notice Error when a given child token's root token is the zero address.
    error ZeroAddressRootToken();
    /// @notice Error when a given child token's bridge address is not set.
    error BridgeNotSet();
    /// @notice Error when a given child token's bridge address is incorrect.
    error IncorrectBridgeAddress();
    /// @notice Error when a call to the given child token's `burn` function fails.
    error BurnFailed();
    /// @notice Error when a call to WIMX token's `transferFrom` fails.
    error TransferWIMXFailed();
    /// @notice Error when token balance invariant check fails.
    error BalanceInvariantCheckFailed(uint256 actualBalance, uint256 expectedBalance);
    /// @notice Error when native transfer is sent to contract from non wrapped-token address.
    error NonWrappedNativeTransfer();
}
