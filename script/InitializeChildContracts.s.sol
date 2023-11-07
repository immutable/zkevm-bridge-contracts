// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";

import {ChildERC20Bridge, IChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {Utils} from "./Utils.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract InitializeChildContracts is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("CHILD_PRIVATE_KEY");
        ChildERC20Bridge childERC20Bridge = ChildERC20Bridge(vm.envAddress("CHILD_ERC20_BRIDGE"));
        ChildAxelarBridgeAdaptor childAxelarBridgeAdaptor =
            ChildAxelarBridgeAdaptor(vm.envAddress("CHILD_BRIDGE_ADAPTOR"));
        address childTokenTemplate = vm.envAddress("CHILDCHAIN_CHILD_TOKEN_TEMPLATE");
        address rootERC20BridgeAdaptor = vm.envAddress("ROOT_BRIDGE_ADAPTOR");
        string memory childRpcUrl = vm.envString("CHILD_RPC_URL");
        string memory rootChainName = vm.envString("ROOT_CHAIN_NAME");
        address rootIMXToken = vm.envAddress("ROOT_IMX_ADDRESS");
        address childGasService = vm.envAddress("CHILD_GAS_SERVICE_ADDRESS"); // Not yet used.

        /**
         * INITIALIZE CHILD CONTRACTS
         */
        string[] memory checksumInputs = Utils.getChecksumInputs(rootERC20BridgeAdaptor);
        bytes memory checksumOutput = vm.ffi(checksumInputs);
        string memory rootBridgeAdaptorString = string(Utils.removeZeroByteValues(checksumOutput));

        vm.createSelectFork(childRpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        // TODO update
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(1),
            pauser: address(2),
            unpauser: address(3),
            variableManager: address(4),
            adaptorManager: address(5)
        });
        childERC20Bridge.initialize(
            roles,
            address(childAxelarBridgeAdaptor),
            rootBridgeAdaptorString,
            childTokenTemplate,
            rootChainName,
            rootIMXToken
        );

        childAxelarBridgeAdaptor.initialize(rootChainName, address(childERC20Bridge), childGasService);

        vm.stopBroadcast();
    }
}
