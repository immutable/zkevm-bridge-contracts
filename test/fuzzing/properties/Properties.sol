// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Properties_RTREV.sol";
import "./Properties_FLRT.sol";
import "./Properties_PAUSE.sol";
import "./Properties_CLDREV.sol";
import "./Properties_SPLY.sol";
import "./Properties_BAL.sol";

/**
 * @title Properties
 * @author 0xScourgedev
 * @notice Composite contract for all of the properties, and contains general invariants
 */
abstract contract Properties is
    Properties_RTREV,
    Properties_FLRT,
    Properties_PAUSE,
    Properties_CLDREV,
    Properties_SPLY,
    Properties_BAL
{}
