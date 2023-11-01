// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {ChildERC20} from "../src/child/ChildERC20.sol";
import {WIMX} from "../src/child/WIMX.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract DeployChildContracts is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("CHILD_PRIVATE_KEY");
        address childGateway = vm.envAddress("CHILD_GATEWAY_ADDRESS");
        string memory childRpcUrl = vm.envString("CHILD_RPC_URL");

        vm.createSelectFork(childRpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        ChildERC20 childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "TEMPLATE", "TPT", 18);

        ChildERC20Bridge childERC20BridgeImplementation = new ChildERC20Bridge();
        childERC20BridgeImplementation.initialize(address(1), "0x123", address(1), "root", address(1));

        TransparentUpgradeableProxy childERC20BridgeProxy = new TransparentUpgradeableProxy(
            address(childERC20BridgeImplementation),
            address(proxyAdmin),
            ""
        );

        ChildAxelarBridgeAdaptor childBridgeAdaptorImplementation = new ChildAxelarBridgeAdaptor(
            childGateway
        );

        TransparentUpgradeableProxy childBridgeAdaptorProxy = new TransparentUpgradeableProxy(
            address(childBridgeAdaptorImplementation),
            address(proxyAdmin),
            ""
        );

        WIMX wrappedIMX = new WIMX();

        vm.stopBroadcast();

        console2.log("====CHILD ADDRESSES====");
        console2.log("ProxyAdmin: %", address(proxyAdmin));
        console2.log("Child ERC20 Bridge Proxy: %s", address(childERC20BridgeProxy));
        console2.log("Child ERC20 Bridge Implementation: %s", address(childERC20BridgeImplementation));
        console2.log("Child Axelar Bridge Adaptor Proxy: %s", address(childBridgeAdaptorProxy));
        console2.log("Child Axelar Bridge Adaptor Implementation: %s", address(childBridgeAdaptorImplementation));
        console2.log("childTokenTemplate: %s", address(childTokenTemplate));
        console2.log("Wrapped IMX: %s", address(wrappedIMX));
    }
}
