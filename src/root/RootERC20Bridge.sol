// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    IRootERC20Bridge,
    IERC20Metadata,
    IRootERC20BridgeEvents,
    IRootERC20BridgeErrors
} from "../interfaces/root/IRootERC20Bridge.sol";
import {IRootBridgeAdaptor} from "../interfaces/root/IRootBridgeAdaptor.sol";
import {IWETH} from "../interfaces/root/IWETH.sol";
import {BridgeRoles} from "../common/BridgeRoles.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Root ERC20 Bridge
 * @notice An ERC20 bridge contract for the root chain, which enables bridging of standard ERC20 tokens, ETH, wETH, IMX and wIMX from the root chain to the child chain and back.
 * @dev Features:
 *      - Map ERC20 tokens from the root chain to the child chain, so as to enable subsequent bridging of the token.
 *      - Deposit ERC20 tokens, native ETH, wrapped ETH and IMX from the root chain to the child chain.
 *      - Withdraw ERC20 tokens, ETH, and IMX from the child chain to the root chain.
 *      - Set and manage a limit to the amount of IMX that can be deposited into the bridge.
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
 *      - An account with a VARIABLE_MANAGER_ROLE can update the cumulative IMX deposit limit.
 *      - An account with an ADAPTOR_MANAGER_ROLE can update the root bridge adaptor address.
 *      - An account with a DEFAULT_ADMIN_ROLE can grant and revoke roles.
 *
 * @dev Caution:
 *      - When depositing IMX (L1 -> L2) it's crucial to make sure that the receiving address on the child chain,
 *        if it's a contract, has a receive or fallback function that allows it to accept native IMX on the child chain.
 *        If this isn't the case, the transaction on the child chain could revert, potentially locking the user's funds indefinitely.
 *      - There is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
 *      - The initialize function is susceptible to front running, so precautions should be taken to account for this scenario.
 *
 * @dev Note:
 *      - This is an upgradeable contract that should be operated behind OpenZeppelin's TransparentUpgradeableProxy.
 */
contract RootERC20Bridge is
    BridgeRoles,
    ReentrancyGuardUpgradeable,
    IRootERC20Bridge,
    IRootERC20BridgeEvents,
    IRootERC20BridgeErrors
{
    using SafeERC20 for IERC20Metadata;

    /// @dev leave this as the first param for the integration tests.
    mapping(address => address) public rootTokenToChildToken;

    /// @notice Role identifier those who can update the cumulative IMX deposit limit.
    bytes32 public constant VARIABLE_MANAGER_ROLE = keccak256("VARIABLE_MANAGER");

    uint256 public constant UNLIMITED_DEPOSIT = 0;
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant DEPOSIT_SIG = keccak256("DEPOSIT");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");
    address public constant NATIVE_ETH = address(0xeee);
    address public constant NATIVE_IMX = address(0xfff);

    /// @dev The address of the bridge adapter used to send and receive messages to and from the child chain.
    IRootBridgeAdaptor public rootBridgeAdaptor;

    /// @dev The address that will be minting tokens on the child chain.
    address public childERC20Bridge;
    /// @dev The address of the token template that will be cloned to create tokens on the child chain.
    address public childTokenTemplate;
    /// @dev The address of the IMX ERC20 token on L1.
    address public rootIMXToken;
    /// @dev The address of the ETH ERC20 token on L2.
    address public childETHToken;
    /// @dev The address of the wETH ERC20 token on L1.
    address public rootWETHToken;
    /// @dev The maximum cumulative amount of IMX that can be deposited into the bridge.
    /// @dev A limit of zero indicates unlimited.
    uint256 public imxCumulativeDepositLimit;
    /// @dev Address of the authorized initializer.
    address public immutable initializerAddress;

    /**
     * @notice Modifier to ensure that the caller is the registered root bridge adaptor.
     */
    modifier onlyBridgeAdaptor() {
        if (msg.sender != address(rootBridgeAdaptor)) {
            revert NotBridgeAdaptor();
        }
        _;
    }

    /**
     * @notice Constructs the RootERC20Bridge contract.
     * @param _initializerAddress The address of the authorized initializer.
     */
    constructor(address _initializerAddress) {
        if (_initializerAddress == address(0)) {
            revert ZeroAddress();
        }
        initializerAddress = _initializerAddress;
    }

    /**
     * @notice Initialization function for RootERC20Bridge.
     * @param newRoles Struct containing addresses of roles.
     * @param newRootBridgeAdaptor Address of adaptor to send bridge messages to, and receive messages from.
     * @param newChildERC20Bridge Address of child ERC20 bridge to communicate with.
     * @param newChildTokenTemplate Address of child token template to clone.
     * @param newRootIMXToken Address of ERC20 IMX on the root chain.
     * @param newRootWETHToken Address of ERC20 WETH on the root chain.
     * @param newImxCumulativeDepositLimit The cumulative IMX deposit limit.
     * @dev Can only be called once.
     */
    function initialize(
        InitializationRoles memory newRoles,
        address newRootBridgeAdaptor,
        address newChildERC20Bridge,
        address newChildTokenTemplate,
        address newRootIMXToken,
        address newRootWETHToken,
        uint256 newImxCumulativeDepositLimit
    ) external virtual initializer {
        __RootERC20Bridge_init(
            newRoles,
            newRootBridgeAdaptor,
            newChildERC20Bridge,
            newChildTokenTemplate,
            newRootIMXToken,
            newRootWETHToken,
            newImxCumulativeDepositLimit
        );
    }

    /**
     * @notice Initialization function for RootERC20Bridge.
     * @param newRoles Struct containing addresses of roles.
     * @param newRootBridgeAdaptor Address of StateSender to send bridge messages to, and receive messages from.
     * @param newChildERC20Bridge Address of child ERC20 bridge to communicate with.
     * @param newChildTokenTemplate Address of child token template to clone.
     * @param newRootIMXToken Address of ERC20 IMX on the root chain.
     * @param newRootWETHToken Address of ERC20 WETH on the root chain.
     * @param newImxCumulativeDepositLimit The cumulative IMX deposit limit.
     */
    function __RootERC20Bridge_init(
        InitializationRoles memory newRoles,
        address newRootBridgeAdaptor,
        address newChildERC20Bridge,
        address newChildTokenTemplate,
        address newRootIMXToken,
        address newRootWETHToken,
        uint256 newImxCumulativeDepositLimit
    ) internal {
        if (msg.sender != initializerAddress) {
            revert UnauthorizedInitializer();
        }
        if (
            newRootBridgeAdaptor == address(0) || newChildERC20Bridge == address(0)
                || newChildTokenTemplate == address(0) || newRootIMXToken == address(0) || newRootWETHToken == address(0)
                || newRoles.defaultAdmin == address(0) || newRoles.pauser == address(0) || newRoles.unpauser == address(0)
                || newRoles.variableManager == address(0) || newRoles.adaptorManager == address(0)
        ) {
            revert ZeroAddress();
        }

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, newRoles.defaultAdmin);
        _grantRole(PAUSER_ROLE, newRoles.pauser);
        _grantRole(UNPAUSER_ROLE, newRoles.unpauser);
        _grantRole(VARIABLE_MANAGER_ROLE, newRoles.variableManager);
        _grantRole(ADAPTOR_MANAGER_ROLE, newRoles.adaptorManager);

        childERC20Bridge = newChildERC20Bridge;
        childTokenTemplate = newChildTokenTemplate;
        rootIMXToken = newRootIMXToken;
        rootWETHToken = newRootWETHToken;
        childETHToken = Clones.predictDeterministicAddress(
            childTokenTemplate, keccak256(abi.encodePacked(NATIVE_ETH)), childERC20Bridge
        );
        rootBridgeAdaptor = IRootBridgeAdaptor(newRootBridgeAdaptor);
        imxCumulativeDepositLimit = newImxCumulativeDepositLimit;

        // Map the supported tokens by default
        rootTokenToChildToken[rootIMXToken] = rootIMXToken;
        rootTokenToChildToken[NATIVE_ETH] = NATIVE_ETH;
        rootTokenToChildToken[rootWETHToken] = NATIVE_ETH;
    }

    /**
     * @inheritdoc IRootERC20Bridge
     */
    function revokeVariableManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(VARIABLE_MANAGER_ROLE, account);
    }

    /**
     * @inheritdoc IRootERC20Bridge
     */
    function grantVariableManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(VARIABLE_MANAGER_ROLE, account);
    }

    /**
     * @inheritdoc IRootERC20Bridge
     */
    function updateRootBridgeAdaptor(address newRootBridgeAdaptor) external onlyRole(ADAPTOR_MANAGER_ROLE) {
        if (newRootBridgeAdaptor == address(0)) {
            revert ZeroAddress();
        }
        emit RootBridgeAdaptorUpdated(address(rootBridgeAdaptor), newRootBridgeAdaptor);
        rootBridgeAdaptor = IRootBridgeAdaptor(newRootBridgeAdaptor);
    }

    /**
     * @notice Updates the IMX deposit limit.
     * @param newImxCumulativeDepositLimit The new cumulative IMX deposit limit.
     * @dev Can only be called by VARIABLE_MANAGER_ROLE.
     * @dev The limit can decrease, but it can never decrease to below the contract's IMX balance.
     */
    function updateImxCumulativeDepositLimit(uint256 newImxCumulativeDepositLimit)
        external
        onlyRole(VARIABLE_MANAGER_ROLE)
    {
        if (
            newImxCumulativeDepositLimit != UNLIMITED_DEPOSIT
                && newImxCumulativeDepositLimit < IERC20Metadata(rootIMXToken).balanceOf(address(this))
        ) {
            revert ImxDepositLimitTooLow();
        }
        emit NewImxDepositLimit(imxCumulativeDepositLimit, newImxCumulativeDepositLimit);
        imxCumulativeDepositLimit = newImxCumulativeDepositLimit;
    }

    /**
     * @notice Method to receive ETH back from the WETH contract when it is unwrapped
     * @dev When a user deposits wETH, it must first be unwrapped.
     *      This allows the bridge to store the underlying native ETH, rather than the wrapped version.
     *      The unwrapping is done through the WETH contract's `withdraw()` function, which sends the native ETH to this bridge contract.
     *      The only reason this `receive()` function is needed is for this process, hence the validation ensures that the sender is the WETH contract.
     */
    receive() external payable {
        // Revert if sender is not the WETH token address
        if (msg.sender != rootWETHToken) {
            revert NonWrappedNativeTransfer();
        }
    }

    /**
     * @inheritdoc IRootERC20Bridge
     * @dev This is only callable by the root chain bridge adaptor.
     *      This method assumes that the adaptor will have performed all
     *     validations relating to the source of the message, prior to calling this method.
     */
    function onMessageReceive(bytes calldata data) external override whenNotPaused onlyBridgeAdaptor {
        if (data.length <= 32) {
            // Data must always be greater than 32.
            // 32 bytes for the signature, and at least some information for the payload
            revert InvalidData("Data too short");
        }

        if (bytes32(data[:32]) == WITHDRAW_SIG) {
            _withdraw(data[32:]);
        } else {
            revert InvalidData("Unsupported action signature");
        }
    }

    /**
     * @inheritdoc IRootERC20Bridge
     * @dev Note that there is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
     */
    function mapToken(IERC20Metadata rootToken) external payable override whenNotPaused returns (address) {
        return _mapToken(rootToken);
    }

    /**
     * @inheritdoc IRootERC20Bridge
     */
    function depositETH(uint256 amount) external payable {
        _depositETH(msg.sender, amount);
    }

    /**
     * @inheritdoc IRootERC20Bridge
     */
    function depositToETH(address receiver, uint256 amount) external payable {
        _depositETH(receiver, amount);
    }

    /**
     * @inheritdoc IRootERC20Bridge
     * @dev Caution:
     *      - When depositing IMX, it's crucial to make sure that the receiving address (`msg.sender`) on the child chain,
     *        if it's a contract, has a receive or fallback function that allows it to accept native IMX.
     *        If this isn't the case, the transaction on the child chain could revert, potentially locking the user's funds indefinitely.
     *      - Note that there is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
     */
    function deposit(IERC20Metadata rootToken, uint256 amount) external payable override {
        _depositToken(rootToken, msg.sender, amount);
    }

    /**
     * @inheritdoc IRootERC20Bridge
     * @dev Caution:
     *      - When depositing IMX, it's crucial to make sure that the receiving address (`receiver`) on the child chain,
     *        if it's a contract, has a receive or fallback function that allows it to accept native IMX.
     *        If this isn't the case, the transaction on the child chain could revert, potentially locking the user's funds indefinitely.
     *      - Note that there is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
     */
    function depositTo(IERC20Metadata rootToken, address receiver, uint256 amount) external payable override {
        _depositToken(rootToken, receiver, amount);
    }

    function _depositETH(address receiver, uint256 amount) private {
        if (msg.value < amount) {
            revert InsufficientValue();
        }

        uint256 expectedBalance = address(this).balance - (msg.value - amount);

        _deposit(IERC20Metadata(NATIVE_ETH), receiver, amount);

        // invariant check to ensure that the root native balance has increased by the amount deposited
        if (address(this).balance != expectedBalance) {
            revert BalanceInvariantCheckFailed(address(this).balance, expectedBalance);
        }
    }

    function _depositToken(IERC20Metadata rootToken, address receiver, uint256 amount) private {
        if (address(rootToken) == rootWETHToken) {
            _depositWrappedETH(receiver, amount);
        } else {
            _depositERC20(rootToken, receiver, amount);
        }
    }

    function _depositWrappedETH(address receiver, uint256 amount) private {
        uint256 expectedBalance = address(this).balance + amount;

        IERC20Metadata erc20WETH = IERC20Metadata(rootWETHToken);

        erc20WETH.safeTransferFrom(msg.sender, address(this), amount);
        IWETH(rootWETHToken).withdraw(amount);

        // invariant check to ensure that the root native balance has increased by the amount deposited
        if (address(this).balance != expectedBalance) {
            revert BalanceInvariantCheckFailed(address(this).balance, expectedBalance);
        }
        _deposit(IERC20Metadata(rootWETHToken), receiver, amount);
    }

    function _depositERC20(IERC20Metadata rootToken, address receiver, uint256 amount) private {
        uint256 expectedBalance = rootToken.balanceOf(address(this)) + amount;
        _deposit(rootToken, receiver, amount);
        // invariant check to ensure that the root token balance has increased by the amount deposited
        // slither-disable-next-line incorrect-equality
        if (rootToken.balanceOf(address(this)) != expectedBalance) {
            revert BalanceInvariantCheckFailed(rootToken.balanceOf(address(this)), expectedBalance);
        }
    }

    function _mapToken(IERC20Metadata rootToken) private returns (address) {
        if (msg.value == 0) {
            revert NoGas();
        }
        if (address(rootToken) == address(0)) {
            revert ZeroAddress();
        }
        if (address(rootToken) == rootIMXToken) {
            revert CantMapIMX();
        }

        if (address(rootToken) == NATIVE_ETH) {
            revert CantMapETH();
        }

        if (address(rootToken) == rootWETHToken) {
            revert CantMapWETH();
        }

        if (rootTokenToChildToken[address(rootToken)] != address(0)) {
            revert AlreadyMapped();
        }

        address childBridge = childERC20Bridge;

        address childToken =
            Clones.predictDeterministicAddress(childTokenTemplate, keccak256(abi.encodePacked(rootToken)), childBridge);

        rootTokenToChildToken[address(rootToken)] = childToken;

        (string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals) = _getTokenDetails(rootToken);

        bytes memory payload = abi.encode(MAP_TOKEN_SIG, rootToken, tokenName, tokenSymbol, tokenDecimals);
        rootBridgeAdaptor.sendMessage{value: msg.value}(payload, msg.sender);

        emit L1TokenMapped(address(rootToken), childToken);
        return childToken;
    }

    function _deposit(IERC20Metadata rootToken, address receiver, uint256 amount)
        private
        nonReentrant
        whenNotPaused
        wontIMXOverflow(address(rootToken), amount)
    {
        if (receiver == address(0) || address(rootToken) == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (msg.value == 0) {
            revert NoGas();
        }
        // ETH, WETH and IMX do not need to be mapped since it should have been mapped on initialization
        if (rootTokenToChildToken[address(rootToken)] == address(0)) {
            revert NotMapped();
        }

        // We can call _mapToken here, but ordering in the GMP is not guaranteed.
        // Therefore, we need to decide how to handle this and it may be a UI decision to wait until map token message is executed on child chain.
        // Discuss this, and add this decision to the design doc.

        address payloadToken = (address(rootToken) == rootWETHToken) ? NATIVE_ETH : address(rootToken);

        // Deposit sig, root token address, depositor, receiver, amount
        bytes memory payload = abi.encode(DEPOSIT_SIG, payloadToken, msg.sender, receiver, amount);

        // Adjust for fee amount on native transfers
        uint256 feeAmount = (address(rootToken) == NATIVE_ETH) ? msg.value - amount : msg.value;

        // Send message to child chain
        rootBridgeAdaptor.sendMessage{value: feeAmount}(payload, msg.sender);

        // Emit the appropriate deposit event
        _transferTokensAndEmitEvent(address(rootToken), receiver, amount);
    }

    /**
     * @notice Private helper function to emit the appropriate deposit event and execute transfer if rootIMX or rootERC20
     */
    function _transferTokensAndEmitEvent(address rootToken, address receiver, uint256 amount) private {
        // ETH also cannot be transferred since it was received in the payable function call
        if (rootToken == NATIVE_ETH) {
            emit NativeEthDeposit(rootToken, childETHToken, msg.sender, receiver, amount);
            // WETH is also not transferred here since it was earlier unwrapped to ETH
        } else if (rootToken == rootWETHToken) {
            emit WETHDeposit(rootToken, childETHToken, msg.sender, receiver, amount);
        } else if (rootToken == rootIMXToken) {
            emit IMXDeposit(rootToken, msg.sender, receiver, amount);
            IERC20Metadata(rootToken).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            emit ChildChainERC20Deposit(rootToken, rootTokenToChildToken[rootToken], msg.sender, receiver, amount);
            IERC20Metadata(rootToken).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _withdraw(bytes memory data) internal virtual {
        (address rootToken, address childToken, address withdrawer, address receiver, uint256 amount) =
            _decodeAndValidateWithdrawal(data);
        _executeTransfer(rootToken, childToken, withdrawer, receiver, amount);
    }

    function _decodeAndValidateWithdrawal(bytes memory data)
        internal
        view
        returns (address rootToken, address childToken, address withdrawer, address receiver, uint256 amount)
    {
        (rootToken, withdrawer, receiver, amount) = abi.decode(data, (address, address, address, uint256));

        if (address(rootToken) == address(0)) {
            revert ZeroAddress();
        }

        if (rootToken == rootIMXToken) {
            childToken = NATIVE_IMX;
        } else if (rootToken == NATIVE_ETH) {
            childToken = childETHToken;
        } else {
            childToken = rootTokenToChildToken[rootToken];
            if (childToken == address(0)) {
                revert NotMapped();
            }
        }
    }

    function _executeTransfer(
        address rootToken,
        address childToken,
        address withdrawer,
        address receiver,
        uint256 amount
    ) internal whenNotPaused {
        if (rootToken == NATIVE_ETH) {
            Address.sendValue(payable(receiver), amount);
            emit RootChainETHWithdraw(NATIVE_ETH, childToken, withdrawer, receiver, amount);
        } else {
            IERC20Metadata(rootToken).safeTransfer(receiver, amount);
            emit RootChainERC20Withdraw(rootToken, childToken, withdrawer, receiver, amount);
        }
    }

    function _getTokenDetails(IERC20Metadata token) private view returns (string memory, string memory, uint8) {
        string memory tokenName;
        try token.name() returns (string memory name) {
            tokenName = name;
        } catch {
            revert TokenNotSupported();
        }

        string memory tokenSymbol;
        try token.symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            revert TokenNotSupported();
        }

        uint8 tokenDecimals;
        try token.decimals() returns (uint8 decimals) {
            tokenDecimals = decimals;
        } catch {
            revert TokenNotSupported();
        }

        return (tokenName, tokenSymbol, tokenDecimals);
    }

    modifier wontIMXOverflow(address rootToken, uint256 amount) {
        // Assert whether the deposit is root IMX
        address imxToken = rootIMXToken;
        uint256 depositLimit = imxCumulativeDepositLimit;
        if (rootToken == imxToken && depositLimit != UNLIMITED_DEPOSIT) {
            // Based on the balance of this contract, check if the deposit will exceed the cumulative limit
            if (IERC20Metadata(imxToken).balanceOf(address(this)) + amount > depositLimit) {
                revert ImxDepositLimitExceeded();
            }
        }
        _;
    }

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gapRootERC20Bridge;
}
