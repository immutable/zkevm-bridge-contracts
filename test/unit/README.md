# Test Plan
This document outlines the tests associated with this project. It is currently not complete as there are capabilities that are still under development. In addition, the document covers unit testing only and does not cover integration test scenarios.

## Root ERC20 Bridge
**Contract**: [RootERC20Bridge.sol](../../src/root/RootERC20Bridge.sol)
**Test Contracts**: [RootERC20Bridge.t.sol](./root/RootERC20Bridge.t.sol), [RootERC20BridgeWithdraw.t.sol](./root/withdrawals/RootERC20BridgeWithdraw.t.sol) 

### Initialization
| Test                                                    | Description                                                                           | Happy Path |
|---------------------------------------------------------|---------------------------------------------------------------------------------------|------------|
| `test_InitializeBridge`                                 | Test initialization of the bridge                                                     | Yes        |
| `test_RevertIf_InitializeTwice`                         | Should revert if initialized twice                                                    | No         |
| `test_RevertIf_InitializeWithAZeroAddressAll`           | Should revert if initialized with a zero address for all arguments                    | No         |
| `test_RevertIf_InitializeWithAZeroAddressChildBridge`   | Should revert if initialized with a zero address for the child bridge argument        | No         |
| `test_RevertIf_InitializeWithAZeroAddressIMXToken`      | Should revert if initialized with a zero address for the IMX token argument           | No         |
| `test_RevertIf_InitializeWithAZeroAddressRootAdapter`   | Should revert if initialized with a zero address for the root bridge adapter argument | No         |
| `test_RevertIf_InitializeWithAZeroAddressTokenTemplate` | Should revert if initialized with a zero address for the token template argument      | No         |
| `test_RevertIf_InitializeWithAZeroAddressWETHToken`     | Should revert if initialized with a zero address for the WETH token argument          | No         |
| `test_RevertIf_InitializeWithEmptyChildAdapter`         | Should revert if initialized with an empty child adapter argument                     | No         |

### Map Token
| Test                                          | Description                                                               | Happy Path |
|-----------------------------------------------|---------------------------------------------------------------------------|------------|
| `test_mapToken_SetsTokenMapping`              | Verifies that the mapToken function sets the token mapping.               | Yes        |
| `test_mapToken_CallsAdaptor`                  | Verifies that the mapToken function calls the bridge adapter              | Yes        |
| `test_mapToken_EmitsTokenMappedEvent`         | Verifies that the mapToken function emits a `TokenMappedEvent` event.     | Yes        |
| `test_RevertIf_mapTokenCalledTwice`           | Should revert if the mapToken function is called twice for the same token | No         |
| `test_RevertIf_mapTokenCalledWithETHAddress`  | Should revert if the mapToken function is called for native ETH           | No         |
| `test_RevertIf_mapTokenCalledWithIMXAddress`  | Should revert if the mapToken function is called for IMX                  | No         |
| `test_RevertIf_mapTokenCalledWithZeroAddress` | Should revert if the mapToken function is called with a zero address      | No         |

### Deposits
#### Standard ERC20 Tokens

| Test                                                        | Description                                                                                    | Happy Path |
|-------------------------------------------------------------|------------------------------------------------------------------------------------------------|------------|
| `test_depositCallsSendMessage`                              | Calls the send message function when depositing                                                | Yes        |
| `test_depositEmitsChildChainERC20DepositEvent`              | Emits the child chain ERC20 deposit event when depositing an ERC20 token                       | Yes        |
| `test_depositTransfersToken`                                | Verifies that the deposit function transfers the specified token to the specified child chain. | Yes        |
| `test_depositToCallsSendMessage`                            | Calls the send message function when depositing to a child chain account                       | Yes        |
| `test_depositToEmitsChildChainERC20DepositEvent`            | Verifies that the depositToETH function emits a ChildChainERC20DepositEven event.              | Yes        |
| `test_depositToTransfersToken`                              | Verifies that the depositToETH function transfers the specified token to the child chain.      | Yes        |
| `test_RevertIf_depositAmountIsZero`                         | Should revert if the deposit amount is zero                                                    | No         |
| `test_RevertIf_depositCalledWhenTokenApprovalNotProvided`   | Should revert if the deposit function is called when token approval is not provided            | No         |
| `test_RevertIf_depositCalledWithUnmappedToken`              | Should revert if the deposit function is called with an unmapped token                         | No         |
| `test_RevertIf_depositCalledWithZeroAddress`                | Should revert if the deposit function is called with a zero address                            | No         |
| `test_RevertIf_depositToAmountIsZero`                       | Should revert if the depositTo amount is zero                                                  | No         |
| `test_RevertIf_depositToCalledWhenTokenApprovalNotProvided` | Should revert if the depositTo function is called when token approval is not provided          | No         |
| `test_RevertIf_depositToCalledWithUnmappedToken`            | Should revert if the depositTo function is called with an unmapped token                       | No         |
| `test_RevertIf_depositToCalledWithZeroAddress`              | Should revert if the depositTo function is called with a zero address                          | No         |

#### IMX Token

| Test                                                 | Description                                                                                            | Happy Path |
|------------------------------------------------------|--------------------------------------------------------------------------------------------------------|------------|
| `test_depositIMXEmitsIMXDepositEvent`                | Emits the IMX deposit event when depositing IMX                                                        | Yes        |
| `test_deposit_whenSettingImxDepositLimitToUnlimited` | Verifies that the deposit function can still be called when the IMX deposit limit is set to unlimited. | Yes        |
| `test_depositToIMXEmitsIMXDepositEvent`              | Verifies that the depositToETH function emits a IMXDepositEven event.                                  | Yes        |
| `test_depositToWETHEmitsWETHDepositEvent`            | Verifies that the depositToETH function emits a WETHDepositEven event when depositing WETH.            | Yes        |
| `test_depositToWETHTransfersToken`                   | Verifies that the depositToETH function transfers WETH to the child chain.                             | Yes        |
| `test_RevertsIf_IMXDepositLimitExceeded`             | Should revert if the IMX deposit limit is exceeded                                                     | No         |
| `test_RevertsIf_IMXDepositLimitTooLow`               | Should revert if the IMX deposit limit is too low                                                      | No         |

#### ETH (Native and Wrapped)

| Test                                          | Description                                                                                 | Happy Path |
|-----------------------------------------------|---------------------------------------------------------------------------------------------|------------|
| `test_depositETHCallsSendMessage`             | Calls the send message function when depositing ETH                                         | Yes        |
| `test_depositETHEmitsNativeEthDepositEvent`   | Emits the native ETH deposit event when depositing ETH                                      | Yes        |
| `test_depositTransfersNativeAsset`            | Verifies that the deposit function transfers the native asset to the specified child chain. | Yes        |
| `test_depositToETHCallsSendMessage`           | Verifies that the depositToETH function calls the sendMessage function.                     | Yes        |
| `test_depositToETHEmitsNativeEthDepositEvent` | Verifies that the depositToETH function emits a NativeEthDepositEven event.                 | Yes        |
| `test_depositToTransfersNativeAsset`          | Verifies that the depositToETH function transfers the native asset to the child chain.      | Yes        |
| `test_RevertIf_depositETHAmountIsZero`        | Should revert if the depositETH amount is zero                                              | No         |
| `test_RevertIf_depositETHInsufficientValue`   | Should revert if the depositETH function is called with insufficient value                  | No         |
| `test_RevertIf_depositToETHAmountIsZero`      | Should revert if the depositToETH amount is zero                                            | No         |
| `test_RevertIf_depositToETHInsufficientValue` | Should revert if the depositToETH function is called with insufficient value                | No         |
| `test_depositWETHCallsSendMessage`            | Verifies that the depositWETH function calls the sendMessage function.                      | Yes        |
| `test_depositWETHEmitsNativeDepositEvent`     | Verifies that the depositWETH function emits a NativeDepositEven event.                     | Yes        |
| `test_depositWETHTransfersToken`              | Verifies that the depositWETH function transfers WETH to the child chain.                   | Yes        |


### Withdrawal
#### Standard ERC20 Tokens

| Test                                                                       | Description                                                                                               | Happy Path |
|----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|------------|
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEvent`                   | Emits a `RootChainERC20WithdrawEvent` when a message is received.                                         | Yes        |
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEvent_DifferentReceiver` | Emits a `RootChainERC20WithdrawEvent` when a message is received for any token with a different receiver. | Yes        |
| `test_onMessageReceive_TransfersTokens`                                    | Transfers tokens when a message is received.                                                              | Yes        |
| `test_onMessageReceive_TransfersTokens_DifferentReceiver`                  | Transfers tokens to a different receiver when a message is received.                                      | Yes        |
| `test_RevertsIf_OnMessageReceiveWithInvalidSignature`                      | Should revert if the message signature is invalid.                                                        | No         |
| `test_RevertsIf_OnMessageReceiveWithInvalidSourceAddress`                  | Should revert if the message source address is invalid.                                                   | No         |
| `test_RevertsIf_OnMessageReceiveWithInvalidSourceChain`                    | Should revert if the message source chain is invalid.                                                     | No         |
| `test_RevertsIf_OnMessageReceiveWithUnmappedToken`                         | Should revert if the message token is not mapped to a root chain token.                                   | No         |
| `test_RevertsIf_OnMessageReceiveWithZeroDataLength`                        | Should revert if the message data length is zero.                                                         | No         |
| `test_RevertsIf_WithdrawWithInvalidSender`                                 | Should revert if the sender of the withdraw request is invalid.                                           | No         |

#### IMX Token (Native and Wrapped)

| Test                                                                             | Description                                                                                                | Happy Path |
|----------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|------------|
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEventForIMX`                   | Emits a `RootChainERC20WithdrawEvent` when a message is received for IMX tokens.                           | Yes        |
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEventForIMX_DifferentReceiver` | Emits a `RootChainERC20WithdrawEvent` when a message is received for IMX tokens with a different receiver. | Yes        |
| `test_onMessageReceive_TransfersIMXTokens`                                       | Transfers IMX tokens when a message is received.                                                           | Yes        |
| `test_onMessageReceive_TransfersIMXTokens_DifferentReceiver`                     | Transfers IMX tokens to a different receiver when a message is received.                                   | Yes        |

#### ETH

| Test                                                                             | Description                                                                                              | Happy Path |
|----------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|------------|


### Control Operations

| Test                                                          | Description                                                         | Happy Path |
|---------------------------------------------------------------|---------------------------------------------------------------------|------------|
| `test_updateRootBridgeAdaptor_UpdatesRootBridgeAdaptor`       | Updates the bridge adaptor address                                  | Yes        |
| `test_updateRootBridgeAdaptor_EmitsNewRootBridgeAdaptorEvent` | Updating adapter address should emit `NewRootBridgeAdaptor` event   | Yes        |
| `test_RevertIf_updateRootBridgeAdaptorCalledByNonOwner`       | Should revert if the function is called by a non-owner              | No         |
| `test_RevertIf_updateRootBridgeAdaptorCalledWithZeroAddress`  | Should revert if the function is called with a zero adaptor address | No         |
