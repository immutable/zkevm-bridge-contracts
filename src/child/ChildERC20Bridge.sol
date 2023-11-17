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
 * @notice ChildERC20Bridge is a bridge that handles the depositing ERC20 and native tokens to the child chain from the rootchain
 * and facilates the withdrawals of ERC20 and native tokens from the child chain to the rootchain.
 * @dev This contract is designed to be upgradeable.
 * @dev Follows a pattern of using a bridge adaptor to communicate with the root chain. This is because the underlying communication protocol may change,
 *      and also allows us to decouple vendor-specific messaging logic from the bridge logic.
 * @dev Because of this pattern, any checks or logic that is agnostic to the messaging protocol should be done in ChildERC20Bridge.
 * @dev Any checks or logic that is specific to the underlying messaging protocol should be done in the bridge adaptor.
 */
contract ChildERC20Bridge is IChildERC20BridgeErrors, IChildERC20Bridge, IChildERC20BridgeEvents, BridgeRoles {
    /// @dev leave this as the first param for the integration tests
    mapping(address => address) public rootTokenToChildToken;

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
                || newRoles.adaptorManager == address(0) || newWIMXToken == address(0)
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
    }

    /**
     * @inheritdoc IChildERC20Bridge
     */
    function updateBridgeAdaptor(address newBridgeAdaptor) external override onlyRole(ADAPTOR_MANAGER_ROLE) {
        if (newBridgeAdaptor == address(0)) {
            revert ZeroAddress();
        }
        emit BridgeAdaptorUpdated(address(bridgeAdaptor), newBridgeAdaptor);
        bridgeAdaptor = IChildERC20BridgeAdaptor(newBridgeAdaptor);
    }

    /**
     * @notice Fallback function on receiving native IMX from WIMX contract.
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
        uint256 feeAmount = msg.value;
        if (childTokenAddr == NATIVE_IMX) {
            // Native IMX.
            if (msg.value < amount) {
                revert InsufficientValue();
            }

            feeAmount = msg.value - amount;
            rootToken = rootIMXToken;
        } else if (childTokenAddr == wIMXToken) {
            // Wrapped IMX.
            // Transfer and unwrap IMX.
            uint256 expectedBalance = address(this).balance + amount;

            IWIMX wIMX = IWIMX(wIMXToken);
            if (!wIMX.transferFrom(msg.sender, address(this), amount)) {
                revert TransferWIMXFailed();
            }
            wIMX.withdraw(amount);

            if (address(this).balance != expectedBalance) {
                revert BalanceInvariantCheckFailed(address(this).balance, expectedBalance);
            }

            rootToken = rootIMXToken;
        } else if (childTokenAddr == childETHToken) {
            // Wrapped ETH.
            IChildERC20 childToken = IChildERC20(childTokenAddr);
            rootToken = NATIVE_ETH;

            if (!childToken.burn(msg.sender, amount)) {
                revert BurnFailed();
            }
        } else {
            // Other ERC20 Tokens
            IChildERC20 childToken = IChildERC20(childTokenAddr);

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

        // Encode the message payload
        bytes memory payload = abi.encode(WITHDRAW_SIG, rootToken, msg.sender, receiver, amount);

        // Send the message to the bridge adaptor and up to root chain
        bridgeAdaptor.sendMessage{value: feeAmount}(payload, msg.sender);

        if (childTokenAddr == NATIVE_IMX) {
            emit ChildChainNativeIMXWithdraw(rootToken, msg.sender, receiver, amount);
        } else if (childTokenAddr == wIMXToken) {
            emit ChildChainWrappedIMXWithdraw(rootToken, msg.sender, receiver, amount);
        } else if (childTokenAddr == childETHToken) {
            emit ChildChainEthWithdraw(msg.sender, receiver, amount);
        } else {
            emit ChildChainERC20Withdraw(rootToken, childTokenAddr, msg.sender, receiver, amount);
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

        IChildERC20 childToken;
        if (rootToken != rootIMXToken) {
            if (rootToken == NATIVE_ETH) {
                childToken = IChildERC20(childETHToken);
            } else {
                childToken = IChildERC20(rootTokenToChildToken[rootToken]);
                if (address(childToken) == address(0)) {
                    revert NotMapped();
                }
            }

            if (address(childToken).code.length == 0) {
                revert EmptyTokenContract();
            }

            if (!childToken.mint(receiver, amount)) {
                revert MintFailed();
            }

            if (rootToken == NATIVE_ETH) {
                emit NativeEthDeposit(rootToken, address(childToken), sender, receiver, amount);
            } else {
                emit ChildChainERC20Deposit(rootToken, address(childToken), sender, receiver, amount);
            }
        } else {
            Address.sendValue(payable(receiver), amount);
            emit IMXDeposit(rootToken, sender, receiver, amount);
        }
    }
}
