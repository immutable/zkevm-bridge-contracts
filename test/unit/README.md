# Test Plan
This document outlines the test plan for this project. 

## Root ERC20 Bridge
**Contract**: [RootERC20Bridge.sol](../../src/root/RootERC20Bridge.sol)

**Test Contracts**: [RootERC20Bridge.t.sol](./root/RootERC20Bridge.t.sol), [RootERC20BridgeWithdraw.t.sol](./root/withdrawals/RootERC20BridgeWithdraw.t.sol) 

### Initialization
The `RootERC20Bridge` contract is upgradeable. These tests verify the initialization of the contract.

| Test                                                    | Description                                                                                        | Happy Path |
|---------------------------------------------------------|----------------------------------------------------------------------------------------------------|------------|
| `test_InitializeBridge`                                 | Test initialization of the bridge, sets the correct values                                         | Yes        |
| `test_RevertIf_InitializeTwice`                         | Should revert if attempting to initalize a second time                                             | No         |
| `test_RevertIf_InitializeWithAZeroAddressAll`           | Should revert if attempting to initialize with a zero address for all arguments                    | No         |
| `test_RevertIf_InitializeWithAZeroAddressChildBridge`   | Should revert if attempting to initialize with a zero address for the child bridge argument        | No         |
| `test_RevertIf_InitializeWithAZeroAddressIMXToken`      | Should revert if attempting to initialize with a zero address for the IMX token argument           | No         |
| `test_RevertIf_InitializeWithAZeroAddressRootAdapter`   | Should revert if attempting to initialize with a zero address for the root bridge adapter argument | No         |
| `test_RevertIf_InitializeWithAZeroAddressTokenTemplate` | Should revert if attempting to initialize with a zero address for the token template argument      | No         |
| `test_RevertIf_InitializeWithAZeroAddressWETHToken`     | Should revert if attempting to initialize with a zero address for the WETH token argument          | No         |
| `test_RevertIf_InitializeWithEmptyChildAdapter`         | Should revert if attempting to initialize with an empty child adapter argument                     | No         |

### Map Token
Tests for the `mapToken` function.
- A mapped token cannot be mapped again
- ETH and IMX cannot be mapped

| Test                                          | Description                                                           | Happy Path |
|-----------------------------------------------|-----------------------------------------------------------------------|------------|
| `test_mapToken_SetsTokenMapping`              | Verifies that the mapToken function sets the token mapping.           | Yes        |
| `test_mapToken_CallsAdaptor`                  | Verifies that the mapToken function calls the bridge adapter          | Yes        |
| `test_mapToken_EmitsTokenMappedEvent`         | Verifies that the mapToken function emits a `TokenMappedEvent` event. | Yes        |
| `test_RevertIf_mapTokenCalledWithZeroAddress` | Should revert if the mapToken function is called with a zero address  | No         |
| `test_RevertIf_mapTokenCalledTwice`           | Should revert if the mapToken is already mapped                       | No         |
| `test_RevertIf_mapTokenCalledWithETHAddress`  | Should revert if attempting to map native or wrapped ETH              | No         |
| `test_RevertIf_mapTokenCalledWithIMXAddress`  | Should revert if attempting to map IMX                                | No         |

### Deposits (L1 -> L2)
The tests relate to the deposit feature of the bridge. 
This operation involves depositing tokens on the L1 contract to mint corresponding tokens on L2. 
The behavior varies slightly depending on whether the deposited token is a standard ERC20, Wrapped IMX, Native ETH, or Wrapped ETH. 
The tests described below are solely related to the portion of this flow related to the L1 bridge contract (i.e., `RootERC20Bridge.sol`), which involves processing a user's deposit request and dispatching a cross-chain message through an underlying bridge adapter.

#### Standard ERC20 Tokens

| Test                                                        | Description                                                                                  | Happy Path |
|-------------------------------------------------------------|----------------------------------------------------------------------------------------------|------------|
| `test_depositTransfersToken`                                | Verifies that `deposit()` transfers tokens from the user to the bridge.                      | Yes        |
| `test_depositToTransfersToken`                              | Verifies that `depositTo()` transfers tokens from the user to the bridge.                    | Yes        |
| `test_depositCallsSendMessage`                              | Verifies that `deposit()` sends cross-chain message through the underlying bridge adaptor.   | Yes        |
| `test_depositToCallsSendMessage`                            | Verifies that `depositTo()` sends cross-chain message through the underlying bridge adaptor. | Yes        |
| `test_depositEmitsChildChainERC20DepositEvent`              | Verifies that `deposit()` emits the correct deposit event when depositing an ERC20 token     | Yes        |
| `test_depositToEmitsChildChainERC20DepositEvent`            | Verifies that `depositTo()` emits the correct deposit event when depositing an ERC20 token   | Yes        |
| `test_RevertIf_depositAmountIsZero`                         | Should revert if `deposit()` is called with a zero deposit amount                            | No         |
| `test_RevertIf_depositToAmountIsZero`                       | Should revert if `depositTo()` is called with a zero deposit amount                          | No         |
| `test_RevertIf_depositCalledWhenTokenApprovalNotProvided`   | Should revert if the `deposit()` function is called when token approval is not provided      | No         |
| `test_RevertIf_depositToCalledWhenTokenApprovalNotProvided` | Should revert if the `depositTo()` function is called when token approval is not provided    | No         |
| `test_RevertIf_depositCalledWithUnmappedToken`              | Should revert if the `deposit()` function is called with an unmapped token                   | No         |
| `test_RevertIf_depositToCalledWithUnmappedToken`            | Should revert if the `depositTo()` function is called with an unmapped token                 | No         |
| `test_RevertIf_depositCalledWithZeroAddress`                | Should revert if the `deposit()` function is called with a zero address                      | No         |
| `test_RevertIf_depositToCalledWithZeroAddress`              | Should revert if the `depositTo()` function is called with a zero address                    | No         |

#### IMX Token
Tests specifically for the behavior related to IMX token deposits, in addition to the shared tests for standard ERC20 token behavior listed above.

| Test                                                 | Description                                                                                            | Happy Path |
|------------------------------------------------------|--------------------------------------------------------------------------------------------------------|------------|
| `test_depositIMXEmitsIMXDepositEvent`                | Verifies that `deposit()` emits the `IMXDepositEvent` event when depositing IMX                        | Yes        |
| `test_depositToIMXEmitsIMXDepositEvent`              | Verifies that `depositTo()` emits the `IMXDepositEvent` when depositing IMX                            | Yes        |
| `test_deposit_whenSettingImxDepositLimitToUnlimited` | Verifies that the deposit function can still be called when the IMX deposit limit is set to unlimited. | Yes        |
| `test_RevertsIf_IMXDepositLimitExceeded`             | Should revert if the IMX deposit limit is exceeded                                                     | No         |
| `test_RevertsIf_IMXDepositLimitTooLow`               | Should revert if the IMX deposit limit is too low                                                      | No         |

#### ETH (Native and Wrapped)
Tests specifically for the behavior related to native ETH and wrapped ETH deposits.

| Test                                          | Description                                                                                                    | Happy Path |
|-----------------------------------------------|----------------------------------------------------------------------------------------------------------------|------------|
| `test_depositTransfersNativeAsset`            | Depositing native ETH using `depositETH()` transfers ETH to the bridge.                                        | Yes        |
| `test_depositToTransfersNativeAsset`          | Depositing native ETH using `depositToETH()` transfers ETH to the bridge.                                      | Yes        |
| `test_depositWETHTransfersToken`              | Depositing wrapped ETH transfers WETH to the bridge.                                                           | Yes        |
| `test_depositToWETHTransfersToken`            | Depositing wrapped ETH transfers WETH to the bridge.                                                           | Yes        |
| `test_depositETHCallsSendMessage`             | Depositing native ETH sends cross-chain message through the bridge adapter                                     | Yes        |
| `test_depositToETHCallsSendMessage`           | Depositing native ETH sends cross-chain message through the bridge adapter                                     | Yes        |
| `test_depositWETHCallsSendMessage`            | Depositing wrapped ETH sends cross-chain message through the bridge adapter                                    | Yes        |
| `test_depositETHEmitsNativeEthDepositEvent`   | Depositing native ETH sends cross-chain message through the bridge adapter emits the `NativeETHDeposit` event  | Yes        |
| `test_depositToETHEmitsNativeEthDepositEvent` | Depositing native ETH sends cross-chain message through the bridge adapter emits the `NativeETHDeposit` event  | Yes        |
| `test_depositWETHEmitsNativeDepositEvent`     | Depositing wrapped ETH sends cross-chain message through the bridge adapter emits the `NativeETHDeposit` event | Yes        |
| `test_depositToWETHEmitsWETHDepositEvent`     | Depositing wrapped ETH sends cross-chain message through the bridge adapter emits the `WETHDeposit` event      | Yes        |
| `test_RevertIf_depositETHAmountIsZero`        | Should revert if the ETH deposit amount is zero                                                                | No         |
| `test_RevertIf_depositToETHAmountIsZero`      | Should revert if the ETH deposit amount is zero                                                                | No         |
| `test_RevertIf_depositETHInsufficientValue`   | Should revert if the ETH deposit is called with insufficient value                                             | No         |
| `test_RevertIf_depositToETHInsufficientValue` | Should revert if the ETH deposit  is called with insufficient value                                            | No         |


### Withdrawal (L2 -> L1)
The tests relate to the withdrawal feature of the bridge. This operation involves burning tokens on the L2 bridge contract to unlock corresponding tokens on L1. 
The behavior of this feature varies slightly depending on whether the token being withdrawn is a standard ERC20, Wrapped IMX, or ETH. 
The tests below are solely related to the portion of the flow involving the L1 bridge contract (i.e., `RootERC20Bridge.sol`), wherein a withdrawal flow initiated on L2, is processed on L1.

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

#### ETH (TODO: )

| Test                                                                             | Description                                                                                              | Happy Path |
|----------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|------------|


### Control Operations

| Test                                                          | Description                                                         | Happy Path |
|---------------------------------------------------------------|---------------------------------------------------------------------|------------|
| `test_updateRootBridgeAdaptor_UpdatesRootBridgeAdaptor`       | Updates the bridge adaptor address                                  | Yes        |
| `test_updateRootBridgeAdaptor_EmitsNewRootBridgeAdaptorEvent` | Updating adapter address should emit `NewRootBridgeAdaptor` event   | Yes        |
| `test_RevertIf_updateRootBridgeAdaptorCalledByNonOwner`       | Should revert if the function is called by a non-owner              | No         |
| `test_RevertIf_updateRootBridgeAdaptorCalledWithZeroAddress`  | Should revert if the function is called with a zero adaptor address | No         |


----

## Child ERC20 Bridge

**Contract**: [ChildERC20Bridge.sol](../../src/child/ChildERC20Bridge.sol)
**Test Contracts**: [ChildERC20Bridge.t.sol](./child/ChildERC20Bridge.t.sol), [ChildERC20BridgeWithdraw.t.sol](./child/withdrawals/ChildERC20BridgeWithdraw.t.sol), [ChildERC20BridgeWithdrawIMX.t.sol](./child/withdrawals/ChildERC20BridgeWithdrawIMX.t.sol), [ChildERC20BridgeWithdrawTo.t.sol](./child/withdrawals/ChildERC20BridgeWithdrawTo.t.sol), [ChildERC20BridgeWithdrawToIMX.t.sol](./child/withdrawals/ChildERC20BridgeWithdrawToIMX.t.sol)

### Initialization
| Test Function Name                                                    | Description                                                                    | Happy Path  |
|-----------------------------------------------------------------------|--------------------------------------------------------------------------------|-------------|
| `test_Initialize`                                                     | Test initialization function                                                   | Yes         |
| `test_RevertIfInitializeTwice`                                        | `initialize()`should revert if initialization is called twice                  | No          |
| `test_RevertIf_InitializeWithAZeroAddressAdapter`                     | `initialize()`should revert if initialized with a zero address adapter         | No          |
| `test_RevertIf_InitializeWithAZeroAddressAll`                         | `initialize()`should revert if initialized with a zero address all             | No          |
| `test_RevertIf_InitializeWithAZeroAddressChildTemplate`               | `initialize()`should revert if initialized with a zero address child template  | No          |
| `test_RevertIf_InitializeWithAZeroAddressIMXToken`                    | `initialize()`should revert if initialized with a zero address IMX token       | No          |
| `test_RevertIf_InitializeWithAnEmptyBridgeAdaptorString`              | `initialize()`should revert if initialized with an empty bridge adaptor string | No          |
| `test_RevertIf_InitializeWithAnEmptyChainNameString`                  | `initialize()`should revert if initialized with an empty chain name string     | No          |

### Cross-chain Message Processing
| Test                                                                  | Description                                                               | Happy Path |
|-----------------------------------------------------------------------|---------------------------------------------------------------------------|------------|
| `test_RevertIf_onMessageReceiveCalledTwice`                           | `_onMessageReceive()` should revert if called twice                       | No         |
| `test_RevertIf_onMessageReceiveCalledWithDataInvalid`                 | `_onMessageReceive()` should revert with invalid data                     | No         |
| `test_RevertIf_onMessageReceiveCalledWithDataLengthZero`              | `_onMessageReceive()` should revert with zero data length                 | No         |
| `test_RevertIf_onMessageReceiveCalledWithMsgSenderNotBridgeAdaptor`   | `_onMessageReceive()` should revert if msg sender is not bridge adaptor   | No         |
| `test_RevertIf_onMessageReceiveCalledWithSourceAddressNotRootAdaptor` | `_onMessageReceive()` should revert if source address is not root adaptor | No         |
| `test_RevertIf_onMessageReceiveCalledWithSourceChainNotRootChain`     | `_onMessageReceive()` should revert if source chain is not root chain     | No         |
| `test_RevertIf_onMessageReceiveCalledWithZeroAddress`                 | `_onMessageReceive()` should revert with zero address                     | No         |

### Map Token Operation (L1 -> L2)
| Test                                          | Description                                                   | Happy Path |
|-----------------------------------------------|---------------------------------------------------------------|------------|
| `test_onMessageReceive_EmitsTokenMappedEvent` | Test `TokenMapped` event emitted when mapping token           | Yes        |
| `test_onMessageReceive_SetsTokenMapping`      | Test token mapping is set                                     | Yes        |
| `test_onMessageReceive_DeploysERC20`          | `_mapToken()` deploys ERC20 token                             | Yes        |
| `test_RevertIf_mapTokenCalledWithETHAddress`  | `_mapToken()` should revert if mapping token with ETH address | No         |
| `test_RevertIf_mapTokenCalledWithIMXAddress`  | `_mapToken()` should revert if mapping token with IMX address | No         |

### Deposits Token Operation (L1 -> L2)
#### Standard ERC20

| Test                                                             | Description                                                 | Happy Path |
|------------------------------------------------------------------|-------------------------------------------------------------|------------|
| `test_onMessageReceive_Deposit_EmitsChildChainERC20DepositEvent` | Test onMessageReceive emits child chain ERC20 deposit event | Yes        |
| `test_onMessageReceive_Deposit_IncreasesTotalSupply`             | Test onMessageReceive increases total supply                | Yes        |
| `test_onMessageReceive_Deposit_TransfersTokensToReceiver`        | Test onMessageReceive transfers tokens to the receiver      | Yes        |
| `test_RevertIf_onMessageReceive_DepositWithEmptyContract`        | `_deposit()` should revert if empty contract                | No         |
| `test_RevertIf_onMessageReceive_Deposit_NotMapped`               | `_deposit()` should revert if token is not mapped           | No         |
| `test_RevertIf_onMessageReceive_Deposit_ReceiverZeroAddress`     | `_deposit()` should revert if receiver as zero address      | No         |
| `test_RevertIf_onMessageReceive_Deposit_RootZeroAddress`         | `_deposit()` should revert if root address as zero address  | No         |

#### ETH

| Test                                                             | Description                                                 | Happy Path |
|------------------------------------------------------------------|-------------------------------------------------------------|------------|
| `test_onMessageReceive_DepositETH_EmitsETHDepositEvent`          | Test onMessageReceive emits ETH deposit event               | Yes        |
| `test_onMessageReceive_DepositETH_IncreasesTotalSupply`          | Test onMessageReceive increases total supply                | Yes        |
| `test_onMessageReceive_DepositETH_TransfersTokensToReceiver`     | Test onMessageReceive transfers tokens to the receiver      | Yes        |

#### IMX

| Test                                                             | Description                                                 | Happy Path |
|------------------------------------------------------------------|-------------------------------------------------------------|------------|
| `test_onMessageReceive_DepositIMX_BalancesChanged`               | Test onMessageReceive balances changed on IMX deposit       | Yes        |
| `test_onMessageReceive_DepositIMX_EmitsIMXDepositEvent`          | Test onMessageReceive emits IMX deposit event               | Yes        |
| `test_RevertIf_onMessageReceive_DepositIMX_InsufficientBalance`  | `_deposit()` should revert if insufficient balance          | No         |

### Withdrawals (L2 -> L1)

#### Standard ERC20 Token

| Test                                                               | Description                                                                    | Happy Path |
|--------------------------------------------------------------------|--------------------------------------------------------------------------------|------------|
| `test_withdraw_CallsBridgeAdaptor`                                 | Test that the `withdraw` function calls the bridge adaptor.                    | Yes        |
| `test_withdraw_EmitsERC20WithdrawEvent`                            | Test that the `withdraw` function emits ERC20 Withdraw event.                  | Yes        |
| `test_withdraw_PaysFee`                                            | Test that the `withdraw` function pays the withdrawal fee.                     | Yes        |
| `test_withdraw_ReducesBalance`                                     | Test that the `withdraw` function reduces the user's balance.                  | Yes        |
| `test_withdraw_ReducesTotalSupply`                                 | Test that the `withdraw` function reduces the total supply.                    | Yes        |
| `test_withdrawTo_CallsBridgeAdaptor`                               | Test that the `withdrawTo` function calls the bridge adaptor.                  | Yes        |
| `test_withdrawTo_EmitsERC20WithdrawEvent`                          | Test that the `withdrawTo` function emits ERC20 Withdraw event.                | Yes        |
| `test_withdrawTo_PaysFee`                                          | Test that the `withdrawTo` function pays the withdrawal fee.                   | Yes        |
| `test_withdrawTo_ToDifferentReceiverCallsMockAdaptor`              | Test `withdrawTo` to a different receiver calling the mock adaptor.            | Yes        |
| `test_withdrawTo_ReducesBalance`                                   | Test that the `withdrawTo` function reduces the user's balance.                | Yes        |
| `test_withdrawTo_ReducesTotalSupply`                               | Test that the `withdrawTo` function reduces the total supply.                  | Yes        |
| `test_RevertIf_ZeroAmountIsProvided`                               | Test reverting when zero amount is provided in the `withdraw` call.            | No         |
| `test_RevertsIf_WithdrawCalledWithAChildTokenThatHasWrongBridge`   | Test withdrawal with child token having the wrong bridge.                      | No         |
| `test_RevertsIf_WithdrawCalledWithAChildTokenWithUnsetRootToken`   | Test withdrawal with a child token having an unset root token.                 | No         |
| `test_RevertsIf_WithdrawCalledWithEmptyChildToken`                 | Test withdrawal with an empty child token.                                     | No         |
| `test_RevertsIf_WithdrawCalledWithUnmappedToken`                   | Test withdrawal with an unmapped token.                                        | No         |
| `test_RevertsIf_WithdrawWhenBurnFails`                             | Test withdrawal when the burn operation fails.                                 | No         |
| `test_RevertsIf_WithdrawToCalledWithAChildTokenThatHasWrongBridge` | Test `withdrawTo` with a child token having the wrong bridge.                  | No         |
| `test_RevertsIf_WithdrawToCalledWithAChildTokenWithUnsetRootToken` | Test `withdrawTo` with a child token having an unset root token.               | No         |
| `test_RevertsIf_WithdrawToCalledWithEmptyChildToken`               | Test `withdrawTo` with an empty child token.                                   | No         |
| `test_RevertsIf_WithdrawToCalledWithUnmappedToken`                 | Test `withdrawTo` with an unmapped token.                                      | No         |
| `test_RevertsIf_WithdrawToWhenBurnFails`                           | Test `withdrawTo` when the burn operation fails.                               | No         |

#### IMX (Wrapped and Native)

| Test                                                                 | Description                                                                    | Happy Path |
|----------------------------------------------------------------------|--------------------------------------------------------------------------------|------------|
| `test_RevertsIf_WithdrawIMXCalledWithInsufficientFund`               | Test `withdrawIMX` when called with insufficient funds.                        | No         |
| `test_WithdrawIMX_CallsBridgeAdaptor`                                | Test that the `withdrawIMX` function calls the bridge adaptor.                 | Yes        |
| `test_WithdrawIMX_EmitsNativeIMXWithdrawEvent`                       | Test that the `withdrawIMX` function emits Native IMX Withdraw event.          | Yes        |
| `test_WithdrawIMX_PaysFee`                                           | Test that the `withdrawIMX` function pays the withdrawal fee.                  | Yes        |
| `test_WithdrawIMX_ReducesBalance`                                    | Test that the `withdrawIMX` function reduces the user's balance.               | Yes        |
| `test_RevertIf_ZeroAmountIsProvided`                                 | Test reverting when zero amount is provided in the `withdrawIMX` call.         | No         |
| `test_RevertsIf_withdrawIMXToCalledWithInsufficientFund`             | Test `withdrawIMXTo` when called with insufficient funds.                      | No         |
| `test_WithdrawIMX_PaysFee`                                           | Test that the `withdrawIMXTo` function pays the withdrawal fee.                | Yes        |
| `test_WithdrawIMX_ReducesBalance`                                    | Test that the `withdrawIMXTo` function reduces the user's balance.             | Yes        |
| `test_withdrawIMXToWithDifferentAccount_CallsBridgeAdaptor`          | Test `withdrawIMXTo` with a different account calling the bridge adaptor.      | Yes        |
| `test_withdrawIMXToWithDifferentAccount_EmitsNativeIMXWithdrawEvent` | Test `withdrawIMXTo` emits Native IMX Withdraw event with a different account. | Yes        |
| `test_withdrawIMXTo_CallsBridgeAdaptor`                              | Test that the `withdrawIMXTo` function calls the bridge adaptor.               | Yes        |
| `test_withdrawIMXTo_EmitsNativeIMXWithdrawEvent`                     | Test that the `withdrawIMXTo` function emits Native IMX Withdraw event.        | Yes        |

#### ETH (TODO: )



### Control Operations
| Test                                                     | Description                                                 | Happy Path |
|----------------------------------------------------------|-------------------------------------------------------------|------------|
| `test_updateBridgeAdaptor`                               | `updateBridgeAdaptor()` function                            | Yes        |
| `test_RevertIf_updateBridgeAdaptorCalledByNonOwner`      | `updateBridgeAdaptor()` reverts if called by non-owner      | No         |
| `test_RevertIf_updateBridgeAdaptorCalledWithZeroAddress` | `updateBridgeAdaptor()` reverts if called with zero address | No         |

----

## Root Axelar Bridge Adapter

**Contract:** [RootAxelarBridgeAdapter.sol](../../src/root/RootAxelarBridgeAdaptor.sol)
**Test Contracts:** [RootAxelarBridgeAdapter.t.sol](./root/RootAxelarBridgeAdaptor.t.sol)

| Test Function Name                                   | Description                                                     | Happy Path |
|------------------------------------------------------|-----------------------------------------------------------------|------------|
| `test_Initialize`                                    | Test `initialize()` sets correct values                         | Yes        |
| `test_RevertWhen_InitializeGivenEmptyChildChainName` | Constructor should revert when given an empty child chain name. | No         |
| `test_RevertWhen_InitializeGivenZeroAddress`         | `initialize()` should revert when given a zero address.         | No         |
| `test_Execute_CallsBridge`                           | `execute` should call the `RootERC20Bridge` contract.           | Yes        |
| `test_Execute_EmitsAdaptorExecuteEvent`              | `execute` should emit the `AdaptorExecute` event.               | Yes        |
| `test_sendMessage_CallsGasService`                   | `sendMessage` calls the Gas Service.                            | Yes        |
| `test_sendMessage_CallsGateway`                      | `sendMessage` calls the Gateway.                                | Yes        |
| `test_sendMessage_EmitsAxelarMessageSentEvent`       | `sendMessage` emits the `AxelarMessageSent` event.              | Yes        |
| `test_sendMessage_GivesCorrectRefundRecipient`       | `sendMessage` gives the correct refund recipient.               | Yes        |
| `test_RevertIf_mapTokenCalledByNonRootBridge`        | `mapToken` reverts when called by a non-root bridge.            | No         |
| `test_RevertIf_mapTokenCalledWithNoValue`            | `mapToken` reverts when called with no value.                   | No         |

--- 

## Child Axelar Bridge Adapter
Contract: [ChildAxelarBridgeAdaptor.sol](../../src/child/ChildAxelarBridgeAdaptor.sol)
Test Contracts: [ChildAxelarBridgeAdaptor.t.sol](./child/ChildAxelarBridgeAdaptor.t.sol)

| Test Function Name                               | Description                                             | Happy Path |
|--------------------------------------------------|---------------------------------------------------------|------------|
| `test_Initialize`                                | Test `initialize()` sets correct values                 | Yes        |
| `test_Execute_CallsBridge`                       | `execute` should call the `ChildERC20Bridge` contract.  | Yes        |
| `test_Execute_EmitsAdaptorExecuteEvent`          | `execute` should emits the `AdaptorExecute` event.      | Yes        |
| `test_sendMessage_CallsGasService`               | `sendMessage` calls the Gas Service.                    | Yes        |
| `test_sendMessage_CallsGateway`                  | `sendMessage` calls the Gateway.                        | Yes        |
| `test_sendMessage_EmitsAxelarMessageSentEvent`   | `sendMessage` emits the AxelarMessageSent event.        | Yes        |
| `test_sendMessage_GivesCorrectRefundRecipient`   | `sendMessage` gives the correct refund recipient.       | Yes        |
| `test_RevertIf_InitializeGivenZeroAddress`       | `initialize` reverts when given a zero address.         | No         |
| `test_RevertIf_sendMessageCalledByNonRootBridge` | `sendMessage` reverts when called by a non-root bridge. | No         |
| `test_RevertIf_sendMessageCalledWithNoValue`     | `sendMessage` reverts when called with no value.        | No         |