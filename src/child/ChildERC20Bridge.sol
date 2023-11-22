// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors,
    IChildERC20Bridge
} from "../interfaces/child/IChildERC20Bridge.sol";
import {IChildERC20BridgeAdaptor} from "../interfaces/child/IChildERC20BridgeAdaptor.sol";
import {IChildERC20} from "../interfaces/child/IChildERC20.sol";
import {IWIMX} from "../interfaces/child/IWIMX.sol";
import {BridgeRoles} from "../common/BridgeRoles.sol";

/**
 * @title Child ERC20 Bridge
 * @notice ChildERC20Bridge is a bridge contract for the child chain, which enables bridging of standard ERC20 tokens, ETH, wETH, IMX and wIMX from the root chain to the child chain and back.
 * @dev Features:
 *      - Map: A token that is originally created on the root chain, can be mapped to the child chain, where a representation of the token is created and managed by the bridge.
 *      - Deposit: Standard ERC20 tokens, native ETH, wrapped ETH or IMX that can be deposited on the root chain, and wrapped version of the tokens are issued on the child chain.
 *      - Withdraw: Bridged wrapped tokens can be withdrawn, so that they can be redeemed for their original tokens on the root chain.
 *      - Manage Role Based Access Control
 *
 * @dev Design:
 *      This contract follows a pattern of using a bridge adaptor to communicate with the child chain. This is because the underlying communication protocol may change,
 *      and also allows us to decouple vendor-specific messaging logic from the bridge logic.
 *      Because of this pattern, any checks or logic that is agnostic to the messaging protocol should be done in this contract.
 *      Any checks or logic that is specific to the underlying messaging protocol should be done in the bridge adaptor.
 *
 * @dev Roles:
 *      - An account with a PAUSER_ROLE can pause the contract.
 *      - An account with an UNPAUSER_ROLE can unpause the contract.
 *      - An account with an ADAPTOR_MANAGER_ROLE can update the root bridge adaptor address.
 *      - An account with a DEFAULT_ADMIN_ROLE can grant and revoke roles.
 * @dev Note:
 *      - There is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
 *      - This is an upgradeable contract that should be operated behind OpenZeppelin's TransparentUpgradeableProxy.
 *      - The initialize function is susceptible to front running, so precautions should be taken to account for this scenario.
 */
contract ChildERC20Bridge is BridgeRoles, IChildERC20BridgeErrors, IChildERC20Bridge, IChildERC20BridgeEvents {
    /// @dev leave this as the first param for the integration tests.
    mapping(address => address) public rootTokenToChildToken;

    /// @dev Role identifier for those who can directly deposit native IMX to the bridge.
    bytes32 public constant TREASURY_MANAGER_ROLE = keccak256("TREASURY_MANAGER");

    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant DEPOSIT_SIG = keccak256("DEPOSIT");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");
    address public constant NATIVE_ETH = address(0xeee);
    address public constant NATIVE_IMX = address(0xfff);

    IChildERC20BridgeAdaptor public bridgeAdaptor;

    /// @dev The address that will be sending messages to, and receiving messages from, the child chain.
    string public rootERC20BridgeAdaptor;
    /// @dev The address of the token template that will be cloned to create tokens.
    address public childTokenTemplate;
    /// @dev The name of the chain that this bridge is connected to.
    string public rootChain;
    /// @dev The address of the IMX ERC20 token on L1.
    address public rootIMXToken;
    /// @dev The address of the ETH ERC20 token on L2.
    address public childETHToken;
    /// @dev The address of the wrapped IMX token on L2.
    address public wIMXToken;

    /**
     * @notice Initialization function for ChildERC20Bridge.
     * @param newRoles Struct containing addresses of roles.
     * @param newBridgeAdaptor Address of StateSender to send deposit information to.
     * @param newRootERC20BridgeAdaptor Stringified address of root ERC20 bridge adaptor to communicate with.
     * @param newChildTokenTemplate Address of child token template to clone.
     * @param newRootChain A stringified representation of the chain that this bridge is connected to. Used for validation.
     * @param newRootIMXToken Address of ECR20 IMX on the root chain.
     * @param newWIMXToken Address of wrapped IMX on the child chain.
     * @dev Can only be called once.
     */
    function initialize(
        InitializationRoles memory newRoles,
        address newBridgeAdaptor,
        string memory newRootERC20BridgeAdaptor,
        address newChildTokenTemplate,
        string memory newRootChain,
        address newRootIMXToken,
        address newWIMXToken
    ) public initializer {
        if (
            newBridgeAdaptor == address(0) || newChildTokenTemplate == address(0) || newRootIMXToken == address(0)
                || newRoles.defaultAdmin == address(0) || newRoles.pauser == address(0) || newRoles.unpauser == address(0)
                || newRoles.adaptorManager == address(0) || newRoles.treasuryManager == address(0)
                || newWIMXToken == address(0)
        ) {
            revert ZeroAddress();
        }

        if (bytes(newRootERC20BridgeAdaptor).length == 0) {
            revert InvalidRootERC20BridgeAdaptor();
        }

        if (bytes(newRootChain).length == 0) {
            revert InvalidRootChain();
        }

        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, newRoles.defaultAdmin);
        _grantRole(PAUSER_ROLE, newRoles.pauser);
        _grantRole(UNPAUSER_ROLE, newRoles.unpauser);
        _grantRole(ADAPTOR_MANAGER_ROLE, newRoles.adaptorManager);
        _grantRole(TREASURY_MANAGER_ROLE, newRoles.treasuryManager);

        rootERC20BridgeAdaptor = newRootERC20BridgeAdaptor;
        childTokenTemplate = newChildTokenTemplate;
        bridgeAdaptor = IChildERC20BridgeAdaptor(newBridgeAdaptor);
        rootChain = newRootChain;
        rootIMXToken = newRootIMXToken;
        wIMXToken = newWIMXToken;

        // NOTE: how will this behave in an updgrade scenario?
        // e.g. this clone may already be deployed and we could deploy to the same address if the salt is the same.
        // Clone childERC20 for native eth
        IChildERC20 clonedETHToken =
            IChildERC20(Clones.cloneDeterministic(childTokenTemplate, keccak256(abi.encodePacked(NATIVE_ETH))));
        // Initialize
        clonedETHToken.initialize(NATIVE_ETH, "Ethereum", "ETH", 18);
        childETHToken = address(clonedETHToken);

        // Map the supported tokens by default
        rootTokenToChildToken[NATIVE_ETH] = childETHToken;
    }

    /**
     * @notice Method to receive IMX back from the WIMX contract when it is unwrapped
     * @dev When a user deposits wIMX, it must first be unwrapped.
     *      This allows the bridge to store the underlying native IMX, rather than the wrapped version.
     *      The unwrapping is done through the WIMX contract's `withdraw()` function, which sends the native IMX to this bridge contract.
     *      The only reason this `receive()` function is needed is for this process, hence the validation ensures that the sender is the WIMX contract.
     */
    receive() external payable whenNotPaused {
        // Revert if sender is not the WIMX token address
        if (msg.sender != wIMXToken) {
            revert NonWrappedNativeTransfer();
        }
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function treasuryDeposit() external payable onlyRole(TREASURY_MANAGER_ROLE) {
        if (msg.value == 0) {
            revert ZeroValue();
        }
        emit TreasuryDeposit(msg.sender, msg.value);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function updateChildBridgeAdaptor(address newBridgeAdaptor) external onlyRole(ADAPTOR_MANAGER_ROLE) {
        if (newBridgeAdaptor == address(0)) {
            revert ZeroAddress();
        }

        emit ChildBridgeAdaptorUpdated(address(bridgeAdaptor), newBridgeAdaptor);
        bridgeAdaptor = IChildERC20BridgeAdaptor(newBridgeAdaptor);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function updateRootBridgeAdaptor(string memory newRootBridgeAdaptor) external onlyRole(ADAPTOR_MANAGER_ROLE) {
        if (bytes(newRootBridgeAdaptor).length == 0) {
            revert InvalidRootERC20BridgeAdaptor();
        }

        emit RootBridgeAdaptorUpdated(rootERC20BridgeAdaptor, newRootBridgeAdaptor);
        rootERC20BridgeAdaptor = newRootBridgeAdaptor;
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function onMessageReceive(string calldata messageSourceChain, string calldata sourceAddress, bytes calldata data)
        external
        override
        whenNotPaused
    {
        if (msg.sender != address(bridgeAdaptor)) {
            revert NotBridgeAdaptor();
        }
        if (!Strings.equal(messageSourceChain, rootChain)) {
            revert InvalidSourceChain();
        }
        if (!Strings.equal(sourceAddress, rootERC20BridgeAdaptor)) {
            revert InvalidSourceAddress();
        }
        if (data.length <= 32) {
            // Data must always be greater than 32.
            // 32 bytes for the signature, and at least some information for the payload
            revert InvalidData("Data too short");
        }

        if (bytes32(data[:32]) == MAP_TOKEN_SIG) {
            _mapToken(data);
        } else if (bytes32(data[:32]) == DEPOSIT_SIG) {
            _deposit(data[32:]);
        } else {
            revert InvalidData("Unsupported action signature");
        }
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdraw(IChildERC20 childToken, uint256 amount) external payable {
        _withdraw(address(childToken), msg.sender, amount);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdrawTo(IChildERC20 childToken, address receiver, uint256 amount) external payable {
        _withdraw(address(childToken), receiver, amount);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdrawIMX(uint256 amount) external payable {
        _withdraw(NATIVE_IMX, msg.sender, amount);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdrawIMXTo(address receiver, uint256 amount) external payable {
        _withdraw(NATIVE_IMX, receiver, amount);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdrawWIMX(uint256 amount) external payable {
        _withdraw(wIMXToken, msg.sender, amount);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdrawWIMXTo(address receiver, uint256 amount) external payable {
        _withdraw(wIMXToken, receiver, amount);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdrawETH(uint256 amount) external payable {
        _withdraw(childETHToken, msg.sender, amount);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function withdrawETHTo(address receiver, uint256 amount) external payable {
        _withdraw(childETHToken, receiver, amount);
    }

    /**
     * @notice Private function to handle withdrawal process for all ERC20 and native token types.
     * @param childTokenAddr The address of the child token to withdraw.
     * @param receiver The address to withdraw the tokens to.
     * @param amount The amount of tokens to withdraw.
     *
     * Requirements:
     *
     * - `childTokenAddr` must not be the zero address.
     * - `receiver` must not be the zero address.
     * - `amount` must be greater than zero.
     * - `msg.value` must be greater than zero.
     * - `childToken` must exist.
     * - `childToken` must be mapped.
     * - `childToken` must have a the bridge set.
     */
    function _withdraw(address childTokenAddr, address receiver, uint256 amount) private whenNotPaused {
        if (childTokenAddr == address(0) || receiver == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (msg.value == 0) {
            revert NoGas();
        }

        address rootToken;
        if (childTokenAddr == NATIVE_IMX) {
            rootToken = _withdrawIMX(amount);
        } else if (childTokenAddr == wIMXToken) {
            rootToken = _withdrawWIMX(amount);
        } else if (childTokenAddr == childETHToken) {
            rootToken = _withdrawETH(amount);
        } else {
            rootToken = _withdrawERC20(rootToken, childTokenAddr, amount);
        }

        // Encode the message payload
        bytes memory payload = abi.encode(WITHDRAW_SIG, rootToken, msg.sender, receiver, amount);

        // Account for fee amount
        uint256 feeAmount = (childTokenAddr == NATIVE_IMX) ? msg.value - amount : msg.value;

        // Send the message to the bridge adaptor and up to root chain
        bridgeAdaptor.sendMessage{value: feeAmount}(payload, msg.sender);

        _emitWithdrawEvent(rootToken, childTokenAddr, msg.sender, receiver, amount);
    }

    function _withdrawIMX(uint256 amount) private returns (address) {
        if (msg.value < amount) {
            revert InsufficientValue();
        }
        return rootIMXToken;
    }

    function _withdrawETH(uint256 amount) private returns (address) {
        if (!IChildERC20(childETHToken).burn(msg.sender, amount)) {
            revert BurnFailed();
        }
        return NATIVE_ETH;
    }

    function _withdrawWIMX(uint256 amount) private returns (address) {
        // Calculate expected balance
        uint256 expectedBalance = address(this).balance + amount;

        IWIMX wIMX = IWIMX(wIMXToken);

        // Transfer to contract
        if (!wIMX.transferFrom(msg.sender, address(this), amount)) {
            revert TransferWIMXFailed();
        }

        // Withdraw
        wIMX.withdraw(amount);
        
        // Assert balance
        if (address(this).balance != expectedBalance) {
            revert BalanceInvariantCheckFailed(address(this).balance, expectedBalance);
        }

        return rootIMXToken;
    }

    function _withdrawERC20(address rootToken, address childToken, uint256 amount) private returns (address) {
        // Validate code existance
        if (address(childToken).code.length == 0) {
            revert EmptyTokenContract();
        }

        rootToken = IChildERC20(childToken).rootToken();
        
        // Assert mapping
        if (rootTokenToChildToken[rootToken] != address(childToken)) {
            revert NotMapped();
        }

        // A mapped token should never have root token unset
        if (rootToken == address(0)) {
            revert ZeroAddressRootToken();
        }

        // A mapped token should never have the bridge unset
        if (IChildERC20(childToken).bridge() != address(this)) {
            revert IncorrectBridgeAddress();
        }

        // Burn tokens
        if (!IChildERC20(childToken).burn(msg.sender, amount)) {
            revert BurnFailed();
        }

        return rootToken;
    }

    function _emitWithdrawEvent(address rootToken, address childToken, address sender, address receiver, uint256 amount)
        private
    {
        if (childToken == NATIVE_IMX) {
            emit ChildChainNativeIMXWithdraw(rootToken, sender, receiver, amount);
        } else if (childToken == wIMXToken) {
            emit ChildChainWrappedIMXWithdraw(rootToken, sender, receiver, amount);
        } else if (childToken == childETHToken) {
            emit ChildChainEthWithdraw(sender, receiver, amount);
        } else {
            emit ChildChainERC20Withdraw(rootToken, childToken, sender, receiver, amount);
        }
    }

    /**
     * @notice Private function to handle mapping of root ERC20 tokens to child ERC20 tokens.
     * @param data The data payload of the message.
     *
     * Requirements:
     *
     * - `rootToken` must not be the zero address.
     * - `rootToken` must not be the root IMX token.
     * - `rootToken` must not be native ETH.
     * - `rootToken` must not already be mapped.
     */
    function _mapToken(bytes calldata data) private {
        (, address rootToken, string memory name, string memory symbol, uint8 decimals) =
            abi.decode(data, (bytes32, address, string, string, uint8));

        if (rootToken == address(0)) {
            revert ZeroAddress();
        }

        if (address(rootToken) == rootIMXToken) {
            revert CantMapIMX();
        }

        if (address(rootToken) == NATIVE_ETH) {
            revert CantMapETH();
        }

        if (rootTokenToChildToken[rootToken] != address(0)) {
            revert AlreadyMapped();
        }

        // Deploy child chain token
        IChildERC20 childToken =
            IChildERC20(Clones.cloneDeterministic(childTokenTemplate, keccak256(abi.encodePacked(rootToken))));
        // Map token
        rootTokenToChildToken[rootToken] = address(childToken);

        // Intialize token
        childToken.initialize(rootToken, name, symbol, decimals);

        emit L2TokenMapped(rootToken, address(childToken));
    }

    /**
     * @notice Private function to handle depositing of ERC20 and native tokens to the child chain.
     * @param data The data payload of the message.
     *
     * Requirements:
     *
     * - `rootToken` must not be the zero address.
     * - `receiver` must not be the zero address.
     * - `childToken` must be mapped.
     * - `childToken` must exist.
     *
     */
    function _deposit(bytes calldata data) private {
        (address rootToken, address sender, address receiver, uint256 amount) =
            abi.decode(data, (address, address, address, uint256));

        if (rootToken == address(0) || receiver == address(0)) {
            revert ZeroAddress();
        }

        _emitDepositEventAndHandleTransfer(rootToken, rootTokenToChildToken[rootToken], sender, receiver, amount);
    }

    function _emitDepositEventAndHandleTransfer(
        address rootToken,
        address childToken,
        address sender,
        address receiver,
        uint256 amount
    ) private {
        if (rootToken == rootIMXToken) {
            Address.sendValue(payable(receiver), amount);
            emit IMXDeposit(rootToken, sender, receiver, amount);
            return;
        }

        if (childToken == address(0)) {
            revert NotMapped();
        }

        if (childToken.code.length == 0) {
            revert EmptyTokenContract();
        }

        if (!IChildERC20(childToken).mint(receiver, amount)) {
            revert MintFailed();
        }

        if (rootToken == NATIVE_ETH) {
            emit NativeEthDeposit(rootToken, address(childToken), sender, receiver, amount);
        } else {
            emit ChildChainERC20Deposit(rootToken, address(childToken), sender, receiver, amount);
        }
    }

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gapChildERC20Bridge;
}
