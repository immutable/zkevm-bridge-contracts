// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IRootERC20Bridge {
    function childBridgeAdaptor() external view returns (string memory);

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
    /// @notice Emitted when a map token message is sent to the child chain.
    event L1TokenMapped(address indexed rootToken, address indexed childToken);
    /// @notice Emitted when an ERC20 deposit message is sent to the child chain.
    event ERC20Deposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
    event IMXDeposit(address indexed rootToken, address depositor, address indexed receiver, uint256 amount);
    event NativeDeposit(
        address indexed rootToken,
        address indexed childToken,
        address depositor,
        address indexed receiver,
        uint256 amount
    );
}

interface IRootERC20BridgeErrors {
    /// @notice Error when the amount requested is less than the value sent.
    error InsufficientValue();
    /// @notice Error when there is no gas payment received.
    error ZeroAmount();
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
    /// @notice Error when a token is already mapped.
    error AlreadyMapped();
    /// @notice Error when a token is not mapped when it should be.
    error NotMapped();
    /// @notice Error when attempting to map IMX.
    error CantMapIMX();
    /// @notice Error when token balance invariant check fails.
    error BalanceInvariantCheckFailed(uint256 actualBalance, uint256 expectedBalance);
    /// @notice Error when the given child chain bridge adaptor is invalid.
    error InvalidChildERC20BridgeAdaptor();
}
