// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";

import {ChildERC20} from "../src/child/ChildERC20.sol";
import {RootERC20Bridge} from "../src/root/RootERC20Bridge.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";
import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract DeployRootContracts is Script {
    function setUp() public {}

    function run() public {
        uint256 rootPrivateKey = vm.envUint("ROOT_PRIVATE_KEY");
        string memory rootRpcUrl = vm.envString("ROOT_RPC_URL");
        address rootGateway = vm.envAddress("ROOT_GATEWAY_ADDRESS");
        address rootGasService = vm.envAddress("ROOT_GAS_SERVICE_ADDRESS");
        string memory childChainName = vm.envString("CHILD_CHAIN_NAME");

        /**
         * DEPLOY ROOT CHAIN CONTRACTS
         */
        vm.createSelectFork(rootRpcUrl);
        vm.startBroadcast(rootPrivateKey);

        // The ChildERC20 deployment on the root chain.
        ChildERC20 rootChainChildTokenTemplate = new ChildERC20();
        rootChainChildTokenTemplate.initialize(address(123), "TEMPLATE", "TPT", 18);

        RootERC20Bridge rootERC20Bridge = new RootERC20Bridge();

        RootAxelarBridgeAdaptor rootBridgeAdaptor = new RootAxelarBridgeAdaptor(
            address(rootERC20Bridge), // root bridge
            childChainName, // child chain name
            rootGateway, // axelar gateway
            rootGasService // axelar gas service
        );

        console2.log("====ROOT ADDRESSES====");
        console2.log("Root ERC20 Bridge: %s", address(rootERC20Bridge));
        console2.log("Root Axelar Bridge Adaptor: %s", address(rootBridgeAdaptor));
        console2.log("ROOT CHAIN childTokenTemplate: %s", address(rootChainChildTokenTemplate));
    }
}
