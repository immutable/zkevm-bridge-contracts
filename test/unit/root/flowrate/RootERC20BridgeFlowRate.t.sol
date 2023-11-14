// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    RootERC20BridgeFlowRate,
    IRootERC20BridgeFlowRateEvents,
    IRootERC20BridgeFlowRateErrors,
    IRootERC20Bridge
} from "../../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";
import {MockAxelarGateway} from "../../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../../src/test/root/MockAxelarGasService.sol";
import {MockAdaptor} from "../../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WETH} from "../../../../src/test/root/WETH.sol";

contract RootERC20BridgeFlowRateUnitTest is Test, IRootERC20BridgeFlowRateEvents, IRootERC20BridgeFlowRateErrors, Utils {
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string CHILD_BRIDGE_ADAPTOR_STRING = Strings.toHexString(CHILD_BRIDGE_ADAPTOR);
    string constant CHILD_CHAIN_NAME = "test";
    address constant IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);
    uint256 constant mapTokenFee = 300;
    uint256 constant depositFee = 200;
    uint256 constant UNLIMITED_IMX_DEPOSITS = 0;

    ERC20PresetMinterPauser public token;
    RootERC20BridgeFlowRate public rootBridgeFlowRate;
    MockAdaptor public mockAxelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    function setUp() public {
        token = new ERC20PresetMinterPauser("Test", "TST");
        deployCodeTo("ERC20PresetMinterPauser.sol", abi.encode("ImmutableX", "IMX"), IMX_TOKEN);

        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        rootBridgeFlowRate = new RootERC20BridgeFlowRate();
        mockAxelarGateway = new MockAxelarGateway();
        axelarGasService = new MockAxelarGasService();

        mockAxelarAdaptor = new MockAdaptor();

        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        // The specific ERC20 token template does not matter for these unit tests
        rootBridgeFlowRate.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR_STRING,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            CHILD_CHAIN_NAME,
            UNLIMITED_IMX_DEPOSITS,
            address(this)
        );
    }

    /**
     * INITIALIZE
     */

    function test_InitializeBridgeFlowRate() public {
        assertEq(address(rootBridgeFlowRate.rootBridgeAdaptor()), address(mockAxelarAdaptor), "bridgeAdaptor not set");
        assertEq(rootBridgeFlowRate.childERC20Bridge(), CHILD_BRIDGE, "childERC20Bridge not set");
        assertEq(rootBridgeFlowRate.childTokenTemplate(), address(token), "childTokenTemplate not set");
        assert(Strings.equal(rootBridgeFlowRate.childChain(), CHILD_CHAIN_NAME));
        assert(Strings.equal(CHILD_BRIDGE_ADAPTOR_STRING, rootBridgeFlowRate.childBridgeAdaptor()));
        assertEq(address(token), rootBridgeFlowRate.childTokenTemplate(), "childTokenTemplate not set");
        assertEq(rootBridgeFlowRate.rootIMXToken(), IMX_TOKEN, "rootIMXToken not set");
        assertEq(rootBridgeFlowRate.rootWETHToken(), WRAPPED_ETH, "rootWETHToken not set");
    }

    function test_RevertIfInitializedTwice() public {
        IRootERC20Bridge.InitializationRoles memory roles = IRootERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            variableManager: address(this),
            adaptorManager: address(this)
        });

        vm.expectRevert("Initializable: contract is already initialized");
        rootBridgeFlowRate.initialize(
            roles,
            address(mockAxelarAdaptor),
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR_STRING,
            address(token),
            IMX_TOKEN,
            WRAPPED_ETH,
            CHILD_CHAIN_NAME,
            UNLIMITED_IMX_DEPOSITS,
            address(this)
        );
    }

}
