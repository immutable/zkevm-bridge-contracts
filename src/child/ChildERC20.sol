// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
// Adapted from OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../lib/EIP712MetaTransaction.sol";
import "../interfaces/child/IChildERC20.sol";

/**
 *   @title ChildERC20
 *   @author Polygon Technology (@QEDK)
 *   @notice Child token template for ChildERC20 predicate deployments
 *   @dev All child tokens are clones of this contract. Burning and minting is controlled by the ChildERC20Bridge.
 *   @dev This is an upgradeable contract so it's possible to patch any future security vulnerabilities or extend the token's functionality.
 *   @dev During the bootstrap process this contract is deployed on-chain. 
 *        When a token is initially mapped by the ChildERC20Bridge the deployed contract is cloned by the ChildERC20Bridge to a deterministic address.
 *        The address of the new ChildERC20 token is the keccak256 hash of the rootToken's address.
 *        The newly deployed token is then initialized with the same name, symbol and decimals as the rootToken.
 *        This deterministic cloning approach allows the token mapping on the root and child bridges to stay congruent.
 */
// solhint-disable reason-string
contract ChildERC20 is EIP712MetaTransaction, ERC20Upgradeable, IChildERC20 {
    address private _bridge;
    address private _rootToken;
    uint8 private _decimals;

    modifier onlyBridge() {
        require(msg.sender == _bridge, "ChildERC20: Only bridge can call");
        _;
    }

    /**
     * @inheritdoc IChildERC20
     */
    function initialize(address rootToken_, string calldata name_, string calldata symbol_, uint8 decimals_)
        external
        initializer
    {
        require(
            rootToken_ != address(0) && bytes(name_).length != 0 && bytes(symbol_).length != 0,
            "ChildERC20: BAD_INITIALIZATION"
        );
        _rootToken = rootToken_;
        _decimals = decimals_;
        _bridge = msg.sender;
        __ERC20_init(name_, symbol_);
        _initializeEIP712(name_, "1");
    }

    /**
     * @notice Returns the decimals places of the token
     * @return uint8 Returns the decimals places of the token.
     */
    function decimals() public view virtual override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (uint8) {
        return _decimals;
    }

    /**
     * @inheritdoc IChildERC20
     */
    function bridge() external view virtual returns (address) {
        return _bridge;
    }

    /**
     * @inheritdoc IChildERC20
     */
    function rootToken() external view virtual returns (address) {
        return _rootToken;
    }

    /**
     * @inheritdoc IChildERC20
     */
    function mint(address account, uint256 amount) external virtual onlyBridge returns (bool) {
        _mint(account, amount);

        return true;
    }

    /**
     * @inheritdoc IChildERC20
     */
    function burn(address account, uint256 amount) external virtual onlyBridge returns (bool) {
        _burn(account, amount);

        return true;
    }

    function _msgSender() internal view virtual override(EIP712MetaTransaction, ContextUpgradeable) returns (address) {
        return EIP712MetaTransaction._msgSender();
    }
}
