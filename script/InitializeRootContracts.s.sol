// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";

import {ChildERC20} from "../src/child/ChildERC20.sol";
import {RootERC20Bridge} from "../src/root/RootERC20Bridge.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";
import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {AddressToString} from "@axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {Utils} from "./Utils.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract InitializeRootContracts is Script {
    function run() public {
        RootERC20Bridge rootERC20Bridge = RootERC20Bridge(vm.envAddress("ROOT_ERC20_BRIDGE"));
        RootAxelarBridgeAdaptor rootBridgeAdaptor = RootAxelarBridgeAdaptor(vm.envAddress("ROOT_BRIDGE_ADAPTOR"));
        address rootChainChildTokenTemplate = vm.envAddress("ROOTCHAIN_CHILD_TOKEN_TEMPLATE");
        address childBridgeAdaptor = vm.envAddress("CHILD_BRIDGE_ADAPTOR");
        address childERC20Bridge = vm.envAddress("CHILD_ERC20_BRIDGE");
        string memory rootRpcUrl = vm.envString("ROOT_RPC_URL");
        uint256 rootPrivateKey = vm.envUint("ROOT_PRIVATE_KEY");
        address rootIMXToken = vm.envAddress("ROOT_IMX_ADDRESS");

        string[] memory checksumInputs = Utils.getChecksumInputs(childBridgeAdaptor);
        bytes memory checksumOutput = vm.ffi(checksumInputs);
        string memory childBridgeAdaptorChecksum = string(Utils.removeZeroByteValues(checksumOutput));
        /**
         * INITIALIZE ROOT CHAIN CONTRACTS
         */
        vm.createSelectFork(rootRpcUrl);
        vm.startBroadcast(rootPrivateKey);

        rootERC20Bridge.initialize(
            address(rootBridgeAdaptor),
            childERC20Bridge,
            childBridgeAdaptorChecksum,
            rootChainChildTokenTemplate,
            rootIMXToken
        );

        rootBridgeAdaptor.setChildBridgeAdaptor();

        vm.stopBroadcast();
        console2.log(rootERC20Bridge.childBridgeAdaptor());
    }
}
