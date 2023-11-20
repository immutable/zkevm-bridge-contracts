// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ChildAxelarBridgeAdaptor} from "../../../src/child/ChildAxelarBridgeAdaptor.sol";
import {
    ChildERC20Bridge,
    IChildERC20Bridge,
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors
} from "../../../src/child/ChildERC20Bridge.sol";
import {IChildERC20, ChildERC20} from "../../../src/child/ChildERC20.sol";
import {MockChildAxelarGateway} from "../../../src/test/child/MockChildAxelarGateway.sol";
import {MockChildAxelarGasService} from "../../../src/test/child/MockChildAxelarGasService.sol";
import {Utils} from "../../utils.t.sol";

contract ChildERC20BridgeIntegrationTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    string public ROOT_ADAPTOR_ADDRESS = Strings.toHexString(address(1));
    string public ROOT_CHAIN_NAME = "ROOT_CHAIN";
    address constant IMX_TOKEN_ADDRESS = address(0xccc);
    address constant WIMX_TOKEN_ADDRESS = address(0xabc);
    address constant NATIVE_ETH = address(0xeee);
    address constant MULTISIG_ADDRESS = address(0xbbbb);
    address constant INITIAL_DEPOSITOR = address(0xcccc);

    ChildERC20Bridge public childERC20Bridge;
    ChildERC20 public childERC20;
    ChildAxelarBridgeAdaptor public childAxelarBridgeAdaptor;
    MockChildAxelarGateway public mockChildAxelarGateway;
    MockChildAxelarGasService public mockChildAxelarGasService;

    function setUp() public {
        childERC20 = new ChildERC20();
        childERC20.initialize(address(123), "Test", "TST", 18);

        childERC20Bridge = new ChildERC20Bridge();
        mockChildAxelarGateway = new MockChildAxelarGateway();
        mockChildAxelarGasService = new MockChildAxelarGasService();
        childAxelarBridgeAdaptor = new ChildAxelarBridgeAdaptor(address(mockChildAxelarGateway));

        IChildERC20Bridge.InitializationRoles memory roles = IChildERC20Bridge.InitializationRoles({
            defaultAdmin: address(this),
            pauser: address(this),
            unpauser: address(this),
            adaptorManager: address(this)
        });
        childERC20Bridge.initialize(
            roles,
            address(childAxelarBridgeAdaptor),
            ROOT_ADAPTOR_ADDRESS,
            address(childERC20),
            ROOT_CHAIN_NAME,
            IMX_TOKEN_ADDRESS,
            WIMX_TOKEN_ADDRESS,
            MULTISIG_ADDRESS,
            INITIAL_DEPOSITOR
        );

        childAxelarBridgeAdaptor.initialize(
            ROOT_CHAIN_NAME, address(childERC20Bridge), address(mockChildAxelarGasService)
        );
    }

    function test_ChildTokenMap() public {
        address rootTokenAddress = address(456);
        string memory name = "test name";
        string memory symbol = "TSTNME";
        uint8 decimals = 17;

        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encode(childERC20Bridge.MAP_TOKEN_SIG(), rootTokenAddress, name, symbol, decimals);

        address predictedAddress = Clones.predictDeterministicAddress(
            address(childERC20), keccak256(abi.encodePacked(rootTokenAddress)), address(childERC20Bridge)
        );
        vm.expectEmit(true, true, false, false, address(childERC20Bridge));
        emit L2TokenMapped(rootTokenAddress, predictedAddress);

        childAxelarBridgeAdaptor.execute(commandId, ROOT_CHAIN_NAME, ROOT_ADAPTOR_ADDRESS, payload);

        assertEq(
            childERC20Bridge.rootTokenToChildToken(rootTokenAddress),
            predictedAddress,
            "rootTokenToChildToken mapping not set"
        );

        IChildERC20 childToken = IChildERC20(predictedAddress);
        assertEq(childToken.name(), name, "token name not set");
        assertEq(childToken.symbol(), symbol, "token symbol not set");
        assertEq(childToken.decimals(), decimals, "token decimals not set");
    }

    function test_RevertIf_payloadDataNotValid() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encode("invalid payload");

        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Unsupported action signature"));
        childAxelarBridgeAdaptor.execute(commandId, ROOT_CHAIN_NAME, ROOT_ADAPTOR_ADDRESS, payload);
    }

    function test_RevertIf_rootTokenAddressIsZero() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encode(childERC20Bridge.MAP_TOKEN_SIG(), address(0), "test name", "TSTNME", 17);

        vm.expectRevert(ZeroAddress.selector);
        childAxelarBridgeAdaptor.execute(commandId, ROOT_CHAIN_NAME, ROOT_ADAPTOR_ADDRESS, payload);
    }

    function test_RevertIf_MapTwice() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encode(childERC20Bridge.MAP_TOKEN_SIG(), address(456), "test name", "TSTNME", 17);

        childAxelarBridgeAdaptor.execute(commandId, ROOT_CHAIN_NAME, ROOT_ADAPTOR_ADDRESS, payload);

        vm.expectRevert(AlreadyMapped.selector);
        childAxelarBridgeAdaptor.execute(commandId, ROOT_CHAIN_NAME, ROOT_ADAPTOR_ADDRESS, payload);
    }

    function test_RevertIf_EmptyData() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = "";

        vm.expectRevert(abi.encodeWithSelector(InvalidData.selector, "Data too short"));
        childAxelarBridgeAdaptor.execute(commandId, ROOT_CHAIN_NAME, ROOT_ADAPTOR_ADDRESS, payload);
    }

    function test_RevertIf_InvalidSourceChain() public {
        bytes32 commandId = bytes32("testCommandId");
        bytes memory payload = abi.encode(childERC20Bridge.MAP_TOKEN_SIG(), address(456), "test name", "TSTNME", 17);

        vm.expectRevert(InvalidSourceChain.selector);
        childAxelarBridgeAdaptor.execute(commandId, "FAKE_CHAIN", ROOT_ADAPTOR_ADDRESS, payload);
    }

    function mapToken(address root) public returns (address childToken) {
        bytes32 mapTokenSig = childERC20Bridge.MAP_TOKEN_SIG();
        vm.prank(address(childAxelarBridgeAdaptor));
        childERC20Bridge.onMessageReceive(
            ROOT_CHAIN_NAME, ROOT_ADAPTOR_ADDRESS, abi.encode(mapTokenSig, root, "test name", "TSTNME", 17)
        );
        return Clones.predictDeterministicAddress(
            address(childERC20), keccak256(abi.encodePacked(root)), address(childERC20Bridge)
        );
    }

    /*
     * DEPOSIT
     */
    function test_deposit_EmitsChildChainERC20Deposit() public {
        address rootTokenAddress = address(456);
        address sender = address(0xff);
        address receiver = address(0xee);
        uint256 amount = 100;
        address childToken = mapToken(rootTokenAddress);
        bytes32 commandId = bytes32("testCommandId");

        vm.expectEmit(address(childERC20Bridge));
        emit ChildChainERC20Deposit(rootTokenAddress, childToken, sender, receiver, amount);

        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(childERC20Bridge.DEPOSIT_SIG(), rootTokenAddress, sender, receiver, amount)
        );
    }

    function test_deposit_EmitsNativeDeposit() public {
        address sender = address(0xff);
        address receiver = address(0xee);
        uint256 amount = 100;

        address predictedChildETHToken = Clones.predictDeterministicAddress(
            address(childERC20), keccak256(abi.encodePacked(NATIVE_ETH)), address(childERC20Bridge)
        );

        bytes32 commandId = bytes32("testCommandId");

        vm.expectEmit(address(childERC20Bridge));
        emit NativeEthDeposit(NATIVE_ETH, predictedChildETHToken, sender, receiver, amount);

        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(childERC20Bridge.DEPOSIT_SIG(), NATIVE_ETH, sender, receiver, amount)
        );
    }

    function test_deposit_EmitsIMXDeposit() public {
        address sender = address(0xff);
        address receiver = address(0xee);
        uint256 amount = 100;
        bytes32 commandId = bytes32("testCommandId");

        vm.deal(address(childERC20Bridge), 1 ether);

        vm.expectEmit(address(childERC20Bridge));
        emit IMXDeposit(IMX_TOKEN_ADDRESS, sender, receiver, amount);

        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(childERC20Bridge.DEPOSIT_SIG(), IMX_TOKEN_ADDRESS, sender, receiver, amount)
        );
    }

    function test_deposit_TransfersTokenToReceiver() public {
        address rootTokenAddress = address(456);
        address sender = address(0xff);
        address receiver = address(0xee);
        uint256 amount = 100;
        address childToken = mapToken(rootTokenAddress);
        bytes32 commandId = bytes32("testCommandId");

        uint256 receiverPreBal = ChildERC20(childToken).balanceOf(receiver);

        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(childERC20Bridge.DEPOSIT_SIG(), rootTokenAddress, sender, receiver, amount)
        );

        assertEq(ChildERC20(childToken).balanceOf(receiver), receiverPreBal + amount, "receiver balance not increased");
    }

    function test_deposit_IncreasesTotalSupply() public {
        address rootTokenAddress = address(456);
        address sender = address(0xff);
        address receiver = address(0xee);
        uint256 amount = 100;
        address childToken = mapToken(rootTokenAddress);
        bytes32 commandId = bytes32("testCommandId");

        uint256 totalSupplyPre = ChildERC20(childToken).totalSupply();

        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(childERC20Bridge.DEPOSIT_SIG(), rootTokenAddress, sender, receiver, amount)
        );

        assertEq(ChildERC20(childToken).totalSupply(), totalSupplyPre + amount, "total supply not increased");
    }

    function test_RevertIf_depositWithRootTokenNotMapped() public {
        address rootTokenAddress = address(456);
        address sender = address(0xff);
        address receiver = address(0xee);
        uint256 amount = 100;
        bytes32 commandId = bytes32("testCommandId");
        bytes32 depositSig = childERC20Bridge.DEPOSIT_SIG();

        vm.expectRevert(NotMapped.selector);
        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(depositSig, rootTokenAddress, sender, receiver, amount)
        );
    }

    // TODO add mapToken calls to these to isolate the specific error we are testing for vvvv

    function test_RevertIf_depositWithRootTokenZeroAddress() public {
        address rootTokenAddress = address(0);
        address sender = address(0xff);
        address receiver = address(0xee);
        uint256 amount = 100;
        bytes32 commandId = bytes32("testCommandId");
        bytes32 depositSig = childERC20Bridge.DEPOSIT_SIG();

        vm.expectRevert(ZeroAddress.selector);
        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(depositSig, rootTokenAddress, sender, receiver, amount)
        );
    }

    function test_RevertIf_depositWithReceiverZeroAddress() public {
        address rootTokenAddress = address(456);
        address sender = address(0xff);
        address receiver = address(0);
        uint256 amount = 100;
        bytes32 commandId = bytes32("testCommandId");
        bytes32 depositSig = childERC20Bridge.DEPOSIT_SIG();

        vm.expectRevert(ZeroAddress.selector);
        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(depositSig, rootTokenAddress, sender, receiver, amount)
        );
    }

    // Manually storage slot of a token in the rootTokenToChildToken mapping, but since it
    // is not a smart contract, it's code length will be 0.
    function test_RevertIf_depositWithEmptyContract() public {
        address sender = address(0xff);
        address receiver = address(12345);
        uint256 amount = 100;
        bytes32 commandId = bytes32("testCommandId");
        bytes32 depositSig = childERC20Bridge.DEPOSIT_SIG();
        address rootAddress = address(0x123);
        {
            // Found by running `forge inspect src/child/ChildERC20Bridge.sol:ChildERC20Bridge storageLayout | grep -B3 -A5 -i "rootTokenToChildToken"`
            uint256 rootTokenToChildTokenMappingSlot = 201;
            address childAddress = address(444444);
            bytes32 slot = getMappingStorageSlotFor(rootAddress, rootTokenToChildTokenMappingSlot);
            bytes32 data = bytes32(uint256(uint160(childAddress)));
            vm.store(address(childERC20Bridge), slot, data);
        }

        vm.expectRevert(EmptyTokenContract.selector);
        childAxelarBridgeAdaptor.execute(
            commandId,
            ROOT_CHAIN_NAME,
            ROOT_ADAPTOR_ADDRESS,
            abi.encode(depositSig, rootAddress, sender, receiver, amount)
        );
    }
}
