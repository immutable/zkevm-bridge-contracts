# Immutable zkEVM Token Bridge Threat Model

## Contents

- [Introduction](#introduction)
- [Architecture](#architecture)
- [Attack Surfaces](#attack-surfaces)
- [Perceived Attackers](#preceived-attackers)
- [Attack Mitigation](#attack-mitigation)
- [Conclusion](#conclusion)

## Terminology
- General Message Passing (GMP) bridge: A bridge that enables the transfer of arbitrary messages between two chains. The GMP bridge used by the Immutable zkEVM token bridge is [Axelar](https://axelar.network/).
- Token bridge: A bridge that enables the transfer of tokens between two chains, using an underlying GMP. The Immutable zkEVM bridge is a token bridge.
- Layer 1 (L1): Refers to Ethereum, which is also referred to as the Root chain in this document.
- Layer 2 (L2): Refers to Immutable zkEVM, which is also referred to as the Child chain in this document.
- Root chain: Refers to the Layer 1 chain, which is Ethereum.
- Child chain: Refers to the Layer 2, which is the Immutable zkEVM chain.
- Deposit: The transfer of tokens from the Root chain to the Child chain.
- Withdrawal: The transfer of tokens from the Child chain to the Root chain.
- Root token: An original token that is deployed on the Root chain.
- Child token: A wrapped token that is deployed on the Child chain, which is used to represent the Root token on the Child chain.

## Introduction
This document presents a threat model for the token bridge between Immutable zkEVM and Ethereum. The bridge enables the transfer of ETH, IMX, and standard ERC20 tokens between the two chains. It uses the underlying General Message Passing (GMP) bridge, specifically Axelar, for message transmission between Ethereum - referred to as the "Root" chain - and the Immutable zkEVM - referred to as the "Child" chain. 

### Scope
This threat model is specifically limited to the token bridge contracts and excludes the underlying GMP bridge. The following core contracts are covered within the scope of this threat model: 
1. [Root Chain](https://github.com/immutable/zkevm-bridge-contracts/tree/main/src/)
   - [`RootERC20Bridge`](../src/root/RootERC20Bridge.sol)
   - [`RootERC20BridgeFlowRate`](../src/root/RootERC20BridgeFlowRate.sol)
   - [`RootAxelarBridgeAdaptor`](../src/root/RootAxelarBridgeAdaptor.sol)
   - [`FlowRateDetection`](../src/root/flowrate/FlowRateDetection.sol)
   - [`FlowRateWithdrawalQueue`](../src/root/flowrate/FlowRateWithdrawalQueue.sol)
1. [Child Chain](https://github.com/immutable/zkevm-bridge-contracts/tree/main/src/)
   - [`ChildERC20Bridge`](../src/child/ChildERC20Bridge.sol)
   - [`ChildAxelarBridgeAdaptor`](../src/child/ChildAxelarBridgeAdaptor.sol)

The associated interfaces for the above contracts are implicitly included within the scope of this threat model, and can be found [here](../src/interfaces/).

### Features
#### Token Transfer
The bridge currently enables users to transfer their assets from the Root chain (Ethereum) to the Child chain (Immutable zkEVM), and to withdraw bridged assets back to the Root chain. 
Specifically, the following core capabilities are supported:
1. **Mapping Tokens (Root → Child):** This is a prerequisite step that must be performed once for each Root token before it can be bridged to the child chain. A mapping operation for a given Root token will deploy a new ERC20 token contract on the Child chain, which will be used to manage a wrapped version of the Root token on the Child chain. The wrapped token contract is owned by the bridge, which can perform mint and burn operations in response to deposits and withdrawals on the Root chain.
2. **Deposit (Root → Child):** Transfer tokens from the Root chain to the Child chain. This flow is referred to as a “deposit”. The types of assets that can be deposited on Ethereum, and the corresponding assets that are minted on Immutable zkEVM are listed below:
    1. Native ETH on Ethereum  → Wrapped ETH on Immutable zkEVM (ERC20 token)
    2. Wrapped ETH on Ethereum → Wrapped ETH on Immutable zkEVM (ERC20 token)
    3. ERC20 IMX on Ethereum   → Native IMX on Immutable zkEVM. IMX is represented on Immutable zkEVM as the native gas token, see [here](https://etherscan.io/token/0xf57e7e7c23978c3caec3c3548e3d615c346e79ff)
    4. Standard ERC20 tokens   → Wrapped equivalents on Immutable zkEVM (ERC20 token)
3. **Withdraw (Child → Root):** Transfer already bridged tokens back to Root chain. This flow is referred to as “withdrawal”. The types of bridged assets that can be withdrawn from Immutable zkEVM and the corresponding assets that are unlocked on Ethereum are listed below:
    1. Native IMX on Immutable zkEVM →  for ERC20 IMX on Ethereum.
    2. Wrapped ETH on Immutable zkEVM →  Native ETH on Ethereum
    3. Wrapped IMX on Immutable zkEVM →  for ERC20 IMX on Ethereum
    4. Wrapped ERC20 on Immutable zkEVM →  Original ERC20 on Ethereum

The bridge controls the lifecycle of bridged tokens to support its core functionality. On the root chain, assets are locked in the bridge upon deposit and unlocked upon withdrawal. On the child chain, assets are minted when deposited and burned when withdrawn. For IMX deposits, native IMX which is held by the bridge is unlocked and sent to the intended recipient, with no asset minting occurring.

*Not supported:*
The following capabilities are not currently supported:
- Bridging of tokens that were originally deployed on the L2 (i.e. ones that do not originate from an L1 token).
- Bridging of non-standard ERC20 tokens
- Bridging of ERC721 or other tokens standards

#### Withdrawal Queue
As a security measure, the bridge implements a delay on certain withdrawal transactions to mitigate the impact of potential exploits. The default delay is one day. The delay is implemented as a withdrawal queue, which is an array of withdrawal transactions for each user. The conditions determining whether a withdrawal transaction should be delayed and placed in a withdrawal queue are as follows:
1. Flow Rate: Specific flow rates can be set for individual tokens, regulating the amount that can be withdrawn over a set period. If a token's withdrawal rate exceeds its specific threshold, all subsequent withdrawals of the bridge are queued.
2. Large Withdrawal Threshold: Any withdrawal exceeding a token-specific amount is queued. This only affects the individual withdrawal in question and does not impact other withdrawals by the same user or others.
3. Unconfigured Token: If no thresholds are defined for a given token, all withdrawal relating to that token are queued.

To this end, the following features are implemented:
- A privileged account with `RATE` role can enable or disable the withdrawal queue, and configure parameters for each token related to the withdrawal queue, such as the flow rate and the large withdrawal thresholds.
- A user can query queued transactions for an account.
- A user can finalise a queued withdrawal once the required delay for a withdrawal has passed.
- A user can choose which queued withdrawals they want to process.
- A user can finalise multiple queued withdrawals in a single transaction.

#### Emergency Pause
The bridge can be paused in the event of an emergency, which will prevent any further user transactions from being processed by the bridge. This includes deposits and withdrawals. The bridge can be unpaused once the emergency has been resolved. To this end, the following features are implemented:
- A privileged account with `PAUSER` role can pause the bridge, disabling any further deposits, withdrawals or other processing of user transactions with the bridge.
- A separate privileged account with `UNPAUSER` role can unpause the bridge, thus re-enabling deposits, user interactions with the bridge.

#### Upgradeability
The features of the changes introduced are:
- Support for native ETH, IMX and ERC20 bridging from Ethereum (L1) to Immutable zkEVM (L2).
  - Native ETH is represented on Immutable zkEVM as an ERC20 token. 
  - wETH will be auto-unwrapped on Ethereum before bridging it across as native ETH i.e. ETH and wETH will be consolidated to the same ERC20 token on Immutable zkEVM. All users will receive native ETH when withdrawing to Ethereum.
  - The bridgeable supply of native IMX on Immutable zkEVM is owned by the `ChildERC20Bridge` contract, the remainder of the bridgeable supply up to the max supply of IMX (2B units) will be held in a treasury safe multi-sig. Increasing the bridgeable supply of native IMX will involve transferring funds directly from the treasury safe to the `ChildERC20Bridge` contract.
- Support for native ETH, IMX and ERC20 bridging from Immutable zkEVM (L2) to Ethereum (L1).
  - IMX is represented on Immutable zkEVM as the native gas token.
  - IMX is represented on Ethereum as a ERC20 token, see [here](https://etherscan.io/token/0xf57e7e7c23978c3caec3c3548e3d615c346e79ff).
  - As a result, a wIMX ERC20 token contract will be deployed for compatibility and usage with our Seaport and DEX contract.
  - wIMX will be auto-unwrapped on Immutable zkEVM before bridging it across as IMX i.e. IMX and wIMX will be consolidated to the same ERC20 token on Ethereum. All users will receive the canonical IMX ERC20 token when withdrawing to Ethereum.
- Ability for the contracts to be upgraded.
- Ability for the contracts to be paused.
- Use Axelar as the General Message Passing (GMP) bridge to send messages to and fro Ethereum and Immutable zkEVM
- Decouple our token bridge contracts from Axelar to future proof a change of the GMP to a zk-proof-based bridge
- The sender and receiver of bridged tokens can be different addresses.
- Flow rate integration for withdrawals from Immutable zkEVM to Ethereum
  - An account with `PAUSER` role can pause all deposits and withdrawals.
  - An account with `UNPAUSER` role can unpause all deposits and withdrawals.
  - A withdrawal queue is defined. In certain situations, a crosschain transfer
    results in a withdrawal being put in a "queue". Users can withdraw the amount
    after a delay. The default delay is one day. The queue is implemented as an
    array. Users can choose which queued withdrawals they want to process.
  - An account with `RATE` role can enable or disable the withdrawal queue, and
    configure parameters for each token related to the withdrawal queue.
  - Withdrawals of tokens whose amount is greater than a token specific threshold are
    put into the withdrawal queue. This just affects an individual withdrawal. It does
    not affect other withdrawals by that user or by any other user.
  - Withdrawals are put into the withdrawal queue when no thresholds have been defined
    for the token being withdrawn. This just affects an individual withdrawal. It does
    not affect other withdrawals by that user or by any other user.
  - If the rate of withdrawal of any token is over a token specific threshold, then all
    withdrawals are put into the withdrawal queue.

### Role-based Access Control

Additional Axelar requirements:
- Axelar will host the relaying service on behalf of Immutable. 
- We will leverage Axelar's full validator set for the safety and liveness of our bridge.
- Axelar will provide a one-step bridging experience i.e. there's no need to sign a separate transaction to claim your funds on the destination chain

# Architecture 

![Top-level bridge architecture](./202311-threat-model-immutable-bridge-diagrams/top-level-architecture.png)


