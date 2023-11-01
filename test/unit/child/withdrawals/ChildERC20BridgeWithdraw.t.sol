// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ChildERC20Bridge,
    IChildERC20BridgeEvents,
    IERC20Metadata,
    IChildERC20BridgeErrors
} from "../../../../src/child/ChildERC20Bridge.sol";
import {IChildERC20} from "../../../../src/interfaces/child/IChildERC20.sol";
import {ChildERC20} from "../../../../src/child/ChildERC20.sol";
import {MockAdaptor} from "../../../../src/test/root/MockAdaptor.sol";
import {Utils} from "../../../utils.t.sol";

contract ChildERC20BridgeWithdrawUnitTest is Test, IChildERC20BridgeEvents, IChildERC20BridgeErrors, Utils {
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    address constant ROOT_BRIDGE = address(3);
    string public ROOT_BRIDGE_ADAPTOR = Strings.toHexString(address(4));
    string constant ROOT_CHAIN_NAME = "test";
    address constant ROOT_IMX_TOKEN = address(0xccc);
    address constant NATIVE_ETH = address(0xeee);
    ChildERC20 public childTokenTemplate;
    ChildERC20 public rootToken;
    ChildERC20 public childToken;
    address public childETHToken;
    ChildERC20Bridge public childBridge;
    MockAdaptor public mockAdaptor;

    function setUp() public {
        rootToken = new ChildERC20();
        rootToken.initialize(address(456), "Test", "TST", 18);

        childTokenTemplate = new ChildERC20();
        childTokenTemplate.initialize(address(123), "Test", "TST", 18);

        mockAdaptor = new MockAdaptor();

        childBridge = new ChildERC20Bridge();
        childBridge.initialize(
            address(mockAdaptor), ROOT_BRIDGE_ADAPTOR, address(childTokenTemplate), ROOT_CHAIN_NAME, ROOT_IMX_TOKEN
        );

        bytes memory mapTokenData =
            abi.encode(MAP_TOKEN_SIG, rootToken, rootToken.name(), rootToken.symbol(), rootToken.decimals());

        vm.prank(address(mockAdaptor));
        childBridge.onMessageReceive(ROOT_CHAIN_NAME, ROOT_BRIDGE_ADAPTOR, mapTokenData);

        childToken = ChildERC20(childBridge.rootTokenToChildToken(address(rootToken)));
    }

    function test_RevertsIf_WithdrawCalledWithEmptyChildToken() public {
        vm.expectRevert(EmptyTokenContract.selector);
        childBridge.withdraw(IChildERC20(address(2222222)), 100);
    }

    function test_RevertsIf_WithdrawCalledWithUnmappedToken() public {
        ChildERC20 newToken = new ChildERC20();
        newToken.initialize(address(123), "Test", "TST", 18);
        vm.expectRevert(NotMapped.selector);
        childBridge.withdraw(IChildERC20(address(newToken)), 100);
    }

    function test_RevertsIf_WithdrawCalledWithAChildTokenThatHasWrongBridge() public {
        // Found by running `forge inspect src/child/ChildERC20.sol:ChildERC20 storageLayout | grep -B3 -A5 -i "bridge"`
        uint256 bridgeSlot = 108;
        bytes32 bridgeSlotBytes32 = bytes32(bridgeSlot);
        vm.store(address(childToken), bridgeSlotBytes32, bytes32(uint256(uint160(address(0x123)))));

        vm.expectRevert(BridgeNotSet.selector);
        childBridge.withdraw(IChildERC20(address(childToken)), 100);
    }

    function test_RevertsIf_WithdrawCalledWithAChildTokenWithUnsetRootToken() public {
        /* First, set rootToken of mapped token to zero */

        // Found by running `forge inspect src/child/ChildERC20.sol:ChildERC20 storageLayout | grep -B3 -A5 -i "rootToken"`
        uint256 rootTokenSlot = 109;
        bytes32 rootTokenSlotBytes32 = bytes32(rootTokenSlot);
        vm.store(address(childToken), rootTokenSlotBytes32, bytes32(uint256(uint160(address(0)))));

        /* Then, set rootTokenToChildToken[address(0)] to the child token (to bypass the NotMapped check) */

        // Slot is 2 because of the Ownable, Initializable contracts coming first.
        // Found by running `forge inspect src/child/ChildERC20Bridge.sol:ChildERC20Bridge storageLayout | grep -B3 -A5 -i "rootTokenToChildToken"`
        uint256 rootTokenToChildTokenMappingSlot = 2;
        bytes32 slot = getMappingStorageSlotFor(address(0), rootTokenToChildTokenMappingSlot);
        bytes32 data = bytes32(uint256(uint160(address(childToken))));

        vm.store(address(childBridge), slot, data);

        vm.expectRevert(ZeroAddressRootToken.selector);
        childBridge.withdraw(IChildERC20(address(childToken)), 100);
    }

    /**
     * @dev TODO NOTE: we are currently not testing the case where:
     * token is mapped AND child token's `rootToken` == address(0).
     */
}
