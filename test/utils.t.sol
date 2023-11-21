// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "./mocks/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "./mocks/root/MockAxelarGasService.sol";
import {RootERC20Bridge, IERC20Metadata} from "../src/root/RootERC20Bridge.sol";
import {RootERC20BridgeFlowRate} from "../src/root//flowrate/RootERC20BridgeFlowRate.sol";
import {ChildERC20Bridge, IChildERC20Bridge} from "../src/child/ChildERC20Bridge.sol";
import {ChildAxelarBridgeAdaptor, IChildAxelarBridgeAdaptor} from "../src/child/ChildAxelarBridgeAdaptor.sol";
import {IWETH} from "../src/interfaces/root/IWETH.sol";
import {WIMX} from "../src/child/WIMX.sol";

import {IChildERC20, ChildERC20} from "../src/child/ChildERC20.sol";
import {IRootERC20Bridge} from "../src/root/RootERC20Bridge.sol";
import {RootAxelarBridgeAdaptor} from "../src/root/RootAxelarBridgeAdaptor.sol";
import {IRootAxelarBridgeAdaptor} from "../src/interfaces/root/IRootAxelarBridgeAdaptor.sol";

interface IPausable {
    function pause() external;

    function unpause() external;
}

contract Utils is Test {
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");

    address pauser = makeAddr("pauser");
    address unpauser = makeAddr("unpauser");

    function pause(IPausable bridge) public {
        vm.startPrank(pauser);
        bridge.pause();
        vm.stopPrank();
    }

    function unpause(IPausable bridge) public {
        vm.startPrank(unpauser);
        bridge.unpause();
        vm.stopPrank();
    }

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
        address childWIMX = address(0xabc);

        deployCodeTo("WIMX.sol", childWIMX);

        axelarGasService = new MockAxelarGasService();
        mockAxelarGateway = new MockAxelarGateway();
        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(1), "Test", "TST", 18);
        childBridge = new ChildERC20Bridge();
        childBridgeAdaptor = new ChildAxelarBridgeAdaptor(address(mockAxelarGateway));
        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this),
            treasuryManager: address(this)
        });
        childBridge.initialize(
            roles, address(childBridgeAdaptor), rootAdaptor, address(childTokenTemplate), "ROOT", rootIMX, childWIMX
        );

        IChildAxelarBridgeAdaptor.InitializationRoles memory adaptorRoles = IChildAxelarBridgeAdaptor
            .InitializationRoles({
            defaultAdmin: address(this),
            bridgeManager: address(this),
            gasServiceManager: address(this),
            targetManager: address(this)
        });

        childBridgeAdaptor.initialize(adaptorRoles, "ROOT", address(childBridge), address(axelarGasService));

        bytes memory mapTokenData = abi.encode(MAP_TOKEN_SIG, rootToken, "TEST NAME", "TNM", 18);
        vm.prank(address(childBridgeAdaptor));
        childBridge.onMessageReceive("ROOT", rootAdaptor, mapTokenData);

        ChildERC20 childToken = ChildERC20(childBridge.rootTokenToChildToken(address(rootToken)));
        vm.prank(address(childBridge));
        childToken.mint(address(this), 1000000 ether);
        childToken.approve(address(childBridge), 1000000 ether);
    }

    struct RootIntegration {
        ERC20PresetMinterPauser imxToken;
        ERC20PresetMinterPauser token;
        RootERC20BridgeFlowRate rootBridgeFlowRate;
        RootAxelarBridgeAdaptor axelarAdaptor;
        MockAxelarGateway mockAxelarGateway;
        MockAxelarGasService axelarGasService;
    }

    function rootIntegrationSetup(
        address childBridge,
        address childBridgeAdaptor,
        string memory childBridgeName,
        address imxTokenAddress,
        address wethTokenAddress,
        uint256 imxCumulativeDepositLimit
    ) public returns (RootIntegration memory integrationTest) {
        integrationTest.token = new ERC20PresetMinterPauser("Test", "TST");
        integrationTest.token.mint(address(this), 1000000 ether);

        deployCodeTo("ERC20PresetMinterPauser.sol", abi.encode("ImmutableX", "IMX"), imxTokenAddress);
        integrationTest.imxToken = ERC20PresetMinterPauser(imxTokenAddress);
        integrationTest.imxToken.mint(address(this), 1000000 ether);

        integrationTest.rootBridgeFlowRate = new RootERC20BridgeFlowRate();
        integrationTest.mockAxelarGateway = new MockAxelarGateway();
        integrationTest.axelarGasService = new MockAxelarGasService();

        integrationTest.axelarAdaptor = new RootAxelarBridgeAdaptor(address(integrationTest.mockAxelarGateway));

        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        integrationTest.rootBridgeFlowRate.initialize(
            roles,
            address(integrationTest.axelarAdaptor),
            childBridge,
            Strings.toHexString(childBridgeAdaptor),
            address(integrationTest.token),
            imxTokenAddress,
            wethTokenAddress,
            childBridgeName,
            imxCumulativeDepositLimit,
            address(this)
        );

        IRootAxelarBridgeAdaptor.InitializationRoles memory adaptorRoles = IRootAxelarBridgeAdaptor.InitializationRoles({
            defaultAdmin: address(this),
            bridgeManager: address(this),
            gasServiceManager: address(this),
            targetManager: address(this)
        });

        integrationTest.axelarAdaptor.initialize(
            adaptorRoles,
            address(integrationTest.rootBridgeFlowRate),
            childBridgeName,
            address(integrationTest.axelarGasService)
        );
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
