// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    IRootERC20Bridge,
    IERC20Metadata,
    IRootERC20BridgeEvents,
    IRootERC20BridgeErrors
} from "../interfaces/root/IRootERC20Bridge.sol";
import {IRootERC20BridgeAdaptor} from "../interfaces/root/IRootERC20BridgeAdaptor.sol";
import {IWETH} from "../interfaces/root/IWETH.sol";
import {BridgeRoles} from "../common/BridgeRoles.sol";

/**
 * @notice RootERC20Bridge is a bridge that allows ERC20 and native tokens to be bridged from the root chain to the child chain
 * and facilitates the withdrawals of ERC20 and native tokens from the child chain to the root chain.
 * @dev This contract is designed to be upgradeable.
 * @dev Follows a pattern of using a bridge adaptor to communicate with the child chain. This is because the underlying communication protocol may change,
 *      and also allows us to decouple vendor-specific messaging logic from the bridge logic.
 * @dev Because of this pattern, any checks or logic that is agnostic to the messaging protocol should be done in RootERC20Bridge.
 * @dev Any checks or logic that is specific to the underlying messaging protocol should be done in the bridge adaptor.
 * @dev Note that there is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
 */
contract RootERC20Bridge is IRootERC20Bridge, IRootERC20BridgeEvents, IRootERC20BridgeErrors, BridgeRoles {
    using SafeERC20 for IERC20Metadata;

    /// @dev leave this as the first param for the integration tests
    mapping(address => address) public rootTokenToChildToken;

    /// @notice Role identifier those who can update the cumulative IMX deposit limit.
    bytes32 public constant VARIABLE_MANAGER_ROLE = keccak256("VARIABLE_MANAGER");

    uint256 public constant UNLIMITED_DEPOSIT = 0;
    bytes32 public constant MAP_TOKEN_SIG = keccak256("MAP_TOKEN");
    bytes32 public constant DEPOSIT_SIG = keccak256("DEPOSIT");
    bytes32 public constant WITHDRAW_SIG = keccak256("WITHDRAW");
    address public constant NATIVE_ETH = address(0xeee);
    address public constant NATIVE_IMX = address(0xfff);

    IRootERC20BridgeAdaptor public rootBridgeAdaptor;
    /// @dev Used to verify source address in messages sent from child chain.
    string public childBridgeAdaptor;
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
    /// @dev The name of the chain that this bridge is connected to.
    string public childChain;
    /// @dev The maximum cumulative amount of IMX that can be deposited into the bridge.
    /// @dev A limit of zero indicates unlimited.
    uint256 public imxCumulativeDepositLimit;

    /**
     * @notice Initialization function for RootERC20Bridge.
     * @param newRoles Struct containing addresses of roles.
     * @param newRootBridgeAdaptor Address of StateSender to send bridge messages to, and receive messages from.
     * @param newChildERC20Bridge Address of child ERC20 bridge to communicate with.
     * @param newChildBridgeAdaptor Address of child bridge adaptor to communicate with (As a checksummed string).
     * @param newChildTokenTemplate Address of child token template to clone.
     * @param newRootIMXToken Address of ERC20 IMX on the root chain.
     * @param newRootWETHToken Address of ERC20 WETH on the root chain.
     * @param newChildChain Name of child chain.
     * @param newImxCumulativeDepositLimit The cumulative IMX deposit limit.
     * @dev Can only be called once.
     */
    function initialize(
        InitializationRoles memory newRoles,
        address newRootBridgeAdaptor,
        address newChildERC20Bridge,
        string memory newChildBridgeAdaptor,
        address newChildTokenTemplate,
        address newRootIMXToken,
        address newRootWETHToken,
        string memory newChildChain,
        uint256 newImxCumulativeDepositLimit
    ) public initializer {
        if (
            newRootBridgeAdaptor == address(0) || newChildERC20Bridge == address(0)
                || newChildTokenTemplate == address(0) || newRootIMXToken == address(0) || newRootWETHToken == address(0)
                || newRoles.defaultAdmin == address(0) || newRoles.pauser == address(0) || newRoles.unpauser == address(0)
                || newRoles.variableManager == address(0) || newRoles.adaptorManager == address(0)
        ) {
            revert ZeroAddress();
        }
        if (bytes(newChildBridgeAdaptor).length == 0) {
            revert InvalidChildERC20BridgeAdaptor();
        }
        if (bytes(newChildChain).length == 0) {
            revert InvalidChildChain();
        }

        __AccessControl_init();
        __Pausable_init();

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
        rootBridgeAdaptor = IRootERC20BridgeAdaptor(newRootBridgeAdaptor);
        childBridgeAdaptor = newChildBridgeAdaptor;
        childChain = newChildChain;
        imxCumulativeDepositLimit = newImxCumulativeDepositLimit;
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
     * @notice Updates the root bridge adaptor.
     * @param newRootBridgeAdaptor Address of new root bridge adaptor.
     * @dev Can only be called by ADAPTOR_MANAGER_ROLE.
     */
    function updateRootBridgeAdaptor(address newRootBridgeAdaptor) external onlyRole(ADAPTOR_MANAGER_ROLE) {
        if (newRootBridgeAdaptor == address(0)) {
            revert ZeroAddress();
        }
        emit NewRootBridgeAdaptor(address(rootBridgeAdaptor), newRootBridgeAdaptor);
        rootBridgeAdaptor = IRootERC20BridgeAdaptor(newRootBridgeAdaptor);
    }

    // TODO add updating of child bridge adaptor. Part of SMR-1908

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
     * @dev method to receive the ETH back from the WETH contract when it is unwrapped
     */
    receive() external payable whenNotPaused() {
        // Revert if sender is not the WETH token address
        if (msg.sender != rootWETHToken) {
            revert NonWrappedNativeTransfer();
        }
    }

    /**
     * @inheritdoc IRootERC20Bridge
     * @dev This is only callable by the root chain bridge adaptor.
     * @dev Validates `sourceAddress` is the child chain's bridgeAdaptor.
     */
    function onMessageReceive(string calldata messageSourceChain, string calldata sourceAddress, bytes calldata data)
        external
        override
        whenNotPaused
    {
        if (msg.sender != address(rootBridgeAdaptor)) {
            revert NotBridgeAdaptor();
        }
        if (!Strings.equal(messageSourceChain, childChain)) {
            revert InvalidSourceChain();
        }
        if (!Strings.equal(sourceAddress, childBridgeAdaptor)) {
            revert InvalidSourceAddress();
        }
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
     * @dev Note that there is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
     */
    function deposit(IERC20Metadata rootToken, uint256 amount) external payable override {
        _depositToken(rootToken, msg.sender, amount);
    }

    /**
     * @inheritdoc IRootERC20Bridge
     * @dev Note that there is undefined behaviour for bridging non-standard ERC20 tokens (e.g. rebasing tokens). Please approach such cases with great care.
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

        bytes memory payload =
            abi.encode(MAP_TOKEN_SIG, rootToken, rootToken.name(), rootToken.symbol(), rootToken.decimals());
        // TODO investigate using delegatecall to keep the axelar message sender as the bridge contract, since adaptor can change.
        rootBridgeAdaptor.sendMessage{value: msg.value}(payload, msg.sender);

        emit L1TokenMapped(address(rootToken), childToken);
        return childToken;
    }

    function _deposit(IERC20Metadata rootToken, address receiver, uint256 amount) private whenNotPaused {
        if (receiver == address(0) || address(rootToken) == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (msg.value == 0) {
            revert NoGas();
        }
        if (
            address(rootToken) == rootIMXToken && imxCumulativeDepositLimit != UNLIMITED_DEPOSIT
                && IERC20Metadata(rootIMXToken).balanceOf(address(this)) + amount > imxCumulativeDepositLimit
        ) {
            revert ImxDepositLimitExceeded();
        }

        // ETH, WETH and IMX do not need to be mapped since it should have been mapped on initialization
        // ETH also cannot be transferred since it was received in the payable function call
        // WETH is also not transferred here since it was earlier unwrapped to ETH

        // TODO We can call _mapToken here, but ordering in the GMP is not guaranteed.
        // Therefore, we need to decide how to handle this and it may be a UI decision to wait until map token message is executed on child chain.
        // Discuss this, and add this decision to the design doc.

        address childToken;
        uint256 feeAmount = msg.value;
        address payloadToken = address(rootToken);

        if (address(rootToken) == NATIVE_ETH) {
            feeAmount = msg.value - amount;
        } else if (address(rootToken) == rootWETHToken) {
            payloadToken = NATIVE_ETH;
        } else {
            if (address(rootToken) != rootIMXToken) {
                childToken = rootTokenToChildToken[address(rootToken)];
                if (childToken == address(0)) {
                    revert NotMapped();
                }
            }
            rootToken.safeTransferFrom(msg.sender, address(this), amount);
        }

        // Deposit sig, root token address, depositor, receiver, amount
        bytes memory payload = abi.encode(DEPOSIT_SIG, payloadToken, msg.sender, receiver, amount);

        // TODO investigate using delegatecall to keep the axelar message sender as the bridge contract, since adaptor can change.
        rootBridgeAdaptor.sendMessage{value: feeAmount}(payload, msg.sender);

        if (address(rootToken) == NATIVE_ETH) {
            emit NativeEthDeposit(address(rootToken), childETHToken, msg.sender, receiver, amount);
        } else if (address(rootToken) == rootWETHToken) {
            emit WETHDeposit(address(rootToken), childETHToken, msg.sender, receiver, amount);
        } else if (address(rootToken) == rootIMXToken) {
            emit IMXDeposit(address(rootToken), msg.sender, receiver, amount);
        } else {
            emit ChildChainERC20Deposit(address(rootToken), childToken, msg.sender, receiver, amount);
        }
    }

    function _withdraw(bytes memory data) private {
        (address rootToken, address withdrawer, address receiver, uint256 amount) =
            abi.decode(data, (address, address, address, uint256));
        address childToken;
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
        _executeTransfer(rootToken, childToken, withdrawer, receiver, amount);
    }

    function _executeTransfer(
        address rootToken,
        address childToken,
        address withdrawer,
        address receiver,
        uint256 amount
    ) internal whenNotPaused {
        // TODO when withdrawing ETH/WETH, this next section will also need to check for the withdrawal of WETH (i.e. rootToken == NATIVE_ETH || rootToken == CHILD_WETH)
        // Tests for this NATIVE_ETH branch not yet written. This should come as part of that PR.
        if (rootToken == NATIVE_ETH) {
            Address.sendValue(payable(receiver), amount);
            emit RootChainETHWithdraw(NATIVE_ETH, childToken, withdrawer, receiver, amount);
        } else {
            IERC20Metadata(rootToken).safeTransfer(receiver, amount);
            emit RootChainERC20Withdraw(rootToken, childToken, withdrawer, receiver, amount);
        }
        // slither-disable-next-line reentrancy-events
    }
}
