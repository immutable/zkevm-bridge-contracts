// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MockAxelarGateway} from "../../../../src/test/root/MockAxelarGateway.sol";
import {MockAxelarGasService} from "../../../../src/test/root/MockAxelarGasService.sol";
import {
    RootERC20Bridge,
    IRootERC20BridgeEvents,
    IERC20Metadata,
    IRootERC20BridgeErrors
} from "../../../../src/root/RootERC20Bridge.sol";
import {RootERC20BridgeFlowRate} from "../../../../src/root/flowrate/RootERC20BridgeFlowRate.sol";

import {
    RootAxelarBridgeAdaptor, IRootAxelarBridgeAdaptorEvents
} from "../../../../src/root/RootAxelarBridgeAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WETH} from "../../../../src/test/root/WETH.sol";

contract RootERC20BridgeWithdrawIntegrationTest is
    Test,
    IRootERC20BridgeErrors,
    IRootERC20BridgeEvents,
    IRootAxelarBridgeAdaptorEvents,
    Utils
{
    address constant CHILD_BRIDGE = address(3);
    address constant CHILD_BRIDGE_ADAPTOR = address(4);
    string constant CHILD_CHAIN_NAME = "CHILD";
    address constant IMX_TOKEN_ADDRESS = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    address constant WRAPPED_ETH = address(0xddd);
    uint256 constant UNLIMITED_DEPOSIT_LIMIT = 0;
    address public constant NATIVE_IMX = address(0xfff);

    uint256 constant withdrawAmount = 0.5 ether;

    ERC20PresetMinterPauser public token;
    ERC20PresetMinterPauser public imxToken;
    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;
    RootERC20BridgeFlowRate public rootBridgeFlowRate;

    function setUp() public {

        console2.log('root withdraw setUp');
        
        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        RootIntegration memory integration = rootIntegrationSetup(
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR,
            CHILD_CHAIN_NAME,
            IMX_TOKEN_ADDRESS,
            WRAPPED_ETH,
            UNLIMITED_DEPOSIT_LIMIT
        );

        console2.log('after rootIntegrationSetup');


        imxToken = integration.imxToken;
        token = integration.token;
        rootBridgeFlowRate = integration.rootBridgeFlowRate;
        axelarAdaptor = integration.axelarAdaptor;
        mockAxelarGateway = integration.mockAxelarGateway;
        axelarGasService = integration.axelarGasService;

        // Need to first map the token.
        rootBridgeFlowRate.mapToken{value: 1}(token);
        //Need to setup the flowRate
        rootBridgeFlowRate.setRateControlThreshold(address(token), 1000 ether, 100 ether, 10 ether);
        rootBridgeFlowRate.setRateControlThreshold(IMX_TOKEN_ADDRESS, 1000 ether, 100 ether, 10 ether);
        // And give the bridge some tokens
        token.transfer(address(rootBridgeFlowRate), 100 ether);
        imxToken.transfer(address(rootBridgeFlowRate), 100 ether);

    }

    function test_RevertsIf_WithdrawWithInvalidSourceChain() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        vm.expectRevert(InvalidSourceChain.selector);
        axelarAdaptor.execute(commandId, "INVALID", sourceAddress, data);
    }

    function test_RevertsIf_WithdrawWithInvalidSourceAddress() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = Strings.toHexString(address(123));

        vm.expectRevert(InvalidSourceAddress.selector);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_RevertsIf_MessageWithEmptyData() public {
        bytes memory data;

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Data too short"));
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_RevertsIf_MessageWithInvalidSignature() public {
        bytes memory data = abi.encode("INVALID_SIG", address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Unsupported action signature"));
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdraw_TransfersTokens() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridgeFlowRate));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 thisPostBal = token.balanceOf(address(this));
        uint256 bridgePostBal = token.balanceOf(address(rootBridgeFlowRate));

        assertEq(thisPostBal, thisPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdrawIMX_TransfersIMX() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        uint256 thisPreBal = imxToken.balanceOf(address(this));
        uint256 bridgePreBal = imxToken.balanceOf(address(rootBridgeFlowRate));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 thisPostBal = imxToken.balanceOf(address(this));
        uint256 bridgePostBal = imxToken.balanceOf(address(rootBridgeFlowRate));

        assertEq(thisPostBal, thisPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdraw_TransfersTokens_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        uint256 receiverPreBal = token.balanceOf(receiver);
        uint256 bridgePreBal = token.balanceOf(address(rootBridgeFlowRate));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 receiverPostBal = token.balanceOf(receiver);
        uint256 bridgePostBal = token.balanceOf(address(rootBridgeFlowRate));

        assertEq(receiverPostBal, receiverPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdrawIMX_TransfersIMX_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        uint256 receiverPreBal = imxToken.balanceOf(receiver);
        uint256 bridgePreBal = imxToken.balanceOf(address(rootBridgeFlowRate));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 receiverPostBal = imxToken.balanceOf(receiver);
        uint256 bridgePostBal = imxToken.balanceOf(address(rootBridgeFlowRate));

        assertEq(receiverPostBal, receiverPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdraw_EmitsRootChainERC20WithdrawEvent() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(
            address(token),
            rootBridgeFlowRate.rootTokenToChildToken(address(token)),
            address(this),
            address(this),
            withdrawAmount
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdrawIMX_EmitsRootChainERC20WithdrawEvent() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), address(this), withdrawAmount);

        console2.logAddress(IMX_TOKEN_ADDRESS);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(address(imxToken), NATIVE_IMX, address(this), address(this), withdrawAmount);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdraw_EmitsRootChainERC20WithdrawEvent_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(
            address(token), rootBridgeFlowRate.rootTokenToChildToken(address(token)), address(this), receiver, withdrawAmount
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdrawIMX_EmitsRootChainERC20WithdrawEvent_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridgeFlowRate.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(address(imxToken), NATIVE_IMX, address(this), receiver, withdrawAmount);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }
}
