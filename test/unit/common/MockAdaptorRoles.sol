// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../../src/common/AdaptorRoles.sol";

contract MockAdaptorRoles is AdaptorRoles {
    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }
}
