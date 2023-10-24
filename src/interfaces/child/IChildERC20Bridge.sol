// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IChildERC20Bridge {
    function rootERC20BridgeAdaptor() external view returns (string memory);
    /**
     * @notice Receives a bridge message from root chain, parsing the message type then executing.
     * @param sourceChain The chain the message originated from.
     * @param sourceAddress The address the message originated from.
     * @param data The data payload of the message.
     */
    function onMessageReceive(string calldata sourceChain, string calldata sourceAddress, bytes calldata data)
        external;

    /**
     * @notice Sets a new bridge adaptor address to receive and send function calls for L1 messages
     * @param newBridgeAdaptor The new child chain bridge adaptor address.
     */
    function updateBridgeAdaptor(address newBridgeAdaptor) external;
}

interface IChildERC20BridgeEvents {
    /// @notice Emitted when a map token message is received from the root chain and executed successfully.
    event L2TokenMapped(address rootToken, address childToken);

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

// TODO add parameters to errors if it makes sense
interface IChildERC20BridgeErrors {
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
    /// @notice Error when a token is already mapped.
    error AlreadyMapped();
    /// @notice Error when a message is given to the bridge from an address not the designated bridge adaptor.
    error NotBridgeAdaptor();
    /// @notice Error when the message's payload is not valid.
    error InvalidData();
    /// @notice Error when the message's source chain is not valid.
    error InvalidSourceChain();
    /// @notice Error when the source chain's message sender is not a recognised address.
    error InvalidSourceAddress();
}
