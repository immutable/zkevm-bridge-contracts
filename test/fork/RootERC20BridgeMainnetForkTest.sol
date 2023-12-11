// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IRootERC20Bridge, IRootERC20BridgeEvents} from "../../src/root/RootERC20Bridge.sol";
import {IRootAxelarBridgeAdaptor} from "../../src/interfaces/root/IRootAxelarBridgeAdaptor.sol";
import "../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import "../../src/root/RootAxelarBridgeAdaptor.sol";
import "../../src/child/ChildERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract RootERC20BridgeMainnetForkTest is Test, IRootERC20BridgeEvents, IRootAxelarBridgeAdaptorEvents {
    IERC20Metadata private constant WETH = IERC20Metadata(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Metadata private constant USDC = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata private constant IMX = IERC20Metadata(0xF57e7e7C23978C3cAEC3C3548E3D615c346e79fF);

    address private USDC_WHALE_ADDRESS = 0xcEe284F754E854890e311e3280b767F80797180d;
    address private IMX_WHALE_ADDRESS = 0x971f723194796dbF04DcFe361ED584CaE9bf94A0;

    address private constant AXELAR_GATEWAY_ADDRESS = 0x4F4495243837681061C4743b74B3eEdf548D56A5;
    address private constant AXELAR_GAS_SERVICE_ADDRESS = 0x2d5d7d31F671F86C782533cc367F14109a082712;

    string private constant CHILD_CHAIN_ID = "immutable-mainnet";
    string private constant CHILD_BRIDGE_ADAPTOR = "0x4F4495243837681061C4743b74B3eEdf548D56A5";

    // TODO: Replace with env variable
    string private MAINNET_RPC_URL = "https://mainnet.infura.io/v3/21b1232d47d749f183f2d47bfd89ecb6";

    address private mockChildBridge = address(0x123);
    address private mockChildAdaptor = address(0x1234);

    uint256 private mainnetForkId;

    RootERC20BridgeFlowRate private rootBridge;
    RootAxelarBridgeAdaptor private rootAdaptor;
    ChildERC20 private rootTokenTemplate;
    address private rootBridgeAddress;
    address private rootAdaptorAddress;

    event NativeGasPaidForContractCall(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event ContractCall(
        address indexed sender,
        string destinationChain,
        string destinationContractAddress,
        bytes32 indexed payloadHash,
        bytes payload
    );

    function setUp() public {
        mainnetForkId = vm.createSelectFork(MAINNET_RPC_URL);

        rootBridge = _deployRootERC20Bridge();
        rootBridgeAddress = address(rootBridge);

        rootAdaptor = _deployRootAxelarAdaptor();
        rootAdaptorAddress = address(rootAdaptor);

        rootTokenTemplate = _deployAndInitChildTokenTemplate(rootBridgeAddress);

        _initializeRootBridge(rootBridge, address(rootTokenTemplate), rootAdaptorAddress);
        _initializeAdaptor(rootAdaptor, rootBridgeAddress);

        vm.deal(address(this), 100 ether);
    }

    /**
     *  @dev This test verifies that mapping and depositing of official USDC on Ethereum mainnet works as expected.
     *       It deploys a new RootERC20BridgeFlowRate contract and a new RootAxelarBridgeAdaptor contract.
     *       It then maps USDC to the new RootERC20BridgeFlowRate contract and deposits 100 USDC to the bridge.
     *       It ensures that the mapping and depositing works as expected by verifying that the correct events are emitted.
     */
    function test_Mainnet_USDCMapAndDeposit() public {
        vm.selectFork(mainnetForkId);
        IERC20Metadata usdcOnChild = _mapAndVerify(address(USDC));
        _depositAndVerify(USDC, usdcOnChild, USDC_WHALE_ADDRESS);
    }

    /// @dev Maps a token on Mainnet, and ensures operations emits the correct events
    function _mapAndVerify(address token) private returns (IERC20Metadata) {
        uint256 bridgeFee = 100;
        address predictedChildTokenAddress = Clones.predictDeterministicAddress(
            address(rootTokenTemplate), keccak256(abi.encodePacked(token)), address(mockChildBridge)
        );

        vm.expectEmit(true, false, false, false, AXELAR_GAS_SERVICE_ADDRESS);
        emit NativeGasPaidForContractCall(
            rootAdaptorAddress, CHILD_CHAIN_ID, CHILD_BRIDGE_ADAPTOR, "", bridgeFee, address(this)
        );

        vm.expectEmit(true, false, false, false, AXELAR_GATEWAY_ADDRESS);
        emit ContractCall(rootAdaptorAddress, CHILD_CHAIN_ID, CHILD_BRIDGE_ADAPTOR, "", "");

        vm.expectEmit(true, true, false, false, rootAdaptorAddress);
        emit AxelarMessageSent(CHILD_CHAIN_ID, CHILD_BRIDGE_ADAPTOR, "");

        vm.expectEmit(rootBridgeAddress);
        emit L1TokenMapped(token, predictedChildTokenAddress);

        rootBridge.mapToken{value: bridgeFee}(IERC20Metadata(token));
        assertEq(rootBridge.rootTokenToChildToken(token), predictedChildTokenAddress);
        return IERC20Metadata(predictedChildTokenAddress);
    }

    /// @dev Deposits token and ensures operations emits the correct events
    function _depositAndVerify(IERC20Metadata rootToken, IERC20Metadata childToken, address whale) private {
        // get some token from a whale
        uint256 bridgeAmount = 100_000;
        uint256 bridgeFee = 100;
        vm.prank(whale);
        rootToken.transfer(address(this), bridgeAmount); // get some tokens from a whale

        rootToken.approve(rootBridgeAddress, bridgeAmount);

        // deposit to the bridge and expect the following events to be emitted
        vm.expectEmit(true, false, false, false, AXELAR_GAS_SERVICE_ADDRESS);
        emit NativeGasPaidForContractCall(
            rootAdaptorAddress, CHILD_CHAIN_ID, CHILD_BRIDGE_ADAPTOR, "", bridgeFee, address(this)
        );

        vm.expectEmit(true, false, false, false, AXELAR_GATEWAY_ADDRESS);
        emit ContractCall(rootAdaptorAddress, CHILD_CHAIN_ID, CHILD_BRIDGE_ADAPTOR, "", "");

        vm.expectEmit(true, true, false, false, rootAdaptorAddress);
        emit AxelarMessageSent(CHILD_CHAIN_ID, CHILD_BRIDGE_ADAPTOR, "");

        vm.expectEmit(rootBridgeAddress);
        emit ChildChainERC20Deposit(address(rootToken), address(childToken), address(this), address(this), bridgeAmount);

        rootBridge.deposit{value: bridgeFee}(rootToken, bridgeAmount);
    }

    function _deployRootERC20Bridge() private returns (RootERC20BridgeFlowRate) {
        return new RootERC20BridgeFlowRate();
    }

    function _deployRootAxelarAdaptor() private returns (RootAxelarBridgeAdaptor) {
        return new RootAxelarBridgeAdaptor(AXELAR_GATEWAY_ADDRESS);
    }

    function _deployAndInitChildTokenTemplate(address _bridge) private returns (ChildERC20) {
        ChildERC20 template = new ChildERC20();
        template.initialize(_bridge, "ChildToken", "CT", 18);
        return template;
    }

    function _initializeRootBridge(RootERC20BridgeFlowRate _bridge, address _tokenTemplate, address _adaptor) private {
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });
        _bridge.initialize(
            roles,
            _adaptor,
            mockChildBridge,
            _tokenTemplate,
            address(IMX),
            address(WETH),
            _bridge.UNLIMITED_DEPOSIT(),
            address(this)
        );
    }

    function _initializeAdaptor(RootAxelarBridgeAdaptor _adaptor, address _bridge) private {
        IRootAxelarBridgeAdaptor.InitializationRoles memory roles = IRootAxelarBridgeAdaptor.InitializationRoles({
            defaultAdmin: address(this),
            bridgeManager: address(this),
            gasServiceManager: address(this),
            targetManager: address(this)
        });
        _adaptor.initialize(roles, _bridge, CHILD_CHAIN_ID, CHILD_BRIDGE_ADAPTOR, AXELAR_GAS_SERVICE_ADDRESS);
    }
}
