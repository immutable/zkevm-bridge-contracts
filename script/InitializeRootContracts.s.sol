// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {ChildERC20} from "../src/child/ChildERC20.sol";
import {RootERC20Bridge, IRootERC20Bridge} from "../src/root/RootERC20Bridge.sol";
import {IRootAxelarBridgeAdaptor} from "../src/interfaces/root/IRootAxelarBridgeAdaptor.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";
import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {AddressToString} from "@axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {Utils} from "./Utils.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

struct InitializeRootContractsParams {
    address rootAdminAddress;
    address rootPauserAddress;
    address rootUnpauserAddress;
    address rootBridgeManagerAddress;
    address rootGasManagerAddress;
    address rootTargetManagerAddress;
    RootERC20Bridge rootERC20Bridge;
    RootAxelarBridgeAdaptor rootBridgeAdaptor;
    address rootChainChildTokenTemplate;
    address childBridgeAdaptor;
    address childERC20Bridge;
    string rootRpcUrl;
    uint256 rootPrivateKey;
    address rootIMXToken;
    address rootWETHToken;
    string childChainName;
    address rootGasService;
    uint256 initialIMXCumulativeDepositLimit;
}

contract InitializeRootContracts is Script {
    function run() public {
        InitializeRootContractsParams memory params = InitializeRootContractsParams({
            rootAdminAddress: vm.envAddress("ROOT_ADMIN_ADDRESS"),
            rootPauserAddress: vm.envAddress("ROOT_PAUSER_ADDRESS"),
            rootUnpauserAddress: vm.envAddress("ROOT_UNPAUSER_ADDRESS"),
            rootBridgeManagerAddress: vm.envAddress("ROOT_BRIDGE_MANAGER_ADDRESS"),
            rootGasManagerAddress: vm.envAddress("ROOT_GAS_MANAGER_ADDRESS"),
            rootTargetManagerAddress: vm.envAddress("ROOT_TARGET_MANAGER_ADDRESS"),
            rootERC20Bridge: RootERC20Bridge(payable(vm.envAddress("ROOT_ERC20_BRIDGE"))),
            rootBridgeAdaptor: RootAxelarBridgeAdaptor(vm.envAddress("ROOT_BRIDGE_ADAPTOR")),
            rootChainChildTokenTemplate: vm.envAddress("ROOTCHAIN_CHILD_TOKEN_TEMPLATE"),
            childBridgeAdaptor: vm.envAddress("CHILD_BRIDGE_ADAPTOR"),
            childERC20Bridge: vm.envAddress("CHILD_ERC20_BRIDGE"),
            rootRpcUrl: vm.envString("ROOT_RPC_URL"),
            rootPrivateKey: vm.envUint("ROOT_PRIVATE_KEY"),
            rootIMXToken: vm.envAddress("ROOT_IMX_ADDRESS"),
            rootWETHToken: vm.envAddress("ROOT_WETH_ADDRESS"),
            childChainName: vm.envString("CHILD_CHAIN_NAME"),
            rootGasService: vm.envAddress("ROOT_GAS_SERVICE_ADDRESS"),
            initialIMXCumulativeDepositLimit: vm.envUint("INITIAL_IMX_CUMULATIVE_DEPOSIT_LIMIT")
        });

        string[] memory checksumInputs = Utils.getChecksumInputs(params.childBridgeAdaptor);
        bytes memory checksumOutput = vm.ffi(checksumInputs);
        string memory childBridgeAdaptorChecksum = string(Utils.removeZeroByteValues(checksumOutput));
        /**
         * INITIALIZE ROOT CHAIN CONTRACTS
         */
        vm.createSelectFork(params.rootRpcUrl);
        vm.startBroadcast(params.rootPrivateKey);

        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: params.rootAdminAddress,
            pauser: params.rootPauserAddress,
            unpauser: params.rootUnpauserAddress,
            variableManager: params.rootAdminAddress,
            adaptorManager: params.rootAdminAddress
        });

        params.rootERC20Bridge.initialize(
            roles,
            address(params.rootBridgeAdaptor),
            params.childERC20Bridge,
            childBridgeAdaptorChecksum,
            params.rootChainChildTokenTemplate,
            params.rootIMXToken,
            params.rootWETHToken,
            params.childChainName,
            params.initialIMXCumulativeDepositLimit
        );

        IRootAxelarBridgeAdaptor.InitializationRoles memory adaptorRoles = IRootAxelarBridgeAdaptor.InitializationRoles({
            defaultAdmin: params.rootAdminAddress,
            bridgeManager: params.rootBridgeManagerAddress,
            gasServiceManager: params.rootGasManagerAddress,
            targetManager: params.rootTargetManagerAddress
        });

        params.rootBridgeAdaptor.initialize(
            adaptorRoles,
            address(params.rootERC20Bridge), // root bridge
            params.childChainName, // child chain name
            params.rootGasService // axelar gas service
        );

        vm.stopBroadcast();
    }
}
