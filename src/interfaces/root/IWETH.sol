// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of Wrapped ETH.
 */
interface IWETH is IERC20 {
    /**
     * @dev Emitted when `value` native ETH are deposited from `account`.
     */
    event Deposit(address indexed account, uint256 value);

    /**
     * @dev Emitted when `value` wETH tokens are withdrawn to `account`.
     */
    event Withdrawal(address indexed account, uint256 value);

    /**
     * @notice Deposit native ETH in the function call and mint the equal amount of wrapped ETH to msg.sender.
     */
    function deposit() external payable;

    /**
     * @notice Withdraw given amount of native ETH to msg.sender and burn the equal amount of wrapped ETH.
     * @param value The amount to withdraw.
     */
    function withdraw(uint256 value) external;
}
