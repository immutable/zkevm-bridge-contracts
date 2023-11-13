// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {
    IChildERC20BridgeEvents,
    IChildERC20BridgeErrors,
    IChildERC20Bridge,
    IERC20Metadata
} from "../interfaces/child/IChildERC20Bridge.sol";
import {IChildERC20BridgeAdaptor} from "../interfaces/child/IChildERC20BridgeAdaptor.sol";
import {IChildERC20} from "../interfaces/child/IChildERC20.sol";

/**
 * @notice RootERC20Bridge is a bridge that allows ERC20 tokens to be transferred from the root chain to the child chain.
 * @dev This contract is designed to be upgradeable.
 * @dev Follows a pattern of using a bridge adaptor to communicate with the child chain. This is because the underlying communication protocol may change,
 *      and also allows us to decouple vendor-specific messaging logic from the bridge logic.
 * @dev Because of this pattern, any checks or logic that is agnostic to the messaging protocol should be done in RootERC20Bridge.
 * @dev Any checks or logic that is specific to the underlying messaging protocol should be done in the bridge adaptor.
 */
contract ChildERC20Bridge is
    AccessControlUpgradeable, // AccessControlUpgradeable inherits Initializable
    IChildERC20BridgeErrors,
    IChildERC20Bridge,
    IChildERC20BridgeEvents
{
    using SafeERC20 for IERC20Metadata;

    /// @dev leave this as the first param for the integration tests
    mapping(address => address) public rootTokenToChildToken;

    /**
     * ROLES
     */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant VARIABLE_MANAGER_ROLE = keccak256("VARIABLE_MANAGER_ROLE");
    bytes32 public constant ADAPTOR_MANAGER_ROLE = keccak256("ADAPTOR_MANAGER_ROLE");

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

    /**
     * @notice Initialization function for RootERC20Bridge.
     * @param newRoles Struct containing addresses of roles.
     * @param newBridgeAdaptor Address of StateSender to send deposit information to.
     * @param newRootERC20BridgeAdaptor Stringified address of root ERC20 bridge adaptor to communicate with.
     * @param newChildTokenTemplate Address of child token template to clone.
     * @param newRootChain A stringified representation of the chain that this bridge is connected to. Used for validation.
     * @param newRootIMXToken Address of ECR20 IMX on the root chain.
     * @dev Can only be called once.
     */
    function initialize(
        InitializationRoles memory newRoles,
        address newBridgeAdaptor,
        string memory newRootERC20BridgeAdaptor,
        address newChildTokenTemplate,
        string memory newRootChain,
        address newRootIMXToken
    ) public initializer {
        if (
            newBridgeAdaptor == address(0) || newChildTokenTemplate == address(0) || newRootIMXToken == address(0)
                || newRoles.defaultAdmin == address(0) || newRoles.pauser == address(0) || newRoles.unpauser == address(0)
                || newRoles.variableManager == address(0) || newRoles.adaptorManager == address(0)
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

        _grantRole(DEFAULT_ADMIN_ROLE, newRoles.defaultAdmin);
        _grantRole(PAUSER_ROLE, newRoles.pauser);
        _grantRole(UNPAUSER_ROLE, newRoles.unpauser);
        _grantRole(VARIABLE_MANAGER_ROLE, newRoles.variableManager);
        _grantRole(ADAPTOR_MANAGER_ROLE, newRoles.adaptorManager);

        rootERC20BridgeAdaptor = newRootERC20BridgeAdaptor;
        childTokenTemplate = newChildTokenTemplate;
        bridgeAdaptor = IChildERC20BridgeAdaptor(newBridgeAdaptor);
        rootChain = newRootChain;
        rootIMXToken = newRootIMXToken;

        IChildERC20 clonedETHToken =
            IChildERC20(Clones.cloneDeterministic(childTokenTemplate, keccak256(abi.encodePacked(NATIVE_ETH))));
        clonedETHToken.initialize(NATIVE_ETH, "Ethereum", "ETH", 18);
        childETHToken = address(clonedETHToken);
    }

    /**
     * @inheritdoc IChildERC20Bridge
     * @dev This is only callable by the child chain bridge adaptor.
     * @dev Validates `sourceAddress` is the root chain's bridgeAdaptor.
     */
    function onMessageReceive(string calldata messageSourceChain, string calldata sourceAddress, bytes calldata data)
        external
        override
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

    function withdraw(IChildERC20 childToken, uint256 amount) external payable {
        _withdraw(childToken, msg.sender, amount);
    }

    function withdrawTo(IChildERC20 childToken, address receiver, uint256 amount) external payable {
        _withdraw(childToken, receiver, amount);
    }

    function withdrawIMX(uint256 amount) external payable {
        _withdrawIMX(msg.sender, amount);
    }

    function withdrawIMXTo(address receiver, uint256 amount) external payable {
        _withdrawIMX(receiver, amount);
    }

    function _withdrawIMX(address receiver, uint256 amount) private {
        if (msg.value < amount) {
            revert InsufficientValue();
        }

        uint256 expectedBalance = address(this).balance - (msg.value - amount);

        _withdraw(IChildERC20(NATIVE_IMX), receiver, amount);

        if (address(this).balance != expectedBalance) {
            revert BalanceInvariantCheckFailed(address(this).balance, expectedBalance);
        }
    }

    function _withdraw(IChildERC20 childToken, address receiver, uint256 amount) private {
        if (address(childToken) == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        address rootToken;
        uint256 feeAmount = msg.value;

        if (address(childToken) == NATIVE_IMX) {
            feeAmount = msg.value - amount;
            rootToken = rootIMXToken;
        } else {
            if (address(childToken).code.length == 0) {
                revert EmptyTokenContract();
            }
            rootToken = childToken.rootToken();

            if (rootTokenToChildToken[rootToken] != address(childToken)) {
                revert NotMapped();
            }

            // A mapped token should never have root token unset
            if (rootToken == address(0)) {
                revert ZeroAddressRootToken();
            }

            // A mapped token should never have the bridge unset
            if (childToken.bridge() != address(this)) {
                revert IncorrectBridgeAddress();
            }

            if (!childToken.burn(msg.sender, amount)) {
                revert BurnFailed();
            }
        }

        // TODO Should we enforce receiver != 0? old poly contracts don't

        // Encode the message payload
        bytes memory payload = abi.encode(WITHDRAW_SIG, rootToken, msg.sender, receiver, amount);

        // Send the message to the bridge adaptor and up to root chain

        bridgeAdaptor.sendMessage{value: feeAmount}(payload, msg.sender);

        if (address(childToken) == NATIVE_IMX) {
            emit ChildChainNativeIMXWithdraw(rootToken, msg.sender, receiver, amount);
        } else {
            emit ChildChainERC20Withdraw(rootToken, address(childToken), msg.sender, receiver, amount);
        }
    }

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

        IChildERC20 childToken =
            IChildERC20(Clones.cloneDeterministic(childTokenTemplate, keccak256(abi.encodePacked(rootToken))));

        rootTokenToChildToken[rootToken] = address(childToken);
        childToken.initialize(rootToken, name, symbol, decimals);

        emit L2TokenMapped(rootToken, address(childToken));
    }

    function _deposit(bytes calldata data) private {
        (address rootToken, address sender, address receiver, uint256 amount) =
            abi.decode(data, (address, address, address, uint256));

        if (rootToken == address(0) || receiver == address(0)) {
            revert ZeroAddress();
        }

        address childToken;

        if (address(rootToken) != rootIMXToken) {
            if (address(rootToken) == NATIVE_ETH) {
                childToken = childETHToken;
            } else {
                childToken = rootTokenToChildToken[address(rootToken)];
                if (childToken == address(0)) {
                    revert NotMapped();
                }
            }

            if (address(childToken).code.length == 0) {
                revert EmptyTokenContract();
            }

            if (!IChildERC20(childToken).mint(receiver, amount)) {
                revert MintFailed();
            }

            if (address(rootToken) == NATIVE_ETH) {
                emit NativeEthDeposit(address(rootToken), childToken, sender, receiver, amount);
            } else {
                emit ChildChainERC20Deposit(address(rootToken), childToken, sender, receiver, amount);
            }
        } else {
            Address.sendValue(payable(receiver), amount);
            emit IMXDeposit(address(rootToken), sender, receiver, amount);
        }
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function updateBridgeAdaptor(address newBridgeAdaptor) external override {
        if (!(hasRole(VARIABLE_MANAGER_ROLE, msg.sender))) {
            revert NotVariableManager();
        }
        if (newBridgeAdaptor == address(0)) {
            revert ZeroAddress();
        }
        bridgeAdaptor = IChildERC20BridgeAdaptor(newBridgeAdaptor);
    }
}
