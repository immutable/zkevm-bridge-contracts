// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {MockAxelarGateway} from "../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../src/test/root/MockAxelarGasService.sol";
import {RootERC20Bridge, IERC20Metadata} from "../src/root/RootERC20Bridge.sol";
import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";

import {IChildERC20, ChildERC20} from "../src/child/ChildERC20.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";

contract Utils is Test {

    function integrationSetup(
        address childBridge, 
        address childBridgeAdaptor, 
        string memory childBridgeName,
        address imxTokenAddress,
        address ethTokenAddress)
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
            childBridgeName,
            address(mockAxelarGateway),
            address(axelarGasService)
        );

        rootBridge.initialize(address(axelarAdaptor), childBridge, childBridgeAdaptor, address(token), imxTokenAddress, ethTokenAddress);
        axelarAdaptor.setChildBridgeAdaptor();
    }

    function setupDeposit(
        ERC20PresetMinterPauser token,
        RootERC20Bridge rootBridge,
        uint256 mapTokenFee,
        uint256 depositFee,
        uint256 tokenAmount,
        bool saveTokenMapping
    ) public returns (address childToken, bytes memory predictedPayload) {
        return _setupDeposit(token, rootBridge, mapTokenFee, depositFee, tokenAmount, address(this), saveTokenMapping);
    }

    function setupDepositTo(
        ERC20PresetMinterPauser token,
        RootERC20Bridge rootBridge,
        uint256 mapTokenFee,
        uint256 depositFee,
        uint256 tokenAmount,
        address to,
        bool saveTokenMapping
    ) public returns (address childToken, bytes memory predictedPayload) {
        return _setupDeposit(token, rootBridge, mapTokenFee, depositFee, tokenAmount, to, saveTokenMapping);
    }

    function _setupDeposit(
        ERC20PresetMinterPauser token,
        RootERC20Bridge rootBridge,
        uint256 mapTokenFee,
        uint256 depositFee,
        uint256 tokenAmount,
        address to,
        bool saveTokenMapping
    ) public returns (address childToken, bytes memory predictedPayload) {
        predictedPayload = abi.encode(rootBridge.DEPOSIT_SIG(), address(token), address(this), to, tokenAmount);
        if (saveTokenMapping) {
            childToken = rootBridge.mapToken{value: mapTokenFee}(token);
        }
        if (address(token) == address(0xeee)) {
            vm.deal(to, tokenAmount+depositFee);
        } else {
            token.mint(address(this), tokenAmount);
            token.approve(address(rootBridge), tokenAmount);
        }
        
        return (childToken, predictedPayload);
    }

    function setupChildDeposit(
        ChildERC20 token,
        ChildERC20Bridge childBridge,
        string memory sourceChain,
        string memory sourceAddress
    ) public {
        string memory name = "TEST";
        string memory symbol = "TST";
        uint8 decimals = 18;

        bytes memory payload = abi.encode(childBridge.MAP_TOKEN_SIG(), address(token), name, symbol, decimals);

        childBridge.onMessageReceive(sourceChain, sourceAddress, payload);
    }

    function getMappingStorageSlotFor(address key, uint256 position) public pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(key, position));
    }
}
