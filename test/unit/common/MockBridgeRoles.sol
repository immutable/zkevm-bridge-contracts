// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../../src/common/BridgeRoles.sol";

contract MockBridgeRoles is BridgeRoles {
    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }
}
