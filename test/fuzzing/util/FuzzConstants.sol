// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@perimetersec/fuzzlib/src/IHevm.sol";

/**
 * @title FuzzConstants
 * @author 0xScourgedev
 * @notice Constants and assumptions for the fuzzing suite
 */
abstract contract FuzzConstants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         FUZZ CONFIGS                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    address internal constant USER1 = address(0x10001);
    address internal constant USER2 = address(0x20001);
    address internal constant USER3 = address(0x30001);
    address[] internal USERS = [USER1, USER2, USER3];

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         CONSTANTS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 internal constant COVERAGE_GAP = 1000;
    uint256 internal constant MAX_REFILL_RATE_GAP = 3600;
    uint256 internal constant MAX_WITHDRAWAL_DELAY = 1209600; // 2 weeks
    bytes32 internal constant WITHDRAW_SIG = keccak256("WITHDRAW");
    bytes32 internal constant DEPOSIT_SIG = keccak256("DEPOSIT");
    bytes32 internal constant NOTHING_SIG = keccak256("NOTHING");
    address internal constant NATIVE_ETH = address(0xeee);
    address internal constant NATIVE_IMX = address(0xfff);
    uint256 internal constant MAX_IN_QUEUE = 20;
    uint256 internal constant EXECUTE_WHEN_PAUSED_ODDS = 100; // 1% chance of executing when paused

    uint256 internal constant IMX_DEPOSIT_LIMIT = 500_000 ether;
    uint256 internal constant MAX_ERC20_BALANCE = 1_000_000_000; // 1 billion tokens as the max ERC20 balance
    uint256 internal constant INITIAL_BALANCE = 500_000 ether; // 1 Billion USD worth of ETH at $2000/ETH
    uint256 internal constant INITIAL_WETH_BALANCE = 500_000 ether; // 1 Billion USD worth of ETH at $2000/ETH
}
