// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {RootERC20BridgeFlowRate} from "../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {Utils} from "../../utils.t.sol";

contract RootERC20BridgeFlowRateForkTest is Test, Utils {
    uint256 mainnetFork;
    address payable rootBridgeAddress = payable(0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6);
    RootERC20BridgeFlowRate public rootBridgeFlowRate;
    string MAINNET_RPC_URL = vm.envString("FORK_MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        rootBridgeFlowRate = RootERC20BridgeFlowRate(rootBridgeAddress);
    }

    function test_getWithdrawalDelay() public {
        uint256 withdrawDelay = rootBridgeFlowRate.withdrawalDelay();
        console2.log("withdrawDelay");
        console2.logUint(withdrawDelay);
        assertEq(withdrawDelay, uint256(86400));
    }
}
