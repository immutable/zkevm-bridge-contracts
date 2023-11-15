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
import {
    RootAxelarBridgeAdaptor, IRootAxelarBridgeAdaptorEvents
} from "../../../../src/root/RootAxelarBridgeAdaptor.sol";
import {Utils} from "../../../utils.t.sol";
import {WETH} from "../../../../src/test/root/WETH.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

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
    RootERC20Bridge public rootBridge;
    RootAxelarBridgeAdaptor public axelarAdaptor;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasService public axelarGasService;

    receive() external payable {}

    function setUp() public {
        deployCodeTo("WETH.sol", abi.encode("Wrapped ETH", "WETH"), WRAPPED_ETH);

        RootIntegration memory integration = rootIntegrationSetup(
            CHILD_BRIDGE,
            CHILD_BRIDGE_ADAPTOR,
            CHILD_CHAIN_NAME,
            IMX_TOKEN_ADDRESS,
            WRAPPED_ETH,
            UNLIMITED_DEPOSIT_LIMIT
        );

        imxToken = integration.imxToken;
        token = integration.token;
        rootBridge = integration.rootBridge;
        axelarAdaptor = integration.axelarAdaptor;
        mockAxelarGateway = integration.mockAxelarGateway;
        axelarGasService = integration.axelarGasService;

        // Need to first map the token.
        rootBridge.mapToken{value: 1}(token);
        // And give the bridge some tokens
        token.transfer(address(rootBridge), 100 ether);
        imxToken.transfer(address(rootBridge), 100 ether);
        // Give bridge some ETH
        deal(address(rootBridge), 100 ether);
    }

    function test_RevertsIf_WithdrawWithInvalidSourceChain() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

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
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Data too short"));
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_RevertsIf_MessageWithInvalidSignature() public {
        bytes memory data = abi.encode("INVALID_SIG", address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Unsupported action signature"));
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdraw_TransfersTokens() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 thisPreBal = token.balanceOf(address(this));
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 thisPostBal = token.balanceOf(address(this));
        uint256 bridgePostBal = token.balanceOf(address(rootBridge));

        assertEq(thisPostBal, thisPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdrawIMX_TransfersIMX() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 thisPreBal = imxToken.balanceOf(address(this));
        uint256 bridgePreBal = imxToken.balanceOf(address(rootBridge));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 thisPostBal = imxToken.balanceOf(address(this));
        uint256 bridgePostBal = imxToken.balanceOf(address(rootBridge));

        assertEq(thisPostBal, thisPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdrawETH_TransfersETH() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 thisPreBal = address(this).balance;
        uint256 bridgePreBal = address(rootBridge).balance;

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 thisPostBal = address(this).balance;
        uint256 bridgePostBal = address(rootBridge).balance;

        assertEq(thisPostBal, thisPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdraw_TransfersTokens_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 receiverPreBal = token.balanceOf(receiver);
        uint256 bridgePreBal = token.balanceOf(address(rootBridge));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 receiverPostBal = token.balanceOf(receiver);
        uint256 bridgePostBal = token.balanceOf(address(rootBridge));

        assertEq(receiverPostBal, receiverPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdrawIMX_TransfersIMX_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 receiverPreBal = imxToken.balanceOf(receiver);
        uint256 bridgePreBal = imxToken.balanceOf(address(rootBridge));

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 receiverPostBal = imxToken.balanceOf(receiver);
        uint256 bridgePostBal = imxToken.balanceOf(address(rootBridge));

        assertEq(receiverPostBal, receiverPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdrawETH_TransfersETH_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        uint256 receiverPreBal = address(receiver).balance;
        uint256 bridgePreBal = address(rootBridge).balance;

        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);

        uint256 receiverPostBal = address(receiver).balance;
        uint256 bridgePostBal = address(rootBridge).balance;

        assertEq(receiverPostBal, receiverPreBal + withdrawAmount, "Incorrect user balance after withdraw");
        assertEq(bridgePostBal, bridgePreBal - withdrawAmount, "Incorrect bridge balance after withdraw");
    }

    function test_withdraw_EmitsRootChainERC20WithdrawEvent() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(
            address(token),
            rootBridge.rootTokenToChildToken(address(token)),
            address(this),
            address(this),
            withdrawAmount
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdrawIMX_EmitsRootChainERC20WithdrawEvent() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(address(imxToken), NATIVE_IMX, address(this), address(this), withdrawAmount);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdrawETH_EmitsRootChainETHWithdrawEvent() public {
        bytes memory data = abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), address(this), withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainETHWithdraw(
            NATIVE_ETH, address(rootBridge.childETHToken()), address(this), address(this), withdrawAmount
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdraw_EmitsRootChainERC20WithdrawEvent_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, address(token), address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(
            address(token), rootBridge.rootTokenToChildToken(address(token)), address(this), receiver, withdrawAmount
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdrawIMX_EmitsRootChainERC20WithdrawEvent_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, IMX_TOKEN_ADDRESS, address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainERC20Withdraw(address(imxToken), NATIVE_IMX, address(this), receiver, withdrawAmount);
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }

    function test_withdrawETH_EmitsRootChainETHWithdrawEvent_DifferentReceiver() public {
        address receiver = address(987654321);
        bytes memory data = abi.encode(WITHDRAW_SIG, NATIVE_ETH, address(this), receiver, withdrawAmount);

        bytes32 commandId = bytes32("testCommandId");
        string memory sourceAddress = rootBridge.childBridgeAdaptor();

        vm.expectEmit();
        emit RootChainETHWithdraw(
            NATIVE_ETH, address(rootBridge.childETHToken()), address(this), receiver, withdrawAmount
        );
        axelarAdaptor.execute(commandId, CHILD_CHAIN_NAME, sourceAddress, data);
    }
}
