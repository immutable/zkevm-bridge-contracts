// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {MockBridgeRoles} from "./MockBridgeRoles.sol";

contract Setup is Test {
    address admin = makeAddr("admin");
    address pauser = makeAddr("pauser");
    address unpauser = makeAddr("unpauser");
    address adaptorManager = makeAddr("adaptorManager");

    MockBridgeRoles mockBridgeRoles;

    function setUp() public {
        mockBridgeRoles = new MockBridgeRoles(admin);
    }
}

contract BridgeRoles is Setup {
    function grantRoles() internal {
        vm.startPrank(admin);
        mockBridgeRoles.grantPauserRole(pauser);
        mockBridgeRoles.grantUnpauserRole(unpauser);
        mockBridgeRoles.grantAdaptorManagerRole(adaptorManager);
        vm.stopPrank();
    }

    function revokeRoles() internal {
        vm.startPrank(admin);
        mockBridgeRoles.revokePauserRole(pauser);
        mockBridgeRoles.revokeUnpauserRole(unpauser);
        mockBridgeRoles.revokeAdaptorManagerRole(adaptorManager);
        vm.stopPrank();
    }

    function test_grantRoles() public {
        grantRoles();
        assert(mockBridgeRoles.hasRole(mockBridgeRoles.PAUSER_ROLE(), pauser));
        assert(mockBridgeRoles.hasRole(mockBridgeRoles.UNPAUSER_ROLE(), unpauser));
        assert(mockBridgeRoles.hasRole(mockBridgeRoles.ADAPTOR_MANAGER_ROLE(), adaptorManager));
    }

    function test_revokeRoles() public {
        grantRoles();
        revokeRoles();
        assert(!mockBridgeRoles.hasRole(mockBridgeRoles.PAUSER_ROLE(), pauser));
        assert(!mockBridgeRoles.hasRole(mockBridgeRoles.UNPAUSER_ROLE(), unpauser));
        assert(!mockBridgeRoles.hasRole(mockBridgeRoles.ADAPTOR_MANAGER_ROLE(), adaptorManager));
    }

    function test_pause() public {
        grantRoles();
        vm.prank(pauser);
        mockBridgeRoles.pause();
        assert(mockBridgeRoles.paused());
    }

    function test_unpause() public {
        grantRoles();
        vm.prank(pauser);
        mockBridgeRoles.pause();

        vm.prank(unpauser);
        mockBridgeRoles.unpause();
        assert(!mockBridgeRoles.paused());
    }

    function test_pause_reverts() public {
        bytes32 role = mockBridgeRoles.PAUSER_ROLE();

        // No role
        vm.prank(pauser);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(pauser),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        mockBridgeRoles.pause();

        // Admin role
        vm.startPrank(admin);
        mockBridgeRoles.grantUnpauserRole(pauser);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(admin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        mockBridgeRoles.pause();
        vm.stopPrank();

        // Unpauser role
        vm.prank(unpauser);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(unpauser),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        mockBridgeRoles.pause();
    }

    function test_unpause_reverts() public {
        bytes32 role = mockBridgeRoles.UNPAUSER_ROLE();

        // No role
        vm.prank(unpauser);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(unpauser),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        mockBridgeRoles.unpause();

        // Admin role
        vm.startPrank(admin);
        mockBridgeRoles.grantPauserRole(unpauser);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(admin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        mockBridgeRoles.unpause();
        vm.stopPrank();

        // Pauser role
        vm.prank(unpauser);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(unpauser),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
        mockBridgeRoles.unpause();
    }
}
