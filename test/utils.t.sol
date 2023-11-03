// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../src/test/root/MockAxelarGasService.sol";
import {RootERC20Bridge, IERC20Metadata} from "../src/root/RootERC20Bridge.sol";
import {ChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {WETH} from "../src/test/root/WETH.sol";
import {IWETH} from "../src/interfaces/root/IWETH.sol";

import {IChildERC20, ChildERC20} from "../src/child/ChildERC20.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";

contract Utils is Test {
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");

    function childIntegrationSetup()
        public
        returns (
            ChildERC20Bridge childBridge,
            ChildAxelarBridgeAdaptor childBridgeAdaptor,
            address rootToken,
            address rootIMX,
            ChildERC20 childTokenTemplate,
            MockAxelarGasService axelarGasService,
            MockAxelarGateway mockAxelarGateway
        )
    {
        string memory rootAdaptor = Strings.toHexString(address(99999));
        rootIMX = address(555555);
        rootToken = address(44444);

        axelarGasService = new MockAxelarGasService();
        mockAxelarGateway = new MockAxelarGateway();
        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(1), "Test", "TST", 18);
        childBridge = new ChildERC20Bridge();
        childBridgeAdaptor = new ChildAxelarBridgeAdaptor(address(mockAxelarGateway));
        childBridge.initialize(address(childBridgeAdaptor), rootAdaptor, address(childTokenTemplate), "ROOT", rootIMX);
        childBridgeAdaptor.initialize("ROOT", address(childBridge), address(axelarGasService));

        bytes memory mapTokenData = abi.encode(MAP_TOKEN_SIG, rootToken, "TEST NAME", "TNM", 18);
        vm.prank(address(childBridgeAdaptor));
        childBridge.onMessageReceive("ROOT", rootAdaptor, mapTokenData);

        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(address(rootToken)));
        vm.prank(address(childBridge));
        childToken.mint(address(this), 1000000 ether);
        childToken.approve(address(childBridge), 1000000 ether);
    }

    function rootIntegrationSetup(
        address childBridge,
        address childBridgeAdaptor,
        string memory childBridgeName,
        address imxTokenAddress,
        address wethTokenAddress
    )
        public
        returns (
            ERC20PresetMinterPauser imxToken,
            ERC20PresetMinterPauser token,
            RootERC20Bridge rootBridge,
            RootAxelarBridgeAdaptor axelarAdaptor,
            MockAxelarGateway mockAxelarGateway,
            MockAxelarGasService axelarGasService
        )
    {
        token = new ERC20PresetMinterPauser("Test", "TST");
        token.mint(address(this), 1000000 ether);

        deployCodeTo("ERC20PresetMinterPauser.sol", abi.encode("ImmutableX", "IMX"), imxTokenAddress);
        imxToken = ERC20PresetMinterPauser(imxTokenAddress);
        imxToken.mint(address(this), 1000000 ether);

        // deployCodeTo("WETH9.sol", abi.encode("Wrapped ETH", "WETH"), wethTokenAddress);
        // imxToken = ERC20PresetMinterPauser(imxTokenAddress);
        // imxToken.mint(address(this), 1000000 ether);

        rootBridge = new RootERC20Bridge();
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();

        axelarAdaptor = new RootAxelarBridgeAdaptor(address(mockAxelarGateway));

        rootBridge.initialize(
            address(axelarAdaptor),
            childBridge,
            Strings.toHexString(childBridgeAdaptor),
            address(token),
            imxTokenAddress,
            wethTokenAddress,
            "CHILD"
        );

        axelarAdaptor.initialize(address(rootBridge), childBridgeName, address(axelarGasService));
    }

    function setupDeposit(
        address token,
        RootERC20Bridge rootBridge,
        uint256 mapTokenFee,
        uint256 depositFee,
        uint256 tokenAmount,
        bool saveTokenMapping
    ) public returns (address childToken, bytes memory predictedPayload) {
        return _setupDeposit(token, rootBridge, mapTokenFee, depositFee, tokenAmount, address(this), saveTokenMapping);
    }

    function setupDepositTo(
        address token,
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
        address token,
        RootERC20Bridge rootBridge,
        uint256 mapTokenFee,
        uint256 depositFee,
        uint256 tokenAmount,
        address to,
        bool saveTokenMapping
    ) public returns (address childToken, bytes memory predictedPayload) {
        predictedPayload = abi.encode(rootBridge.DEPOSIT_SIG(), token, address(this), to, tokenAmount);

        if (saveTokenMapping) {
            childToken = rootBridge.mapToken{value: mapTokenFee}(ERC20PresetMinterPauser(token));
        }

        if (token == address(0xeee)) {
            vm.deal(to, tokenAmount + depositFee);
        } else if (address(token) == address(0xddd)) {
            // set the payload to expect native eth when depositing wrapped eth
            predictedPayload = abi.encode(rootBridge.DEPOSIT_SIG(), address(0xeee), address(this), to, tokenAmount);
            vm.deal(to, tokenAmount + depositFee);
            IWETH(token).deposit{value: tokenAmount}();
            IWETH(token).approve(address(rootBridge), tokenAmount);
        } else {
            ERC20PresetMinterPauser(token).mint(address(this), tokenAmount);
            ERC20PresetMinterPauser(token).approve(address(rootBridge), tokenAmount);
        }

        return (childToken, predictedPayload);
    }

    function setupChildDeposit(
        ChildERC20 token,
        ChildERC20Bridge childBridge,
        string memory sourceChain,
        string memory sourceAddress
    ) public {
        string memory name = token.name();
        string memory symbol = token.symbol();
        uint8 decimals = token.decimals();

        bytes memory payload = abi.encode(childBridge.MAP_TOKEN_SIG(), address(token), name, symbol, decimals);

        childBridge.onMessageReceive(sourceChain, sourceAddress, payload);
    }

    function getMappingStorageSlotFor(address key, uint256 position) public pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(key, position));
    }
}
