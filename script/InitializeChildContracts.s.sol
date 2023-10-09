// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract InitializeChildContracts is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ChildERC20Bridge childERC20Bridge = ChildERC20Bridge(vm.envAddress("CHILD_ERC20_BRIDGE"));
        ChildAxelarBridgeAdaptor childAxelarBridgeAdaptor = ChildAxelarBridgeAdaptor(vm.envAddress("CHILD_BRIDGE_ADAPTOR"));
        address childTokenTemplate = vm.envAddress("CHILDCHAIN_CHILD_TOKEN_TEMPLATE");
        address rootERC20BridgeAdaptor = vm.envAddress("ROOT_BRIDGE_ADAPTOR");
        string memory childRpcUrl = vm.envString("CHILD_RPC_URL");
        string memory rootChainName = vm.envString("ROOT_CHAIN_NAME");

        /**
         * INITIALIZE CHILD CONTRACTS
         */
        vm.createSelectFork(childRpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        childERC20Bridge.initialize(
            address(childAxelarBridgeAdaptor), 
            Strings.toHexString(rootERC20BridgeAdaptor), 
            childTokenTemplate,
            rootChainName
        );

        childAxelarBridgeAdaptor.setRootBridgeAdaptor();

        vm.stopBroadcast();

    }
}
