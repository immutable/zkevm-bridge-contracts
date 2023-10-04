// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {MockAxelarGateway} from "../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../src/test/root/MockAxelarGasService.sol";
import {RootERC20Bridge, IERC20Metadata} from "../src/root/RootERC20Bridge.sol";
import {IChildERC20} from "../src/child/ChildERC20.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";

contract Utils is Test {
    function integrationSetup(address childBridge, address childBridgeAdaptor, string memory childBridgeName)
        public
        returns (
            ERC20PresetMinterPauser token,
            RootERC20Bridge rootBridge,
            RootAxelarBridgeAdaptor axelarAdaptor,
            MockAxelarGateway mockAxelarGateway,
            MockAxelarGasService axelarGasService
        )
    {
        token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(this), 1000000 ether);

        rootBridge = new RootERC20Bridge();
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();

        axelarAdaptor = new RootAxelarBridgeAdaptor(
            address(rootBridge),
            childBridgeAdaptor,
            childBridgeName,
            address(mockAxelarGateway),
            address(axelarGasService)
        );

        rootBridge.initialize(address(axelarAdaptor), childBridge, address(token));
    }

    function setupDeposit(
        ERC20PresetMinterPauser token,
        RootERC20Bridge rootBridge,
        uint256 gasPrice,
        uint256 tokenAmount
    ) public returns (address childToken, bytes memory predictedPayload) {
        return _setupDeposit(token, rootBridge, gasPrice, tokenAmount, address(this));
    }

    function setupDepositTo(
        ERC20PresetMinterPauser token,
        RootERC20Bridge rootBridge,
        uint256 gasPrice,
        uint256 tokenAmount,
        address to
    ) public returns (address childToken, bytes memory predictedPayload) {
        return _setupDeposit(token, rootBridge, gasPrice, tokenAmount, to);
    }

    function _setupDeposit(
        ERC20PresetMinterPauser token,
        RootERC20Bridge rootBridge,
        uint256 gasPrice,
        uint256 tokenAmount,
        address to
    ) public returns (address childToken, bytes memory predictedPayload) {
        predictedPayload = abi.encode(rootBridge.DEPOSIT_SIG(), address(token), address(this), to, tokenAmount);

        childToken = rootBridge.mapToken{value: gasPrice}(token);

        token.mint(address(this), tokenAmount);
        token.approve(address(rootBridge), tokenAmount);

        return (childToken, predictedPayload);
    }
}
