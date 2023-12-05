// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import {Deployer} from "@axelar-gmp-sdk-solidity/contracts/deploy/Deployer.sol";
import {Create2} from "@axelar-gmp-sdk-solidity/contracts/deploy/Create2.sol";

/**
 * @title OwnableCreate2Deployer
 * @notice Deploys and optionally initializes contracts using the `CREATE2` opcode.
 * @dev This contract extends the {Deployer} contract from the Axelar SDK, by adding basic access control to the deployment functions.
 *      The contract has an owner, which is the only entity that can deploy new contracts.
 *      The owner is initially set to the deployer of this contract and can be changed using {transferOwnership}.
 *
 * @dev The contract deploys a contract with the same bytecode, salt, and sender(owner) to the same address.
 *      Attempting to deploy a contract with the same bytecode, salt, and sender(owner) will revert.
 *      The address where the contract will be deployed can be found using {deployedAddress}.
 */
contract OwnableCreate2Deployer is Ownable, Create2, Deployer {
    constructor() Ownable() {}

    /**
     * @dev Deploys a contract using the `CREATE2` opcode.
     *      This function is called by {deploy} and {deployAndInit} external functions in the {Deployer} contract.
     *      This function can only be called by the owner of this contract, hence {deploy} and {deployAndInit} can only be called by the owner.
     *      The address where the contract will be deployed can be found using {deployedAddress}.
     * @param bytecode The bytecode of the contract to be deployed
     * @param deploySalt A salt which is a hash of the salt provided by the sender and the sender's address.
     * @return The address of the deployed contract
     */
    function _deploy(bytes memory bytecode, bytes32 deploySalt) internal override onlyOwner returns (address) {
        return _create2(bytecode, deploySalt);
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} or {deployAndInit}.
     *      This function is called by the {deployedAddress} external functions in the {Deployer} contract.
     * @param bytecode The bytecode of the contract to be deployed
     * @param deploySalt A salt which is a hash of the salt provided by the sender and the sender's address.
     * @return The predicted deployment address of the contract
     */
    function _deployedAddress(bytes memory bytecode, bytes32 deploySalt) internal view override returns (address) {
        return _create2Address(bytecode, deploySalt);
    }
}
