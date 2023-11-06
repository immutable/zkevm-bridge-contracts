// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

interface IChildAxelarBridgeAdaptorErrors {
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddress();
    /// @notice Error when a message is sent with no gas payment.
    error NoGas();
    /// @notice Error when the caller is not the bridge.
    error CallerNotBridge();
}

interface IChildAxelarBridgeAdaptorEvents {
    /// @notice Emitted when an Axelar message is sent to the root chain.
    event AxelarMessage(string indexed rootChain, string indexed rootBridgeAdaptor, bytes indexed payload);
    /// @notice Emitted when an Axelar message is received from the root chain.
    event AdaptorExecute(string sourceChain, string sourceAddress_, bytes payload_);
}
