// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {RootERC20Bridge} from "../src/root/RootERC20Bridge.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";
import {ChildERC20} from "../src/child/ChildERC20.sol";

// TODO update private key usage to be more secure: https://book.getfoundry.sh/reference/forge/forge-script#wallet-options---raw

contract RootContracts is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address rootGateway = vm.envAddress("ROOT_GATEWAY_ADDRESS");
        address childERC20Bridge = vm.envAddress("CHILD_ERC20_BRIDGE_ADDRESS");
        address childBridgeAdaptor = vm.envAddress("CHILD_BRIDGE_ADAPTOR_ADDRESS");
        // address _childBridgeAdaptor,
        // string memory _childChain,
        // address _axelarGateway,
        // address _gasService
        vm.startBroadcast(deployerPrivateKey);

        ChildERC20 childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "FILLER", "FLR", 18);

        RootERC20Bridge rootBridge = new RootERC20Bridge();

        RootAxelarBridgeAdaptor rootBridgeAdaptor = new RootAxelarBridgeAdaptor(
            address(rootBridge), // root bridge
            // address(2), // child bridge adaptor
            "test", // child chain name
            address(3), // axelar gateway
            address(4) // axelar gas service
        );

        // TODO make sure we set bridge adaptors everywhere

        // rootBridge.initialize(address(rootBridgeAdaptor), address(456), address(789));

        vm.stopBroadcast();
    }
}
