# Test Plan
This document outlines the tests associated with this project. It is currently not complete as there are capabilities that are still under development. In addition, the document covers unit testing only and does not cover integration test scenarios.

## Root ERC20 Bridge
**Contract**: [RootERC20Bridge](../../src/root/RootERC20Bridge.sol)
**Test Contracts**: [RootERC20Bridge.t.sol](./root/RootERC20Bridge.t.sol), [RootERC20BridgeWithdraw.t.sol](./root/withdrawals/RootERC20BridgeWithdraw.t.sol) 

### Initialization
| Test                                                    | Description                                                                            | Happy Path |
|---------------------------------------------------------|----------------------------------------------------------------------------------------|------------|
| `test_InitializeBridge`                                 | Test initialization of the bridge                                                      | Yes        |
| `test_RevertIf_InitializeTwice`                         | Ensures revert if initialized twice                                                    | No         |
| `test_RevertIf_InitializeWithAZeroAddressAll`           | Ensures revert if initialized with a zero address for all arguments                    | No         |
| `test_RevertIf_InitializeWithAZeroAddressChildBridge`   | Ensures revert if initialized with a zero address for the child bridge argument        | No         |
| `test_RevertIf_InitializeWithAZeroAddressIMXToken`      | Ensures revert if initialized with a zero address for the IMX token argument           | No         |
| `test_RevertIf_InitializeWithAZeroAddressRootAdapter`   | Ensures revert if initialized with a zero address for the root bridge adapter argument | No         |
| `test_RevertIf_InitializeWithAZeroAddressTokenTemplate` | Ensures revert if initialized with a zero address for the token template argument      | No         |
| `test_RevertIf_InitializeWithAZeroAddressWETHToken`     | Ensures revert if initialized with a zero address for the WETH token argument          | No         |
| `test_RevertIf_InitializeWithEmptyChildAdapter`         | Ensures revert if initialized with an empty child adapter argument                     | No         |

### Control Operations

| Test                                                         | Description                                                          | Happy Path |
|--------------------------------------------------------------|----------------------------------------------------------------------|------------|
| `test_updateRootBridgeAdaptor_UpdatesRootBridgeAdapto`       | Updates the bridge adaptor address                                   | Yes        |
| `test_updateRootBridgeAdaptor_EmitsNewRootBridgeAdaptorEven` | Updating adapter address should emit `NewRootBridgeAdaptor` event    | Yes        |
| `test_RevertIf_updateRootBridgeAdaptorCalledByNonOwner`      | Ensures revert if the function is called by a non-owner              | No         |
| `test_RevertIf_updateRootBridgeAdaptorCalledWithZeroAddress` | Ensures revert if the function is called with a zero adaptor address | No         |


### Map Token
| Test                                          | Description                                                                | Happy Path |
|-----------------------------------------------|----------------------------------------------------------------------------|------------|
| `test_mapToken_SetsTokenMapping`              | Verifies that the mapToken function sets the token mapping.                | Yes        |
| `test_mapToken_CallsAdaptor`                  | Verifies that the mapToken function calls the bridge adapter               | Yes        |
| `test_mapToken_EmitsTokenMappedEvent`         | Verifies that the mapToken function emits a `TokenMappedEvent` event.      | Yes        |
| `test_RevertIf_mapTokenCalledTwice`           | Ensures revert if the mapToken function is called twice for the same token | No         |
| `test_RevertIf_mapTokenCalledWithETHAddress`  | Ensures revert if the mapToken function is called for native ETH           | No         |
| `test_RevertIf_mapTokenCalledWithIMXAddress`  | Ensures revert if the mapToken function is called for IMX                  | No         |
| `test_RevertIf_mapTokenCalledWithZeroAddress` | Ensures revert if the mapToken function is called with a zero address      | No         |

### Deposits
#### Standard ERC20 Tokens

| Test                                                        | Description                                                                                    | Happy Path |
|-------------------------------------------------------------|------------------------------------------------------------------------------------------------|------------|
| `test_depositCallsSendMessage`                              | Calls the send message function when depositing                                                | Yes        |
| `test_depositEmitsChildChainERC20DepositEvent`              | Emits the child chain ERC20 deposit event when depositing an ERC20 token                       | Yes        |
| `test_depositTransfersToken`                                | Verifies that the deposit function transfers the specified token to the specified child chain. | Yes        |
| `test_depositToCallsSendMessage`                            | Calls the send message function when depositing to a child chain account                       | Yes        |
| `test_depositToEmitsChildChainERC20DepositEven`             | Verifies that the depositToETH function emits a ChildChainERC20DepositEven event.              | Yes        |
| `test_depositToTransfersToken`                              | Verifies that the depositToETH function transfers the specified token to the child chain.      | Yes        |
| `test_RevertIf_depositAmountIsZero`                         | Ensures revert if the deposit amount is zero                                                   | No         |
| `test_RevertIf_depositCalledWhenTokenApprovalNotProvided`   | Ensures revert if the deposit function is called when token approval is not provided           | No         |
| `test_RevertIf_depositCalledWithUnmappedToken`              | Ensures revert if the deposit function is called with an unmapped token                        | No         |
| `test_RevertIf_depositCalledWithZeroAddress`                | Ensures revert if the deposit function is called with a zero address                           | No         |
| `test_RevertIf_depositToAmountIsZero`                       | Ensures revert if the depositTo amount is zero                                                 | No         |
| `test_RevertIf_depositToCalledWhenTokenApprovalNotProvided` | Ensures revert if the depositTo function is called when token approval is not provided         | No         |
| `test_RevertIf_depositToCalledWithUnmappedToken`            | Ensures revert if the depositTo function is called with an unmapped token                      | No         |
| `test_RevertIf_depositToCalledWithZeroAddress`              | Ensures revert if the depositTo function is called with a zero address                         | No         |

#### IMX Token

| Test                                                 | Description                                                                                            | Happy Path |
|------------------------------------------------------|--------------------------------------------------------------------------------------------------------|------------|
| `test_depositIMXEmitsIMXDepositEvent`                | Emits the IMX deposit event when depositing IMX                                                        | Yes        |
| `test_deposit_whenSettingImxDepositLimitToUnlimited` | Verifies that the deposit function can still be called when the IMX deposit limit is set to unlimited. | Yes        |
| `test_depositToIMXEmitsIMXDepositEven`               | Verifies that the depositToETH function emits a IMXDepositEven event.                                  | Yes        |
| `test_depositToWETHEmitsWETHDepositEven`             | Verifies that the depositToETH function emits a WETHDepositEven event when depositing WETH.            | Yes        |
| `test_depositToWETHTransfersToken`                   | Verifies that the depositToETH function transfers WETH to the child chain.                             | Yes        |
| `test_RevertsIf_IMXDepositLimitExceeded`             | Ensures revert if the IMX deposit limit is exceeded                                                    | No         |
| `test_RevertsIf_IMXDepositLimitTooLow`               | Ensures revert if the IMX deposit limit is too low                                                     | No         |

#### ETH (Native and Wrapped)

| Test                                          | Description                                                                                 | Happy Path |
|-----------------------------------------------|---------------------------------------------------------------------------------------------|------------|
| `test_depositETHCallsSendMessage`             | Calls the send message function when depositing ETH                                         | Yes        |
| `test_depositETHEmitsNativeEthDepositEvent`   | Emits the native ETH deposit event when depositing ETH                                      | Yes        |
| `test_depositTransfersNativeAsse`             | Verifies that the deposit function transfers the native asset to the specified child chain. | Yes        |
| `test_depositToETHCallsSendMessage`           | Verifies that the depositToETH function calls the sendMessage function.                     | Yes        |
| `test_depositToETHEmitsNativeEthDepositEven`  | Verifies that the depositToETH function emits a NativeEthDepositEven event.                 | Yes        |
| `test_depositToTransfersNativeAsse`           | Verifies that the depositToETH function transfers the native asset to the child chain.      | Yes        |
| `test_RevertIf_depositETHAmountIsZero`        | Ensures revert if the depositETH amount is zero                                             | No         |
| `test_RevertIf_depositETHInsufficientValue`   | Ensures revert if the depositETH function is called with insufficient value                 | No         |
| `test_RevertIf_depositToETHAmountIsZero`      | Ensures revert if the depositToETH amount is zero                                           | No         |
| `test_RevertIf_depositToETHInsufficientValue` | Ensures revert if the depositToETH function is called with insufficient value               | No         |
| `test_depositWETHCallsSendMessag`             | Verifies that the depositWETH function calls the sendMessage function.                      | Yes        |
| `test_depositWETHEmitsNativeDepositEvent`     | Verifies that the depositWETH function emits a NativeDepositEven event.                     | Yes        |
| `test_depositWETHTransfersToken`              | Verifies that the depositWETH function transfers WETH to the child chain.                   | Yes        |


### Withdrawal
