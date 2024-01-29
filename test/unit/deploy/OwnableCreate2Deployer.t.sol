// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IDeploy} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IDeploy.sol";
import {IDeployer} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IDeployer.sol";

import {ChildERC20} from "../../../src/child/ChildERC20.sol";
import {OwnableCreate2Deployer} from "../../../src/deploy/OwnableCreate2Deployer.sol";

contract OwnableCreate2DeployerTest is Test {
    OwnableCreate2Deployer private deployer;
    ChildERC20 private childERC20;

    bytes private childERC20Bytecode;
    bytes32 private salt;
    address private owner;

    event Deployed(address indexed deployedAddress, address indexed sender, bytes32 indexed salt, bytes32 bytecodeHash);

    function setUp() public {
        owner = address(0x12345);

        // create a new deployer that is owned by this contract
        deployer = new OwnableCreate2Deployer(owner);

        childERC20 = new ChildERC20();
        childERC20Bytecode = type(ChildERC20).creationCode;

        salt = createSaltFromKey("test-salt");
        vm.startPrank(owner);
    }

    function test_RevertIf_DeployWithEmptyByteCode() public {
        vm.expectRevert(IDeploy.EmptyBytecode.selector);
        deployer.deploy("", salt);
    }

    function test_RevertIf_DeployWithNonOwner() public {
        vm.stopPrank();

        address nonOwner = address(0x1);
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        deployer.deploy(childERC20Bytecode, salt);
    }

    /// @dev deploying with the same bytecode, salt and sender should revert
    function test_RevertIf_DeployAlreadyDeployedCreate2Contract() public {
        deployer.deploy(childERC20Bytecode, salt);

        vm.expectRevert(IDeploy.AlreadyDeployed.selector);
        deployer.deploy(childERC20Bytecode, salt);
    }

    function test_deploy_DeploysContract() public {
        address expectedAddress = predictCreate2Address(childERC20Bytecode, address(deployer), address(owner), salt);

        vm.expectEmit();
        emit Deployed(expectedAddress, address(owner), salt, keccak256(childERC20Bytecode));
        address deployed = deployer.deploy(childERC20Bytecode, salt);

        assertEq(deployed.code, address(childERC20).code, "deployed contract code does not match expected");

        ChildERC20 deployedChildERC20 = ChildERC20(deployed);
        assertEq(deployedChildERC20.name(), "", "deployed contract should have empty name");
        assertEq(deployedChildERC20.symbol(), "", "deployed contract should have empty symbol");
        assertEq(deployedChildERC20.decimals(), 0, "deployed contract should have 0 decimals");
    }

    function test_deploy_DeploysToPredictedAddress() public {
        address deployedAddress = deployer.deploy(childERC20Bytecode, salt);
        address expectedAddress = predictCreate2Address(childERC20Bytecode, address(deployer), address(owner), salt);
        assertEq(deployedAddress, expectedAddress, "deployed address does not match expected address");
    }

    function test_deploy_DeploysSameContractToDifferentAddresses_GivenDifferentSalts() public {
        address deployed1 = deployer.deploy(childERC20Bytecode, salt);

        bytes32 newSalt = createSaltFromKey("new-salt");
        address deployed2 = deployer.deploy(childERC20Bytecode, newSalt);

        assertEq(deployed1.code, deployed2.code, "bytecode of deployed contracts do not match");
        assertNotEq(deployed1, deployed2, "deployed contracts should not have the same address");
    }

    function test_deploy_DeploysContractGivenNewOwner() public {
        address newOwner = address(0x1);

        deployer.transferOwnership(newOwner);
        assertEq(deployer.owner(), newOwner, "owner did not change as expected");

        // check that the old owner cannot deploy
        vm.expectRevert("Ownable: caller is not the owner");
        deployer.deploy(childERC20Bytecode, salt);

        // test that the new owner can deploy
        vm.startPrank(newOwner);
        address expectedAddress = predictCreate2Address(childERC20Bytecode, address(deployer), address(newOwner), salt);

        vm.expectEmit();
        emit Deployed(expectedAddress, address(newOwner), salt, keccak256(childERC20Bytecode));
        address deployed = deployer.deploy(childERC20Bytecode, salt);

        assertEq(deployed.code, address(childERC20).code, "deployed contract should match expected");
    }

    /**
     * deployAndInit
     */
    function test_RevertIf_DeployAndInitWithNonOwner() public {
        vm.stopPrank();

        address nonOwner = address(0x1);
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        deployer.deployAndInit(childERC20Bytecode, salt, "");
    }

    function test_deployAndInit_DeploysAndInitsContract() public {
        address expectedAddress = predictCreate2Address(childERC20Bytecode, address(deployer), address(owner), salt);
        address rootToken = address(0x1);
        string memory name = "Test-Token";
        string memory symbol = "TST";
        uint8 decimals = 18;
        bytes memory initPayload =
            abi.encodeWithSelector(ChildERC20.initialize.selector, rootToken, name, symbol, decimals);

        vm.expectEmit();
        emit Deployed(expectedAddress, address(owner), salt, keccak256(childERC20Bytecode));
        address deployed = deployer.deployAndInit(childERC20Bytecode, salt, initPayload);

        // regardless of init data, the deployed address should match expected deployment
        assertEq(deployed, expectedAddress, "deployed address should match expected address");

        assertEq(deployed.code, address(childERC20).code, "deployed contract should match expected");

        // verify initialisation
        ChildERC20 deployedChildERC20 = ChildERC20(deployed);
        assertEq(deployedChildERC20.rootToken(), rootToken, "rootToken does not match expected");
        assertEq(deployedChildERC20.name(), name, "name does not match expected");
        assertEq(deployedChildERC20.symbol(), symbol, "symbol does not match expected");
        assertEq(deployedChildERC20.decimals(), decimals, "decimals does not match expected");
    }

    /**
     * deployedAddress
     */
    function test_deployedAddress_ReturnsPredictedAddress() public {
        address deployAddress = deployer.deployedAddress(childERC20Bytecode, address(owner), salt);

        address predictedAddress = predictCreate2Address(childERC20Bytecode, address(deployer), address(owner), salt);
        address deployedAddress = deployer.deploy(childERC20Bytecode, salt);

        assertEq(deployAddress, predictedAddress, "deployment address did not match predicted address");
        assertEq(deployAddress, deployedAddress, "deployment address did not match deployed address");
    }

    /**
     * private helper functions
     */
    function predictCreate2Address(bytes memory _bytecode, address _deployer, address _sender, bytes32 _salt)
        private
        pure
        returns (address)
    {
        bytes32 deploySalt = keccak256(abi.encode(_sender, _salt));
        return address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(_deployer), deploySalt, keccak256(_bytecode)))))
        );
    }

    function createSaltFromKey(string memory key) private view returns (bytes32) {
        return keccak256(abi.encode(address(owner), key));
    }
}
