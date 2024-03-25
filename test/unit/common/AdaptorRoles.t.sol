// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {MockAdaptorRoles} from "./MockAdaptorRoles.sol";

contract Setup is Test {
    address admin = makeAddr("admin");
    address bridgeManager = makeAddr("bridgeManager");
    address gasServiceManager = makeAddr("gasServiceManager");
    address targetManager = makeAddr("targetManager");

    MockAdaptorRoles mockAdaptorRoles;

    function setUp() public {
        mockAdaptorRoles = new MockAdaptorRoles(admin);
    }
}

contract AdaptorRoles is Setup {
    function grantRoles() internal {
        vm.startPrank(admin);
        mockAdaptorRoles.grantBridgeManagerRole(bridgeManager);
        mockAdaptorRoles.grantGasServiceManagerRole(gasServiceManager);
        mockAdaptorRoles.grantTargetManagerRole(targetManager);
        vm.stopPrank();
    }

    function revokeRoles() internal {
        vm.startPrank(admin);
        mockAdaptorRoles.revokeBridgeManagerRole(bridgeManager);
        mockAdaptorRoles.revokeGasServiceManagerRole(gasServiceManager);
        mockAdaptorRoles.revokeTargetManagerRole(targetManager);
        vm.stopPrank();
    }

    function test_grantRoles() public {
        grantRoles();
        assert(mockAdaptorRoles.hasRole(mockAdaptorRoles.BRIDGE_MANAGER_ROLE(), bridgeManager));
        assert(mockAdaptorRoles.hasRole(mockAdaptorRoles.GAS_SERVICE_MANAGER_ROLE(), gasServiceManager));
        assert(mockAdaptorRoles.hasRole(mockAdaptorRoles.TARGET_MANAGER_ROLE(), targetManager));
    }

    function test_revokeRoles() public {
        grantRoles();
        revokeRoles();
        assert(!mockAdaptorRoles.hasRole(mockAdaptorRoles.BRIDGE_MANAGER_ROLE(), bridgeManager));
        assert(!mockAdaptorRoles.hasRole(mockAdaptorRoles.GAS_SERVICE_MANAGER_ROLE(), gasServiceManager));
        assert(!mockAdaptorRoles.hasRole(mockAdaptorRoles.TARGET_MANAGER_ROLE(), targetManager));
    }
}
