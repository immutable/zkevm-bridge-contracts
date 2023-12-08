// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ChildERC20} from "../../../src/child/ChildERC20.sol";

contract ChildERC20Test is Test {
    string constant DEFAULT_CHILDERC20_NAME = "Child ERC20";
    string constant DEFAULT_CHILDERC20_SYMBOL = "CERC";
    uint8 constant DEFAULT_CHILDERC20_DECIMALS = 18;
    address constant DEFAULT_CHILDERC20_ADDRESS = address(111);

    ChildERC20 public childToken;

    function setUp() public {
        childToken = new ChildERC20();
        childToken.initialize(DEFAULT_CHILDERC20_ADDRESS, DEFAULT_CHILDERC20_NAME, DEFAULT_CHILDERC20_SYMBOL, DEFAULT_CHILDERC20_DECIMALS);
    }

    function test_InitialState() public {
        assertEq(childToken.name(), DEFAULT_CHILDERC20_NAME, "Incorrect token name");
        assertEq(childToken.symbol(), DEFAULT_CHILDERC20_SYMBOL, "Incorrect token symbol");
        assertEq(childToken.decimals(), DEFAULT_CHILDERC20_DECIMALS, "Incorrect token decimals");
        assertEq(childToken.totalSupply(), 0, "Incorrect token supply");
    }

    function test_FailInitialisationBadAddress() public {
        ChildERC20 failedToken = new ChildERC20();
        vm.expectRevert("ChildERC20: BAD_INITIALIZATION");
        failedToken.initialize(address(0), DEFAULT_CHILDERC20_NAME, DEFAULT_CHILDERC20_SYMBOL, DEFAULT_CHILDERC20_DECIMALS);
    }

    function test_FailInitialisationBadName() public {
        ChildERC20 failedToken = new ChildERC20();
        vm.expectRevert("ChildERC20: BAD_INITIALIZATION");
        failedToken.initialize(DEFAULT_CHILDERC20_ADDRESS, "", DEFAULT_CHILDERC20_SYMBOL, DEFAULT_CHILDERC20_DECIMALS);
    }

    function test_FailInitialisationBadSymbol() public {
        ChildERC20 failedToken = new ChildERC20();
        vm.expectRevert("ChildERC20: BAD_INITIALIZATION");
        failedToken.initialize(DEFAULT_CHILDERC20_ADDRESS, DEFAULT_CHILDERC20_NAME, "", DEFAULT_CHILDERC20_DECIMALS);
    }

    function test_RevertIf_InitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        childToken.initialize(DEFAULT_CHILDERC20_ADDRESS, DEFAULT_CHILDERC20_NAME, DEFAULT_CHILDERC20_SYMBOL, DEFAULT_CHILDERC20_DECIMALS);        
    }

    function test_RevertIf_MintTokensByNotDeployer() public {
        address notDeployer = address(333);
        address receiver = address(222);
        vm.prank(notDeployer);
        vm.expectRevert("ChildERC20: Only bridge can call");
        childToken.mint(receiver, 100);        
    }

    function test_MintSuccess() public {
        uint256 mintAmount = 1000000;
        address receiver = address(222);

        uint256 receiverPreBal = childToken.balanceOf(receiver);

        childToken.mint(receiver, mintAmount);   

        uint256 receiverPostBal = childToken.balanceOf(receiver);

        assertEq(childToken.totalSupply(), mintAmount, "Incorrect token supply");
        assertEq(receiverPostBal, receiverPreBal + mintAmount, "Incorrect token balance");
    }

    function test_RevertIf_BurnTokensByNotDeployer() public {
        address notDeployer = address(333);
        address receiver = address(222);
        vm.prank(notDeployer);
        vm.expectRevert("ChildERC20: Only bridge can call");
        childToken.burn(receiver, 100);             
    }

    function test_BurnSuccess() public {
        uint256 mintAmount = 1000000;
        uint256 burnAmount = 1000;
        address receiver = address(222);

        childToken.mint(receiver, mintAmount);   

        uint256 receiverPreBurnBal = childToken.balanceOf(receiver);

        childToken.burn(receiver, burnAmount);   

        uint256 receiverPostBurnBal = childToken.balanceOf(receiver);

        assertEq(childToken.totalSupply(), mintAmount - burnAmount, "Incorrect token supply");
        assertEq(receiverPostBurnBal, receiverPreBurnBal - burnAmount, "Incorrect token balance");
    }
}
