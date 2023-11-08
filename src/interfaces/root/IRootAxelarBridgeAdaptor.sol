// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.19;

interface IRootAxelarBridgeAdaptorErrors {
    /// @notice Error when a zero address is given when not valid.
    error ZeroAddresses();
    /// @notice Error when a message is to be sent to a child chain that isn't valid.
    error InvalidChildChain();
    /// @notice Error when no gas (in the form of `msg.value`) is given to the transaction to pay for Axelar message passing.
    error NoGas();
    /// @notice Error when the contract calling the adaptor is not the bridge.
    error CallerNotBridge();
}

interface IRootAxelarBridgeAdaptorEvents {
    /// @notice Emitted when an Axelar message is sent to the child chain.
    event AxelarMessageSent(string indexed childChain, string indexed childBridgeAdaptor, bytes indexed payload);
    /// @notice Emitted when an Axelar message is received from the child chain.
    event AdaptorExecute(string sourceChain, string sourceAddress_, bytes payload_);
}
