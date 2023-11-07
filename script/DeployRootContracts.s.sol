// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ChildERC20} from "../src/child/ChildERC20.sol";
import {RootERC20Bridge} from "../src/root/RootERC20Bridge.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";
import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {WETH} from "../src/test/root/WETH.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract DeployRootContracts is Script {
    function run() public {
        uint256 rootPrivateKey = vm.envUint("ROOT_PRIVATE_KEY");
        string memory rootRpcUrl = vm.envString("ROOT_RPC_URL");
        string memory deployEnvironment = vm.envString("ENVIRONMENT");
        address rootGateway = vm.envAddress("ROOT_GATEWAY_ADDRESS");

        /**
         * DEPLOY ROOT CHAIN CONTRACTS
         */
        vm.createSelectFork(rootRpcUrl);
        vm.startBroadcast(rootPrivateKey);

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // The ChildERC20 deployment on the root chain.
        ChildERC20 rootChainChildTokenTemplate = new ChildERC20();
        rootChainChildTokenTemplate.initialize(address(123), "TEMPLATE", "TPT", 18);

        RootERC20Bridge rootERC20BridgeImplementation = new RootERC20Bridge();
        rootERC20BridgeImplementation.initialize(
            address(1), address(1), "filler", address(1), address(1), address(1), "filler_child_name", 1
        );
        TransparentUpgradeableProxy rootERC20BridgeProxy = new TransparentUpgradeableProxy(
            address(rootERC20BridgeImplementation),
            address(proxyAdmin),
            ""
        );

        RootAxelarBridgeAdaptor rootBridgeAdaptorImplementation = new RootAxelarBridgeAdaptor(rootGateway);
        rootBridgeAdaptorImplementation.initialize(address(rootERC20BridgeImplementation), "Filler", address(1));

        TransparentUpgradeableProxy rootBridgeAdaptorProxy = new TransparentUpgradeableProxy(
            address(rootBridgeAdaptorImplementation),
            address(proxyAdmin),
            ""
        );

        if (Strings.equal(deployEnvironment, "local")) {
            new WETH();
        }

        vm.stopBroadcast();

        console2.log("====ROOT ADDRESSES====");
        console2.log("ProxyAdmin: %", address(proxyAdmin));
        console2.log("Root ERC20 Bridge Proxy: %s", address(rootERC20BridgeProxy));
        console2.log("Root ERC20 Bridge Implementation: %s", address(rootERC20BridgeImplementation));
        console2.log("Root Axelar Bridge Adaptor Proxy: %s", address(rootBridgeAdaptorProxy));
        console2.log("Root Axelar Bridge Adaptor Implementation: %s", address(rootBridgeAdaptorImplementation));
        console2.log("ROOT CHAIN childTokenTemplate: %s", address(rootChainChildTokenTemplate));
    }
}
