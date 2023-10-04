// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {RootERC20Bridge} from "../src/root/RootERC20Bridge.sol";
// root Axelar adaptor
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract RootBridgeAndAdaptorScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address rootGateway = vm.envAddress("ROOT_GATEWAY_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        RootERC20Bridge rootBridge = new RootERC20Bridge();

        RootAxelarBridgeAdaptor rootBridgeAdaptor = new RootAxelarBridgeAdaptor(
            address(rootBridge), // root bridge
            address(2), // child bridge adaptor
            "test", // child chain name
            address(3), // axelar gateway
            address(4) // axelar gas service
        );

        rootBridge.initialize(address(rootBridgeAdaptor), address(456), address(789));

    function initialize(address newBridgeAdaptor, address newChildERC20Bridge, address newChildTokenTemplate)
        vm.stopBroadcast();
    }
}
