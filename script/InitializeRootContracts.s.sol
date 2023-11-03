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

struct InitializeRootContractsParams {
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
}

contract InitializeRootContracts is Script {
    function run() public {
        InitializeRootContractsParams memory params = InitializeRootContractsParams({
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
            rootGasService: vm.envAddress("ROOT_GAS_SERVICE_ADDRESS")
        });

        string[] memory checksumInputs = Utils.getChecksumInputs(params.childBridgeAdaptor);
        bytes memory checksumOutput = vm.ffi(checksumInputs);
        string memory childBridgeAdaptorChecksum = string(Utils.removeZeroByteValues(checksumOutput));
        /**
         * INITIALIZE ROOT CHAIN CONTRACTS
         */
        vm.createSelectFork(params.rootRpcUrl);
        vm.startBroadcast(params.rootPrivateKey);

        params.rootERC20Bridge.initialize(
            address(params.rootBridgeAdaptor),
            params.childERC20Bridge,
            childBridgeAdaptorChecksum,
            params.rootChainChildTokenTemplate,
            params.rootIMXToken,
            params.rootWETHToken,
            params.childChainName
        );

        params.rootBridgeAdaptor.initialize(
            address(params.rootERC20Bridge), // root bridge
            params.childChainName, // child chain name
            params.rootGasService // axelar gas service
        );

        vm.stopBroadcast();
    }
}
