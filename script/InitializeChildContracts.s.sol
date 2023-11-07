// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";

import {ChildERC20Bridge, IChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {Utils} from "./Utils.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

struct InitializeChildContractsParams {
    address childAdminAddress;
    address childPauserAddress;
    address childUnpauserAddress;
    ChildERC20Bridge childERC20Bridge;
    ChildAxelarBridgeAdaptor childAxelarBridgeAdaptor;
    address childTokenTemplate;
    address rootERC20BridgeAdaptor;
    string rootChainName;
    address rootIMXToken;
    string childRpcUrl;
    uint256 deployerPrivateKey;
    address childGasService;
}

contract InitializeChildContracts is Script {
    function run() public {
        InitializeChildContractsParams memory params = InitializeChildContractsParams({
            childAdminAddress: vm.envAddress("CHILD_ADMIN_ADDRESS"),
            childPauserAddress: vm.envAddress("CHILD_PAUSER_ADDRESS"),
            childUnpauserAddress: vm.envAddress("CHILD_UNPAUSER_ADDRESS"),
            childERC20Bridge: ChildERC20Bridge(vm.envAddress("CHILD_ERC20_BRIDGE")),
            childAxelarBridgeAdaptor: ChildAxelarBridgeAdaptor(vm.envAddress("CHILD_BRIDGE_ADAPTOR")),
            childTokenTemplate: vm.envAddress("CHILDCHAIN_CHILD_TOKEN_TEMPLATE"),
        rootERC20BridgeAdaptor:  vm.envAddress("ROOT_BRIDGE_ADAPTOR"),
            rootChainName: vm.envString("ROOT_CHAIN_NAME"),
            rootIMXToken: vm.envAddress("ROOT_IMX_ADDRESS"),
            childRpcUrl: vm.envString("CHILD_RPC_URL"),
            deployerPrivateKey: vm.envUint("CHILD_PRIVATE_KEY"),
            childGasService: vm.envAddress("CHILD_GAS_SERVICE_ADDRESS")
        });

        /**
         * INITIALIZE CHILD CONTRACTS
         */
        string[] memory checksumInputs = Utils.getChecksumInputs(params.rootERC20BridgeAdaptor);
        bytes memory checksumOutput = vm.ffi(checksumInputs);
        string memory rootBridgeAdaptorString = string(Utils.removeZeroByteValues(checksumOutput));

        vm.createSelectFork(params.childRpcUrl);
        vm.startBroadcast(params.deployerPrivateKey);

        // TODO update
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: params.childAdminAddress,
            pauser: params.childPauserAddress,
            unpauser: params.childUnpauserAddress,
            variableManager: params.childAdminAddress,
            adaptorManager: params.childAdminAddress
        });
        params.childERC20Bridge.initialize(
            roles,
            address(params.childAxelarBridgeAdaptor),
            rootBridgeAdaptorString,
            params.childTokenTemplate,
            params.rootChainName,
            params.rootIMXToken
        );

        params.childAxelarBridgeAdaptor.initialize(params.rootChainName, address(params.childERC20Bridge), params.childGasService);

        vm.stopBroadcast();
    }
}
