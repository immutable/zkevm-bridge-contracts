// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

interface IChildERC20BridgeAdaptor {
    /**
     * @notice Send an arbitrary message to the root chain via the message passing protocol.
     * @param payload The message to send, encoded in a `bytes` array.
     * @param refundRecipient Used if the message passing protocol requires fees & pays back excess to a refund recipient.
     * @dev `payable` because the message passing protocol may require a fee to be paid.
     */
    function sendMessage(bytes calldata payload, address refundRecipient) external payable;
}
