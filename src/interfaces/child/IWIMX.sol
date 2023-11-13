// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of Wrapped IMX.
 */
interface IWIMX is IERC20 {
    /**
     * @dev Emitted when `value` native IMX are deposited from `account`.
     */
    event Deposit(address indexed account, uint256 value);

    /**
     * @dev Emitted when `value` wIMX tokens are withdrawn to `account`.
     */
    event Withdrawal(address indexed account, uint256 value);

    /**
     * @notice Deposit native IMX in the function call and mint the equal amount of wrapped IMX to msg.sender.
     */
    function deposit() external payable;

    /**
     * @notice Withdraw given amount of native IMX to msg.sender and burn the equal amount of wrapped IMX.
     * @param value The amount to withdraw.
     */
    function withdraw(uint256 value) external;
}
