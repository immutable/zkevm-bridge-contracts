// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./FuzzIntegrityChildERC20Bridge.sol";
import "./FuzzIntegrityRootERC20BridgeFlowRate.sol";

/**
 * @title Fuzz
 * @author 0xScourgedev
 * @notice Composite contract for all of the handlers
 */
contract Fuzz is FuzzChildERC20BridgeIntegrity, FuzzRootERC20BridgeFlowRateIntegrity {
    constructor() payable {
        setup();
        setupActors();
    }
}
