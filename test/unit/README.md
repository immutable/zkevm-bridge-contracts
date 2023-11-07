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

### Map Token (L1 -> L2)
Tests for the `mapToken` function, which maps a token on the L1 bridge contract to a newly created token on the L2 bridge contract.
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
This operation involves depositing tokens on the L1 contract to mint (or redeem) corresponding tokens on L2. 
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

| Test                                                 | Description                                                                                                 | Happy Path |
|------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|------------|
| `test_depositIMXEmitsIMXDepositEvent`                | Verifies that `deposit()` emits the `IMXDepositEvent` event when depositing IMX                             | Yes        |
| `test_depositToIMXEmitsIMXDepositEvent`              | Verifies that `depositTo()` emits the `IMXDepositEvent` when depositing IMX for different recipient address | Yes        |
| `test_deposit_whenSettingImxDepositLimitToUnlimited` | Verifies that the deposit function can still be called when the IMX deposit limit is set to unlimited.      | Yes        |
| `test_RevertsIf_IMXDepositLimitExceeded`             | Should revert if the IMX deposit limit is exceeded                                                          | No         |
| `test_RevertsIf_IMXDepositLimitTooLow`               | Should revert if the IMX deposit limit is too low                                                           | No         |

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

| Test                                                                       | Description                                                                                                             | Happy Path |
|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|------------|
| `test_onMessageReceive_TransfersTokens`                                    | Withdraw transfers tokens to withdrawer address.                                                                        | Yes        |
| `test_onMessageReceive_TransfersTokens_DifferentReceiver`                  | Withdraw transfers tokens to a specified recipient address.                                                             | Yes        |
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEvent`                   | Withdraw emits a `RootChainERC20WithdrawEvent` when a withdrawal message is received.                                   | Yes        |
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEvent_DifferentReceiver` | Withdraw emits a `RootChainERC20WithdrawEvent` when a withdrawal message with a different receiver address is received. | Yes        |
| `test_RevertsIf_OnMessageReceiveWithUnmappedToken`                         | Should revert if the token is not already mapped on the root chain.                                                     | No         |
| `test_RevertsIf_WithdrawWithInvalidSender`                                 | Should revert if the caller of `OnMessageReceive()` function is not the root chain bridge adapter                       | No         |
| `test_RevertsIf_OnMessageReceiveWithInvalidSignature`                      | Should revert if the message signature is not for a withdrawal action.                                                  | No         |
| `test_RevertsIf_OnMessageReceiveWithInvalidSourceAddress`                  | Should revert if the message source address is not the child bridge adapter.                                            | No         |
| `test_RevertsIf_OnMessageReceiveWithInvalidSourceChain`                    | Should revert if the message source chain is not the child chain id.                                                    | No         |
| `test_RevertsIf_OnMessageReceiveWithZeroDataLength`                        | Should revert if the message data length is zero.                                                                       | No         |

#### IMX Token (Native and Wrapped)

| Test                                                                             | Description                                                                                             | Happy Path |
|----------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|------------|
| `test_onMessageReceive_TransfersIMXTokens`                                       | Withdrawal transfers IMX tokens when a message is received.                                             | Yes        |
| `test_onMessageReceive_TransfersIMXTokens_DifferentReceiver`                     | Withdrawal transfers IMX tokens to a different receiver when a message is received.                     | Yes        |
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEventForIMX`                   | Withdrawal emits a `RootChainERC20WithdrawEvent` when withdrawing IMX tokens.                           | Yes        |
| `test_onMessageReceive_EmitsRootChainERC20WithdrawEventForIMX_DifferentReceiver` | Withdrawal emits a `RootChainERC20WithdrawEvent` when withdrawing IMX tokens with a different receiver. | Yes        |

#### ETH (Not Implemented)

| Test                                                                           | Description                                                              | Happy Path |
|--------------------------------------------------------------------------------|--------------------------------------------------------------------------|------------|
| `test_onMessageReceive_TransfersETH`                                           | ETH withdrawal transfers native ETH to withdrawer address.               | Yes        |
| `test_onMessageReceive_TransfersETH_DifferentReceiver`                         | ETH withdrawal transfers native ETH to a specified receiver address.     | Yes        |
| `test_onMessageReceive_EmitsRootChainETHWithdrawEventForETH`                   | ETH withdrawal emits a `RootChainETHWithdrawEvent` when withdrawing ETH. | Yes        |
| `test_onMessageReceive_EmitsRootChainETHWithdrawEventForETH_DifferentReceiver` | ETH withdrawal emits a `RootChainETHWithdrawEvent` when withdrawing ETH. | Yes        |

### Control Operations

| Test                                                          | Description                                                              | Happy Path |
|---------------------------------------------------------------|--------------------------------------------------------------------------|------------|
| `test_updateRootBridgeAdaptor_UpdatesRootBridgeAdaptor`       | Updates the bridge adaptor address                                       | Yes        |
| `test_updateRootBridgeAdaptor_EmitsNewRootBridgeAdaptorEvent` | Updating bridge adapter address should emit `NewRootBridgeAdaptor` event | Yes        |
| `test_RevertIf_updateRootBridgeAdaptorCalledByNonOwner`       | Should revert if the function is not called by the owner                 | No         |
| `test_RevertIf_updateRootBridgeAdaptorCalledWithZeroAddress`  | Should revert if the function is called with a zero adaptor address      | No         |

----


## Root ERC 20 Flow Rate (Not Implemented)
Contract: [RootERC20FlowRate.sol](../../src/root/RootERC20FlowRate.sol) inherits from [RootERC20Bridge.sol](../../src/root/RootERC20Bridge.sol)
Tests: [RootERC20FlowRate.t.sol](./root/RootERC20FlowRate.t.sol)

**Uninitialized testing:**
| Test name                         |Description                                        | Happy Case |
|-----------------------------------| --------------------------------------------------|------------|
| `testUninitPaused`                  | paused() returns false.                           | NA         |
| `testUninitLargeTransferThresholds` | largeTransferThresholds returns 0 for a  returns a zero length array | NA |
| `testWrongInit`                     | Check calling RootERC20Predicate's initialize reverts. | NA    |

**Control functions testing:**

| Test name                                          | Description                                    | Happy Case |
|----------------------------------------------------|------------------------------------------------|------------|
| `testReinit`                                       | re-run initialize                              | No         |
| `testActivateWithdrawalQueue`                      | activateWithdrawalQueue()                      | Yes        |
| `testActivateWithdrawalQueueBadAuth`               | activateWithdrawalQueue() bad auth.            | No         |
| `testDeactivateWithdrawalQueue`                    | deactivateWithdrawalQueue()                    | Yes        |
| `testDeactivateWithdrawalQueueBadAuth`             | deactivateWithdrawalQueue() bad auth.          | No         |
| `testSetWithdrawDelay`                             | setWithdrawDelay()                             | Yes        |
| `testSetWithdrawDelayBadAuth`                      | setWithdrawDelay() bad auth                    | No         |
| `testSetRateControlThreshold`                      | setRateControlThreshold()                      | Yes        |
| `testSetRateControlThresholdBadAuth`               | setRateControlThreshold() bad auth             | No         |
| `testGrantRole`                                    | grantRole()                                    | Yes        |
| `testGrantRoleBadAuth`                             | grantRole() bad auth                           | No         |
| `testPause`                                        | pause()                                        | Yes        |
| `testPauseBadAuth`                                 | pause() bad auth.                              | No         |
| `testUnpause`                                      | unpause()                                      | Yes        |
| `testUnpauseBadAuth`                               | unpause() bad auth.                            | No         |
| `testWithdrawalWhenPaused`                         | test withdrawal when paused                    | No         |
| `testFinaliseQueuedWithdrawalWhenPaused`           | finaliseQueuedWithdrawal when paused           | No         |
| `testfinaliseQueuedWithdrawalAggregatedWhenPaused` | finaliseQueuedWithdrawalAggregated when paused | No         |
| `testDepositWhenPaused`                            | depoosit when paused                           | No         |
| `testDepositToWhenPaused`                          | depoositTo when paused                         | No         |
| `testDepositNativeToWhenPaused`                    | depoositNativeTo when paused                   | No         |


**Operational functions testing:**
| Test name                       |Description                                        | Happy Case |
|---------------------------------| --------------------------------------------------|------------|
| `testWithdrawalERC20`             | _withdraw() small amount, no queue                | Yes        |
| `testWithdrawalEther`             | _withdraw() small amount, no queue                | Yes        |
| `testWithdrawalBadData`           | _withdraw() with data parameter too small         | No         |
| `testWithdrawalUnconfiguredToken` | _withdraw() with unconfigured child / root token  | No         |
| `testWithdrawalLargeWithdrawal`   | _withdraw() with large value                      | Yes        |
| `testWithdrawalLargeWithdrawal`   | _withdraw() causing high flow rate                | Yes        |
| `testHighFlowRate`                | _withdraw() with withdrawal queue active          | Yes        |
| `testFinaliseQueuedWithdrawalERC20` | finaliseQueuedWithdrawal for an ERC20           | Yes        |
| `testFinaliseQueuedWithdrawalEther` | finaliseQueuedWithdrawal for a Ether            | Yes        |
| `testFinaliseQueuedWithdrawalOutOfBounds` | finaliseQueuedWithdrawal when index is out of range for all withdrawals | No       |
| `testFinaliseQueuedWithdrawalAlreadyProcessed` | finaliseQueuedWithdrawal for index already processed | No       |
| `testFinaliseQueuedWithdrawalTooEarly` | finaliseQueuedWithdrawal before withdrawal delay | No       |
| `testFinaliseQueuedWithdrawalsAggregatedERC20` | finaliseQueuedWithdrawalsAggregated for ERC20 | Yes |
| `testFinaliseQueuedWithdrawalsAggregatedEther` | finaliseQueuedWithdrawalsAggregated for Ether | Yes |
| `testFinaliseQueuedWithdrawalsAggregatedOutOfBounds` | finaliseQueuedWithdrawalsAggregated when index is out of range for all withdrawals | No       |
| `testFinaliseQueuedWithdrawalsAggregatedAlreadyProcessed` | finaliseQueuedWithdrawalsAggregated for index already processed | No       |
| `testFinaliseQueuedWithdrawalsAggregatedTooEarly` | finaliseQueuedWithdrawalsAggregated before withdrawal delay | No       |
| `testFinaliseQueuedWithdrawalsAggregatedMismatch` | finaliseQueuedWithdrawalsAggregated with mismatch tokens | No |
| `testFinaliseQueuedWithdrawalsAggregatedNoIndices` | finaliseQueuedWithdrawalsAggregated with indices array zero length | No |
| `testFinaliseQueuedWithdrawalsReentrancy` | finaliseQueuedWithdrawals for reentrancy attacks | No |
| `testFinaliseQueuedWithdrawalsAggregatedReentrancy` | finaliseQueuedWithdrawalsAggregated for reentrancy attacks | No |

----

## Child ERC20 Bridge

**Contract**: [ChildERC20Bridge.sol](../../src/child/ChildERC20Bridge.sol)
**Test Contracts**: [ChildERC20Bridge.t.sol](./child/ChildERC20Bridge.t.sol), [ChildERC20BridgeWithdraw.t.sol](./child/withdrawals/ChildERC20BridgeWithdraw.t.sol), [ChildERC20BridgeWithdrawIMX.t.sol](./child/withdrawals/ChildERC20BridgeWithdrawIMX.t.sol), [ChildERC20BridgeWithdrawTo.t.sol](./child/withdrawals/ChildERC20BridgeWithdrawTo.t.sol), [ChildERC20BridgeWithdrawToIMX.t.sol](./child/withdrawals/ChildERC20BridgeWithdrawToIMX.t.sol)

### Initialization
The `ChildERC20Bridge` contract is upgradeable. These tests verify the initialization of the contract.

| Test Function Name                                                    | Description                                                                   | Happy Path  |
|-----------------------------------------------------------------------|-------------------------------------------------------------------------------|-------------|
| `test_Initialize`                                                     | Test initialization function                                                  | Yes         |
| `test_RevertIfInitializeTwice`                                        | Should revert if attempting to initialize more than once                      | No          |
| `test_RevertIf_InitializeWithAZeroAddressAdapter`                     | Should revert if attempting to initialize with a zero address adapter         | No          |
| `test_RevertIf_InitializeWithAZeroAddressAll`                         | Should revert if attempting to initialize with a zero address all             | No          |
| `test_RevertIf_InitializeWithAZeroAddressChildTemplate`               | Should revert if attempting to initialize with a zero address child template  | No          |
| `test_RevertIf_InitializeWithAZeroAddressIMXToken`                    | Should revert if attempting to initialize with a zero address IMX token       | No          |
| `test_RevertIf_InitializeWithAnEmptyBridgeAdaptorString`              | Should revert if attempting to initialize with an empty bridge adaptor string | No          |
| `test_RevertIf_InitializeWithAnEmptyChainNameString`                  | Should revert if attempting to initialize with an empty chain name string     | No          |

### Cross-chain Message Processing
| Test                                                                  | Description                                                                        | Happy Path |
|-----------------------------------------------------------------------|------------------------------------------------------------------------------------|------------|
| `test_RevertIf_onMessageReceiveCalledTwice`                           | Should revert if message is delivered more than once                               | No         |
| `test_RevertIf_onMessageReceiveCalledWithDataInvalid`                 | Should revert with message contains invalid data                                   | No         |
| `test_RevertIf_onMessageReceiveCalledWithDataLengthZero`              | Should revert with message data is empty                                           | No         |
| `test_RevertIf_onMessageReceiveCalledWithMsgSenderNotBridgeAdaptor`   | Should revert if `onMessageReceive()` caller is not the child chain bridge adaptor | No         |
| `test_RevertIf_onMessageReceiveCalledWithSourceAddressNotRootAdaptor` | Should revert if source address is not root chain adaptor                          | No         |
| `test_RevertIf_onMessageReceiveCalledWithSourceChainNotRootChain`     | Should revert if source chain is not root chain id                                 | No         |
| `test_RevertIf_onMessageReceiveCalledWithZeroAddress`                 | Should revert if root token address is zero address                                | No         |

### Map Token (L1 -> L2)
Tests for the `mapToken` function, which maps a token on the L1 bridge contract to a newly created token on the L2 bridge contract.

| Test                                          | Description                                             | Happy Path |
|-----------------------------------------------|---------------------------------------------------------|------------|
| `test_onMessageReceive_SetsTokenMapping`      | Verifies token mapping is set correctly                 | Yes        |
| `test_onMessageReceive_EmitsTokenMappedEvent` | Verifies `TokenMapped` event emitted when mapping token | Yes        |
| `test_onMessageReceive_DeploysERC20`          | Verifies mapping deploys new ERC20 token                | Yes        |
| `test_RevertIf_mapTokenCalledWithETHAddress`  | Verifies mapping reverts if token refers to ETH         | No         |
| `test_RevertIf_mapTokenCalledWithIMXAddress`  | Verifies mapping reverts if token refers to IMX address | No         |

### Deposits Token (L1 -> L2)
#### Standard ERC20

| Test                                                             | Description                                            | Happy Path |
|------------------------------------------------------------------|--------------------------------------------------------|------------|
| `test_onMessageReceive_Deposit_TransfersTokensToReceiver`        | Verifies deposit transfers tokens to the receiver      | Yes        |
| `test_onMessageReceive_Deposit_EmitsChildChainERC20DepositEvent` | Verifies deposit emits child chain ERC20 deposit event | Yes        |
| `test_onMessageReceive_Deposit_IncreasesTotalSupply`             | Verifies deposit increases total supply                | Yes        |
| `test_RevertIf_onMessageReceive_DepositWithEmptyContract`        | Should revert if empty contract                        | No         |
| `test_RevertIf_onMessageReceive_Deposit_NotMapped`               | Should revert if token is not mapped                   | No         |
| `test_RevertIf_onMessageReceive_Deposit_ReceiverZeroAddress`     | Should revert if receiver address is zero address      | No         |
| `test_RevertIf_onMessageReceive_Deposit_RootZeroAddress`         | Should revert if root token address as zero address    | No         |

#### ETH

| Test                                                             | Description                                               | Happy Path |
|------------------------------------------------------------------|-----------------------------------------------------------|------------|
| `test_onMessageReceive_DepositETH_TransfersTokensToReceiver`     | Verifies deposit ETH transfers tokens to the receiver     | Yes        |
| `test_onMessageReceive_DepositETH_IncreasesTotalSupply`          | Verifies deposit ETH increases total supply on the bridge | Yes        |
| `test_onMessageReceive_DepositETH_EmitsETHDepositEvent`          | Verifies deposit ETH emits `ETHDeposit` event             | Yes        |

#### IMX

| Test                                                             | Description                                                                  | Happy Path |
|------------------------------------------------------------------|------------------------------------------------------------------------------|------------|
| `test_onMessageReceive_DepositIMX_BalancesChanged`               | Verifies deposit IMX updates bridge's balance                                | Yes        |
| `test_onMessageReceive_DepositIMX_EmitsIMXDepositEvent`          | Test onMessageReceive emits IMX deposit event                                | Yes        |
| `test_RevertIf_onMessageReceive_DepositIMX_InsufficientBalance`  | Should revert if the bridge does not have sufficient IMX to transfer to user | No         |

### Withdrawals (L2 -> L1)

#### Standard ERC20 Token

| Test                                                               | Description                                                                     | Happy Path |
|--------------------------------------------------------------------|---------------------------------------------------------------------------------|------------|
| `test_withdrawTo_ReducesBalance`                                   | Verifies that the `withdrawTo` function reduces the user's balance.             | Yes        |
| `test_withdraw_ReducesBalance`                                     | Verifies that the `withdraw` function reduces the user's balance.               | Yes        |
| `test_withdrawTo_ReducesTotalSupply`                               | Verifies that the `withdrawTo` function reduces the total supply for the token. | Yes        |
| `test_withdraw_ReducesTotalSupply`                                 | Verifies that the `withdraw` function reduces the total supply for the token.   | Yes        |
| `test_withdraw_PaysFee`                                            | Verifies that the `withdraw` function pays the withdrawal fee.                  | Yes        |
| `test_withdrawTo_PaysFee`                                          | Verifies that the `withdrawTo` function pays the withdrawal fee.                | Yes        |
| `test_withdraw_CallsBridgeAdaptor`                                 | Verifies that the `withdraw` function calls the bridge adaptor.                 | Yes        |
| `test_withdrawTo_CallsBridgeAdaptor`                               | Verifies that the `withdrawTo` function calls the bridge adaptor.               | Yes        |
| `test_withdraw_EmitsERC20WithdrawEvent`                            | Verifies that the `withdraw` function emits ERC20 Withdraw event.               | Yes        |
| `test_withdrawTo_EmitsERC20WithdrawEvent`                          | Verifies that the `withdrawTo` function emits ERC20 Withdraw event.             | Yes        |
| `test_withdrawTo_ToDifferentReceiverCallsMockAdaptor`              | Verifies `withdrawTo` to a different receiver calling the mock adaptor.         | Yes        |
| `test_RevertIf_ZeroAmountIsProvided`                               | Should revert zero amount is provided in the `withdraw` call.                   | No         |
| `test_RevertsIf_WithdrawCalledWithAChildTokenThatHasWrongBridge`   | Should revert bridge associated with the child token is incorrect.              | No         |
| `test_RevertsIf_WithdrawCalledWithAChildTokenWithUnsetRootToken`   | Should revert the root token associated with a child token is unset.            | No         |
| `test_RevertsIf_WithdrawCalledWithEmptyChildToken`                 | Should revert an empty child token is invalid.                                  | No         |
| `test_RevertsIf_WithdrawCalledWithUnmappedToken`                   | Should revert if token is not already mapped.                                   | No         |
| `test_RevertsIf_WithdrawWhenBurnFails`                             | Should revert if burning the child token fails operation fails.                 | No         |
| `test_RevertsIf_WithdrawToCalledWithAChildTokenThatHasWrongBridge` | Should revert bridge associated with the child token is incorrect.              | No         |
| `test_RevertsIf_WithdrawToCalledWithAChildTokenWithUnsetRootToken` | Should revert the root token associated with a child token is unset..           | No         |
| `test_RevertsIf_WithdrawToCalledWithEmptyChildToken`               | Should revert an empty child token is invalid.                                  | No         |
| `test_RevertsIf_WithdrawToCalledWithUnmappedToken`                 | Should revert if token is not already mapped.                                   | No         |
| `test_RevertsIf_WithdrawToWhenBurnFails`                           | Should revert if burning the child token fails operation fails                  | No         |

#### IMX (Wrapped and Native)

| Test                                                                 | Description                                                                          | Happy Path |
|----------------------------------------------------------------------|--------------------------------------------------------------------------------------|------------|
| `test_withdrawIMX_ReducesBalance`                                    | Verifies that the `withdrawIMX` function reduces the user's balance.                 | Yes        |
| `test_withdrawIMXTo_ReducesBalance`                                  | Verifies that the `withdrawIMXTo` function reduces the user's balance.               | Yes        |
| `test_withdrawIMX_PaysFee`                                           | Verifies that the `withdrawIMX` function pays the withdrawal fee.                    | Yes        |
| `test_withdrawIMXTo_PaysFee`                                         | Verifies that the `withdrawIMXTo` function pays the withdrawal fee.                  | Yes        |
| `test_withdrawIMX_CallsBridgeAdaptor`                                | Verifies that the `withdrawIMX` function calls the bridge adaptor.                   | Yes        |
| `test_withdrawIMXTo_CallsBridgeAdaptor`                              | Verifies that the `withdrawIMXTo` function calls the bridge adaptor.                 | Yes        |
| `test_withdrawIMX_EmitsNativeIMXWithdrawEvent`                       | Verifies that the `withdrawIMX` function emits Native IMX Withdraw event.            | Yes        |
| `test_withdrawIMXTo_EmitsNativeIMXWithdrawEvent`                     | Verifies that the `withdrawIMXTo` function emits Native IMX Withdraw event.          | Yes        |
| `test_withdrawIMXToWithDifferentAccount_CallsBridgeAdaptor`          | Verifies `withdrawIMXTo` with a different account calling the bridge adaptor.        | Yes        |
| `test_withdrawIMXToWithDifferentAccount_EmitsNativeIMXWithdrawEvent` | Verifies `withdrawIMXTo` emits Native IMX Withdraw event with a different account.   | Yes        |
| `test_RevertsIf_WithdrawIMXCalledWithInsufficientFund`               | Should revert if `withdrawIMX` when called with insufficient funds.                  | No         |
| `test_RevertIf_ZeroAmountIsProvided`                                 | Should revert if zero amount is provided in the `withdrawIMX` call.                  | No         |
| `test_RevertsIf_withdrawIMXToCalledWithInsufficientFund`             | Should revert if the IMX value provided is less than amount requested for withdrawal | No         |

#### ETH (Not Implemented)

| Test                                                                 | Description                                                                          | Happy Path |
|----------------------------------------------------------------------|--------------------------------------------------------------------------------------|------------|
| `test_withdrawETH_ReducesBalance`                                    | Verifies that the `withdrawETH` function reduces the user's balance.                 | Yes        |
| `test_withdrawETHTo_ReducesBalance`                                  | Verifies that the `withdrawETHTo` function reduces the user's balance.               | Yes        |
| `test_withdrawETH_PaysFee`                                           | Verifies that the `withdrawETH` function pays the withdrawal fee.                    | Yes        |
| `test_withdrawETHTo_PaysFee`                                         | Verifies that the `withdrawETHTo` function pays the withdrawal fee.                  | Yes        |
| `test_withdrawETH_CallsBridgeAdaptor`                                | Verifies that the `withdrawETH` function calls the bridge adaptor.                   | Yes        |
| `test_withdrawETHTo_CallsBridgeAdaptor`                              | Verifies that the `withdrawETHTo` function calls the bridge adaptor.                 | Yes        |
| `test_withdrawETH_EmitsETHWithdrawEvent`                             | Verifies that the `withdrawETH` function emits Native IMX Withdraw event.            | Yes        |
| `test_withdrawETHTo_EmitsETHWithdrawEvent`                           | Verifies that the `withdrawETHTo` function emits Native IMX Withdraw event.          | Yes        |
| `test_withdrawETHToWithDifferentAccount_CallsBridgeAdaptor`          | Verifies `withdrawETHTo` with a different account calling the bridge adaptor.        | Yes        |
| `test_withdrawETHToWithDifferentAccount_EmitsNativeETHWithdrawEvent` | Verifies `withdrawETHTo` emits Native IMX Withdraw event with a different account.   | Yes        |
| `test_RevertsIf_WithdrawETHCalledWithInsufficientFund`               | Should revert if `withdrawETH` when called with insufficient funds.                  | No         |
| `test_RevertIf_ZeroAmountIsProvided`                                 | Should revert if zero amount is provided in the `withdrawETH` call.                  | No         |
| `test_RevertsIf_withdrawETHToCalledWithInsufficientFund`             | Should revert if the IMX value provided is less than amount requested for withdrawal | No         |


### Control Operations
| Test                                                     | Description                                                             | Happy Path |
|----------------------------------------------------------|-------------------------------------------------------------------------|------------|
| `test_updateBridgeAdaptor`                               | Update child bridge adaptor address function                            | Yes        |
| `test_RevertIf_updateBridgeAdaptorCalledByNonOwner`      | Should reverts if called by non-owner                                   | No         |
| `test_RevertIf_updateBridgeAdaptorCalledWithZeroAddress` | Should revert if called with new adapter address being the zero address | No         |

----

## Root Axelar Bridge Adapter

**Contract:** [RootAxelarBridgeAdapter.sol](../../src/root/RootAxelarBridgeAdaptor.sol)
**Test Contracts:** [RootAxelarBridgeAdapter.t.sol](./root/RootAxelarBridgeAdaptor.t.sol)

| Test Function Name                                   | Description                                                       | Happy Path |
|------------------------------------------------------|-------------------------------------------------------------------|------------|
| `test_Initialize`                                    | Verifies that `initialize()` sets correct values                  | Yes        |
| `test_RevertWhen_InitializeGivenEmptyChildChainName` | `initialize()` should revert if given an empty root chain name.   | No         |
| `test_RevertWhen_InitializeGivenZeroAddress`         | `initialize()` should revert if given a zero root bridge address. | No         |
| `test_sendMessage_CallsGasService`                   | `sendMessage` calls the Gas Service.                              | Yes        |
| `test_sendMessage_CallsGateway`                      | `sendMessage` calls the Gateway.                                  | Yes        |
| `test_sendMessage_EmitsAxelarMessageSentEvent`       | `sendMessage` emits the `AxelarMessageSent` event.                | Yes        |
| `test_sendMessage_GivesCorrectRefundRecipient`       | `sendMessage` gives the correct refund recipient.                 | Yes        |
| `test_Execute_CallsBridge`                           | `execute` should call the configured `RootERC20Bridge` contract.  | Yes        |
| `test_Execute_EmitsAdaptorExecuteEvent`              | `execute` should emit the `AdaptorExecute` event.                 | Yes        |
| `test_RevertIf_mapTokenCalledByNonRootBridge`        | `mapToken` should reverts when called by a non-root bridge.       | No         |
| `test_RevertIf_mapTokenCalledWithNoValue`            | `mapToken` should reverts when called with no value.              | No         |

--- 

## Child Axelar Bridge Adapter
Contract: [ChildAxelarBridgeAdaptor.sol](../../src/child/ChildAxelarBridgeAdaptor.sol)
Test Contracts: [ChildAxelarBridgeAdaptor.t.sol](./child/ChildAxelarBridgeAdaptor.t.sol)

| Test Function Name                               | Description                                                          | Happy Path |
|--------------------------------------------------|----------------------------------------------------------------------|------------|
| `test_Initialize`                                | Verifies `initialize()` sets correct values                          | Yes        |
| `test_RevertIf_InitializeGivenZeroAddress`       | `initialize` should revert if given a zero child bridge address.     | No         |
| `test_sendMessage_CallsGasService`               | Verifies `sendMessage` calls the Gas Service.                        | Yes        |
| `test_sendMessage_CallsGateway`                  | Verifies `sendMessage` calls the Gateway.                            | Yes        |
| `test_sendMessage_EmitsAxelarMessageSentEvent`   | Verifies `sendMessage` emits the `AxelarMessageSent` event.          | Yes        |
| `test_sendMessage_GivesCorrectRefundRecipient`   | Verifies `sendMessage` gives the correct refund recipient.           | Yes        |
| `test_RevertIf_sendMessageCalledByNonRootBridge` | `sendMessage` reverts when called by a non-root bridge.              | No         |
| `test_RevertIf_sendMessageCalledWithNoValue`     | `sendMessage` reverts when called with no value.                     | No         |
| `test_Execute_CallsBridge`                       | Verifies `execute` calls the configured `ChildERC20Bridge` contract. | Yes        |
| `test_Execute_EmitsAdaptorExecuteEvent`          | Verifies `execute` emits the `AdaptorExecute` event.                 | Yes        |

--- 

**The following section defines tests relating to flow rate detection and withdrawal queue management functionality. 
This is functionality that will largely be reused from [prior implementations](https://github.com/immutable/poly-core-contracts/blob/main/test/forge/root/flowrate/README.md) which have already been audited by ToB.**

## Flow Rate Detection
This section defines tests for contracts/root/flowrate/FlowRateDetection.sol.
All of these tests are in test/forge/root/flowrate/FlowRateDetection.t.sol.

**Uninitialized testing**

| Test name                        | Description                                       | Happy Case |
|----------------------------------|---------------------------------------------------|------------|
| `testUninitFlowRateBuckets`      | flowRateBuckets(address) returns an empty bucket. | NA         |
| `testUnWithdrawalQueueActivated` | withdrawalQueueActivated returns false.           | NA         |

**Control functions tests:**

| Test name                             | Description                                                        | Happy Case |
|---------------------------------------|--------------------------------------------------------------------|------------|
| `testActivateWithdrawalQueue`         | _activateWithdrawalQueue().                                        | Yes        |
| `testDeactivateWithdrawalQueue`       | _deactivateWithdrawalQueue() when withdrawalQueueActivate is true. | Yes        |
| `testSetFlowRateThreshold`            | _setFlowRateThreshold() with valid values                          | Yes        |
| `testSetFlowRateThresholdBadToken`    | _setFlowRateThreshold() with token address = 0                     | No         |
| `testSetFlowRateThresholdBadCapacity` | _setFlowRateThreshold() with capacity = 0                          | No         |
| `testSetFlowRateThresholdBadFillRate` | _setFlowRateThreshold() with refill rate = 0                       | No         |

**Operational functions tests:**

| Test name                              | Description                                                          | Happy Case |
|----------------------------------------|----------------------------------------------------------------------|------------|
| `testUpdateFlowRateBucketSingle`       | _updateFlowRateBucket() with a single call for a configured token    | Yes        |
| `testUpdateFlowRateBucketMultiple`     | _updateFlowRateBucket() with a multiple calls for a configured token | Yes        |
| `testUpdateFlowRateBucketOverflow`     | _updateFlowRateBucket() when the bucket overflows                    | Yes        |
| `testUpdateFlowRateBucketJustEmpty`    | _updateFlowRateBucket() when the bucket is exactly empty.            | Yes        |
| `testUpdateFlowRateBucketEmpty`        | _updateFlowRateBucket() when the bucket has underflowed.             | Yes        |
| `testUpdateFlowRateBucketAfterEmpty`   | _updateFlowRateBucket() after the bucket was empty.                  | Yes        |
| `testUpdateFlowRateBucketUnconfigured` | _updateFlowRateBucket() unconfigured bucket.                         | No         |


## Flow Rate Withdrawal Queue
This section defines tests for contracts/root/flowrate/FlowRateWithdrawalQueue.sol

**Uninitialized testing:**

| Test name                           | Description                                                                   | Happy Case |
|-------------------------------------|-------------------------------------------------------------------------------|------------|
| `testUninitWithdrawalQueue`         | withdrawalDelay() returns zero.                                               | NA         |
| `testEmptyProcessWithdrawal`        | _processWithdrawal with no elements in the queue.                             | No         |
| `testEmptyPendingWithdrawalsLength` | getPendingWithdrawalsLength returns a zero length array.                      | NA         |
| `testEmptyGetPendingWithdrawals1`   | getPendingWithdrawals with no elements in the queue and no requested indices. | NA         |  
| `testEmptyGetPendingWithdrawals2`   | getPendingWithdrawals with no elements in the queue and a requested index.    | NA         |  
| `testEmptyFindPendingWithdrawals`   | findPendingWithdrawals with no elements in the queue.                         | NA         | 

**Control function tests:**

| Test name                 | Description                                         | Happy Case |
|---------------------------|-----------------------------------------------------|------------|
| `testInitWithdrawalQueue` | __FlowRateWithdrawalQueue_init().                   | Yes        |
| `testSetWithdrawalDelay`  | _setWithdrawalDelay can confugre a withdrawal delay | Yes        |

**Operational function tests:**

| Test name                    | Description                                                      | Happy Case |
|------------------------------|------------------------------------------------------------------|------------|
| `testEnqueueWithdrawal`      | _enqueueWithdrawal                                               | Yes        |
| `testEnqueueTwoWithdrawals`  | _enqueueWithdrawal with two different tokens.                    | Yes        |
| `testEnqueueZeroToken`       | _enqueueWithdrawal with a token that is address(0)               | No         |
| `testProcessOneEntry`        | _processWithdrawal with one entry in the queue.                  | Yes        | 
| `testProcessTwoEntries`      | _processWithdrawal with two entries in the queue.                | Yes        |
| `testProcessOutOfOrder`      | Process withdrawals out of order.                                | Yes        |
| `testProcessOutside`         | _processWithdrawal for entry outside array.                      | No         |
| `testProcessTooEarly`        | _processWithdrawal before withdrawal delay.                      | No         |
| `testAlreadyProcessed`       | _processWithdrawal when already processed.                       | No         |
| `testGetPendingWithdrawals`  | getPendingWithdrawals for a range of scenarios                   | NA         |
| `testFindPendingWithdrawals` | findPendingWithdrawals for a range of scenarios                  | NA         |
| `testEnqueueProcessMultiple` | Enqueue one token, process the token, and repeat multiple times. | Yes        |

