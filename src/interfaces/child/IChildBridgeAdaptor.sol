// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

/**
 * @title Child ERC20 Bridge Adaptor Interface
 * @notice Defines the functions that can be used be used by a Child ERC20 Bridge to send messages through an underlying GMP
 * @dev This interface abstracts the details of the underlying General Purpose Message Passing protocol.
 *      This minimizes changes to the interface consumer if the underlying GMP is changed in the future.
 */
interface IChildBridgeAdaptor {
    /**
     * @notice Send an arbitrary message to the root chain via the message passing protocol.
     * @param payload The message to send, encoded in a `bytes` array.
     * @param refundRecipient Used if the message passing protocol requires fees & pays back excess to a refund recipient.
     * @dev The function is `payable` because the message passing protocol may require a fee to be paid.
     */
    function sendMessage(bytes calldata payload, address refundRecipient) external payable;
}
