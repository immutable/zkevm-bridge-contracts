// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IRootERC20Bridge {
    struct InitializationRoles {
        address defaultAdmin; // The address which will inherit `DEFAULT_ADMIN_ROLE`.
        address pauser; // The address which will inherit `PAUSER_ROLE`.
        address unpauser; // The address which will inherit `UNPAUSER_ROLE`.
        address variableManager; // The address which will inherit `VARIABLE_MANAGER_ROLE`.
        address adaptorManager; // The address which will inherit `ADAPTOR_MANAGER_ROLE`.
    }

    function childBridgeAdaptor() external view returns (string memory);
    /**
     * @notice Receives a bridge message from child chain, parsing the message type then executing.
     * @param sourceChain The chain the message originated from.
     * @param sourceAddress The address the message originated from.
     * @param data The data payload of the message.
     */
    function onMessageReceive(string calldata sourceChain, string calldata sourceAddress, bytes calldata data)
        external;

    /**
     * @notice Initiate sending a mapToken message to the child chain.
     * @notice This is done when a token hasn't been mapped before.
     * @dev Populates a root token => child token mapping on parent chain before
     *      sending a message telling child chain to do the same.
     * @dev The address of the child chain token is deterministic using CREATE2.
     * @param rootToken The address of the token on the root chain.
     * @return childToken The address of the token to be deployed on the child chain.
     */
    function mapToken(IERC20Metadata rootToken) external payable returns (address);

    /**
     * @notice Initiate sending a deposit message to the child chain.
     * @custom:requires `rootToken` to already be mapped with `mapToken`.
     * @param rootToken The address of the token on the root chain.
     * @param amount The amount of tokens to deposit.
     */
    function deposit(IERC20Metadata rootToken, uint256 amount) external payable;
    /**
     * @notice Initiate sending a deposit message to the child chain, with a specified receiver.
     * @custom:requires `rootToken` to already be mapped with `mapToken`.
     * @param rootToken The address of the token on the root chain.
     * @param receiver The address of the receiver on the child chain.
     * @param amount The amount of tokens to deposit.
     */
    function depositTo(IERC20Metadata rootToken, address receiver, uint256 amount) external payable;
}

interface IRootERC20BridgeEvents {
    /// @notice Emitted when the child chain bridge adaptor is updated.
    event NewRootBridgeAdaptor(address oldRootBridgeAdaptor, address newRootBridgeAdaptor);
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
    event IMXDeposit(address indexed rootToken, address depositor, address indexed receiver, uint256 amount);
    event WETHDeposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    event NativeEthDeposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );

    event RootChainERC20Withdraw(
        address indexed rootToken,
        address indexed childToken,
        address withdrawer,
        address indexed receiver,
        uint256 amount
    );
}

interface IRootERC20BridgeErrors {
    /// @notice Error when the caller is not the variable manager role.
    error NotVariableManager();
    /// @notice Error when the amount requested is less than the value sent.
    error InsufficientValue();
    /// @notice Error when there is no gas payment received.
    error ZeroAmount();
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
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
    /// @notice Error when the given child chain bridge adaptor is invalid.
    error InvalidChildERC20BridgeAdaptor();
    /// @notice Error when a message received has invalid data.
    error InvalidData(string reason);
    /// @notice Error when a message received has invalid source address.
    error InvalidSourceAddress();
    /// @notice Error when a message received has invalid source chain.
    error InvalidSourceChain();
    /// @notice Error when caller is not the root bridge adaptor but should be.
    error NotBridgeAdaptor();
    /// @notice Error when the total IMX deposit limit is exceeded
    error ImxDepositLimitExceeded();
    /// @notice Error when the IMX deposit limit is set below the amount of IMX already deposited
    error ImxDepositLimitTooLow();
}
