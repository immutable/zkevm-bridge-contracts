// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;
/**
 * @title Child Bridge Adaptor Errors
 * @notice Contains the different error types that can be thrown by a bridge adaptor
 */
interface IChildAxelarBridgeAdaptorErrors {
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
    /// @notice Error when a message is sent with no gas payment.
    error NoGas();
    /// @notice Error when the caller is not the bridge.
    error CallerNotBridge();
}

/**
 * @title Child Bridge Adaptor Events
 * @notice Contains the event types that can be emitted by a bridge adaptor
 */
interface IChildAxelarBridgeAdaptorEvents {
    /// @notice Emitted when an Axelar message is sent to the root chain.
    event AxelarMessageSent(string indexed rootChain, string indexed rootBridgeAdaptor, bytes indexed payload);
    /// @notice Emitted when an Axelar message is received from the root chain.
    event AdaptorExecute(string sourceChain, string sourceAddress_, bytes payload_);
}
