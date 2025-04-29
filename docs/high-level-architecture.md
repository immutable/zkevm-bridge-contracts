# High-level Architecture

---

<!-- TOC -->
  * [Introduction](#introduction)
    * [Purpose](#purpose)
    * [Scope](#scope)
  * [Background](#background)
    * [Cross-chain Messaging](#cross-chain-messaging)
    * [Axelar: General-purpose Messaging Protocol](#axelar-general-purpose-messaging-protocol)
    * [Immutable zkEVM Chain](#immutable-zkevm-chain)
  * [Immutable zkEVM Token Bridge](#immutable-zkevm-token-bridge)
    * [Core Features](#core-features)
      * [Deposit Assets (Root Chain → Child Chain)](#deposit-assets-root-chain--child-chain)
      * [Withdraw Assets (Child Chain → Root Chain)](#withdraw-assets-child-chain--root-chain)
    * [Security Features](#security-features)
      * [IMX Deposit Limit](#imx-deposit-limit)
      * [Withdrawal Delays](#withdrawal-delays)
      * [Emergency Pause](#emergency-pause)
      * [Role-Based-Access-Control](#role-based-access-control)
  * [Architecture](#architecture)
    * [Stakeholders](#stakeholders)
    * [Core Components](#core-components)
    * [Transaction Lifecycle](#transaction-lifecycle)
      * [Deposit Transaction Flow](#deposit-transaction-flow)
      * [Withdrawal Transaction Flow](#withdrawal-transaction-flow)
    * [Withdrawal Delay Mechanism](#withdrawal-delay-mechanism)
      * [Withdrawal Queue](#withdrawal-queue)
    * [Flow Rate Detection](#flow-rate-detection)
  * [Glossary](#glossary)
  * [Appendix A: Smart Contract State Mutation Functions](#appendix-a-smart-contract-state-mutation-functions)
<!-- TOC -->

---

## Introduction
### Purpose
This document outlines a high-level architecture and threat model for the token bridge between Ethereum ("Root" chain) and the Immutable zkEVM ("Child" chain) chains. The bridge facilitates the transfer of ETH, IMX, and standard ERC20 tokens between these chains, using an underlying General Message Passing (GMP) bridge, Axelar, for message transmission. This bridge is a critical piece of infrastructure for the Immutable zkEVM chain.

The purpose of this document is to two-fold:
1. Provide a high-level view of the Immutable zkEVM bridge's architecture, in terms of its core functionalities and use-cases, major components and their interactions, dependencies and architectural characteristics.
2. Identify key security risks related to the token bridge and detail the security features and controls implemented to mitigate them.

### Scope
This document primarily focuses on the on-chain components of the Immutable zkEVM token bridge infrastructure, covering its design, implementation, and operational aspects. Although various off-chain components and services will support this infrastructure, they are not included in the scope of this document. Furthermore, key dependencies like the GMP and underlying chains are only discussed at a high level, to the extent they influence the bridge's security model.

---

## Background

### Cross-chain Messaging
Cross-chain protocols can be arranged into a conceptual model containing layers of abstraction based on scope and functionality. Each layer relies on the layers beneath it for functionality and security. As a result, the architectural risks at each layer encompass those below.

At the lowest level is the messaging protocol, also known as the General Messaging Protocol (GMP). This protocol facilitates the transmission of arbitrary messages across chains and ensures the validity and finality of any information sent from a source network to a destination network.

Token bridges rely on underlying messaging bridges to enable the transfer of assets from a source to a destination network. Token bridges mimic this transfer of an asset by locking the original asset in the source network and issuing a synthetic representation on the destination. The original asset remains encumbered for as long as the synthetic token exists on the destination. When a user wants to redeem the original asset on the source network, the synthetic assets are burnt on the destination network and the original assets unlocked on the source network. Locked assets in a token bridge create a honey-pot for attackers, which has thus made them the primary targets of bridge-related hacks to date. This method is widely used as it is the only way to transfer assets to a network where they were not initially issued.

The Immutable zkEVM bridge, is a token bridge. It relies on an underlying messaging protocol provided by [Axelar](https://axelar.network/).

<p align="center">
<img src="diagrams/cross-chain-stack.png" alt="drawing" width="490"/>
</p>
<p align="center">
Cross-chain Messaging Stack
</p>

### Axelar: General-purpose Messaging Protocol
[Axelar](https://axelar.network/) is a general-purpose cross-chain messaging protocol that uses cryptoeconomic guarantees for security. The protocol employs a delegated [proof-of-stake](https://cross-chainriskframework.github.io/framework/20categories/20architecture/architecture/#proof-of-stake) mechanism and a permissionless set of validators coordinated through a [Tendermint](https://tendermint.com/)-based blockchain network. Validators are incentivized with block rewards, and penalised if they deviate from the protocol or experience extended downtimes. This incentivizes validators to operate performant and secure validator nodes and behave honestly. The protocol's safety and liveness guarantees stem directly from the financial stake of the validator set and the in-protocol mechanism that governs their behavior.

Axelar's validator network comprise [75 active validators](https://axelarscan.io/validators), and employs a quadratic voting mechanism to achieve consensus. This approach helps to distribute voting power more evenly across validators and mitigate risks associated with the concentration of stake distribution and centralization. The protocol sets a 60% safety threshold by quadratic share of voting power, which, with the current distribution of stake, requires at least 30 out of 70 validators to sign a message for it to be considered valid.

If a quorum of validators is compromised or colludes, fraudulent messages could be submitted and executed. Similarly, if a bug or vulnerability in the protocol enabled spoofing a quorum, then safety could be compromised. Furthermore, under the current distribution of stake, the protocol’s liveness would be impacted if roughly 19 validators failed simultaneously. This same threshold of validators could censor messages if they choose to do so.

<p align="center">
<img src="diagrams/Axelar-GMP.png" alt="drawing" width="700"/>
</p>
<p align="center">
Axelar General-purpose Messaging Bridge
</p>

### Immutable zkEVM Chain
The Immutable zkEVM chain is an EVM-based single sequencer chain, derived from a fork of the [Geth client](https://github.com/ethereum/go-ethereum) and operating on the [Clique consensus protocol](https://geth.ethereum.org/docs/tools/clef/clique-signing). As a permissioned chain, it has a fixed set of validators. The chain utilizes a native token, IMX, for transaction gas payments. An [ERC20 version of IMX](https://etherscan.io/token/0xf57e7e7c23978c3caec3c3548e3d615c346e79ff) also exists on Ethereum. Upon the launch of the Immutable zkEVM chain, native IMX was pre-mined to support the floating supply of IMX on Ethereum. Users bridging IMX from Ethereum will receive native IMX on the Immutable zkEVM. The Immutable zkEVM bridge maintains a supply of IMX to service this bridging.

---

## Immutable zkEVM Token Bridge
The Immutable zkEVM token bridge facilitates the transfer of assets between two chains, namely Ethereum (the Root chain) and the Immutable zkEVM (the Child chain). At present, the bridge only supports the transfer of standard ERC20 tokens originating from Ethereum, as well as native assets (ETH and IMX). Other types of assets (such as ERC721) and assets originating from the Child chain are not currently supported.

### Core Features
The bridge provides two key functions, **deposits** and **withdrawals**. 

#### Deposit Assets (Root Chain → Child Chain)
When a user wishes to transfer assets from Ethereum to Immutable zkEVM, they initiate a deposit. This deposit moves an asset from the Root chain to the Child chain. It does so by first transferring the user's asset to the bridge (Root chain) where they are locked, then minting and transferring corresponding representation tokens of that asset to the user, on the Child chain. The following types of asset deposits flows are supported:
1. Native ETH on Ethereum  → Wrapped ETH on Immutable zkEVM (ERC20 token)
2. Wrapped ETH on Ethereum → Wrapped ETH on Immutable zkEVM (ERC20 token)
3. ERC20 IMX on Ethereum   → Native IMX on Immutable zkEVM. IMX is represented on Immutable zkEVM as the native gas token, see [here](https://etherscan.io/token/0xf57e7e7c23978c3caec3c3548e3d615c346e79ff)
4. Standard ERC20 tokens   → Wrapped equivalents on Immutable zkEVM (ERC20 token)

#### Withdraw Assets (Child Chain → Root Chain)
When a user wants to transfer bridged assets from Immutable zkEVM back to Ethereum, they start a withdrawal. This process moves an asset from the Child chain to the Root chain. It includes burning the user's bridged tokens on the child chain and unlocking the corresponding asset on the Root chain. Only assets that were bridged using the deposit flow described above can be withdrawn. Therefore, the available withdrawal flows are as follows:
1. Native IMX on Immutable zkEVM →  for ERC20 IMX on Ethereum.
2. Wrapped ETH on Immutable zkEVM →  Native ETH on Ethereum
3. Wrapped IMX on Immutable zkEVM →  for ERC20 IMX on Ethereum
4. Wrapped ERC20 on Immutable zkEVM →  Original ERC20 on Ethereum

**Not supported:**
The following capabilities are not currently supported by the Immutable zkEVM bridge:
- Bridging of tokens that were originally deployed on the Child chain (i.e. ones that do not originate from the Root chain).
- Bridging of non-standard ERC20 tokens
- Bridging of ERC721 or other tokens standards

### Security Features
The bridge employs a number of security features to mitigate the likelihood and impact of potential exploits. These are discussed further in subsections below.

#### IMX Deposit Limit
The total amount of IMX that can be deposited (i.e. sent from the Root chain to the Child chain), is capped at a configurable threshold. In addition to mitigating the potential impact of an exploit, this limit serves to reduce the likelihood of scenarios where the bridge might not have sufficient native IMX to process the deposits on the child chain.

#### Withdrawal Delays
To mitigate the impact of potential exploits, withdrawal transactions (token transfers from the Child chain to the Root chain) may be automatically delayed under certain conditions. By default, this delay is one day. The delay is implemented as a withdrawal queue, which is an array of withdrawal transactions for each user. Once the required delay has passed, a user can finalize a queued withdrawal. The conditions that trigger a withdrawal delay are as follows:
   - Specific flow rates can be set for individual tokens. These rates regulate the amount that can be withdrawn over a period of time. If a token's withdrawal rate exceeds its specific threshold, all subsequent withdrawals from the bridge are queued.
   - Any withdrawal that exceeds a token-specific amount is queued. This only affects the individual withdrawal in question and does not impact other withdrawals by the same user or others.
   - If no thresholds are defined for a given token, all withdrawals relating to that token are queued.

For further details, see the [withdrawal delay mechanism section](#withdrawal-delay-mechanism).

#### Emergency Pause
In the event of an emergency, the bridge can be paused to mitigate the potential impact of an incident. This suspends all user-accessible capabilities, including token mapping, deposits, and withdrawals, until the bridge is resumed. However, this doesn't restrict privileged functions accessible by accounts with certain roles. It allows administrators to perform necessary operations that can address the incident (e.g., bridge parameter changes, upgrades). The specific functions that are halted by the emergency pause mechanism for each contract are listed below:
- Root Chain
   - `RootERC20Bridge`: `mapToken()`, `deposit()`, `depositTo()`, `depositETH()`, `depositToETH()`, `onMessageReceive()`
   - `RootERC20BridgeFlowRate` contract: `finaliseQueuedWithdrawal()`, `finaliseQueuedWithdrawalsAggregated()`, as well as all functions from `RootERC20Bridge`.
- Child Chain:
  - `ChildERC20Bridge`: `withdraw()`, `withdrawTo()`, `withdrawIMX()`, `withdrawIMXTo()`, `withdrawWIMX()`, `withdrawWIMXTo()`,`onMessageReceive()`

#### Role-Based-Access-Control
The bridge employs fine-grained Role-Based-Access-Controls (RBAC), for privileged operations that control various parameters of the bridge. These include:
- `DEFAULT_ADMIN_ROLE`: Can manage granting and revoking of roles to accounts.
- `VARIABLE_MANAGER_ROLE`: Can update the cumulative IMX deposit limit.
- `RATE_MANAGER_ROLE`: Can enable or disable the withdrawal queue, and configure parameter for each token related to the withdrawal queue.
- `BRIDGE_MANAGER_ROLE`: Can update the bridge used by the adaptor.
- `ADAPTOR_MANAGER_ROLE`: Can update the bridge adaptor.
- `TARGET_MANAGER_ROLE`: Can update targeted bridge used by the adaptor (e.g. target is child chain on root adaptors).
- `GAS_SERVICE_MANAGER_ROLE`: Role identifier for those who can update the gas service used by the adaptor.
- `PAUSER_ROLE`: Role identifier for those who can pause functionanlity.
- `UNPAUSER_ROLE`: Role identifier for those who can unpause functionality
---
## Architecture

### Stakeholders
The following stakeholders are involved in the bridge's design, implementation, and operation:
1. **Users:** Users are the primary stakeholders of the bridge. They are the ones who deposit and withdraw assets from the bridge. They are also the ones who are impacted by any potential exploits.
2. **Token holders:** Token holders are the stakeholders who hold the tokens that are bridged. They are impacted by any potential exploits that affect the bridge, as this could significantly impact the value of their tokens.
3. **Bridge Operators:** Bridge operators are the entities that operate the bridge. They are responsible for the bridge's security, maintenance, and upgrades. They are also responsible for the bridge's operational aspects, such as key management, deployment, and configuration. In the context of Immutable zkEVM bridge, this role is undertaken exclusively by Immutable.

### Core Components
The Immutable zkEVM bridge consists of a set of solidity smart contracts deployed on both the Root and Child chains. These contracts enable capabilities such as deposits, withdrawals, and token mapping between the Root and Child chains, as discussed in the [core features](#core-features*) section.

The design of the contracts follows an adaptor pattern, in order to abstract away GMP specific functionality from the core bridge functionality. This allows the bridge to be easily replace the underlying GMP if required. 

Hence, the bridge consist of a pair of contracts deployed on each chain: an adaptor, which handle sending and receiving messages to the underlying GMP, and the bridge contract, which handles the core bridge functionality. Both adaptors and bridge contracts are upgradeable, and follow the Transparent proxy pattern. This allows the bridge to be upgraded without requiring users to interact with a new contract address.

<img src="diagrams/bridge-HLA.png" alt="drawing" width="1638"/>

The [smart contracts include](https://github.com/immutable/zkevm-bridge-contracts/tree/main/src):
1. [Root Chain](https://github.com/immutable/zkevm-bridge-contracts/tree/main/src/): Contracts deployed on the Root Chain:
    - [`RootERC20Bridge`](../src/root/RootERC20Bridge.sol): The bridge contract that handles mapping, deposits and withdrawals of ERC20 tokens, and native tokens between the Root and Child chains. Note that this contract is not deployed, and is solely used as a base contract for the `RootERC20BridgeFlowRate` contract.
    - [`RootERC20BridgeFlowRate`](../src/root/RootERC20BridgeFlowRate.sol): Extends `RootERC20Bridge` to include flow rate control functionality. This is the primary bridge contract that users will interact with.
    - [`FlowRateDetection`](../src/root/flowrate/FlowRateDetection.sol): Implements flow rate control detection functionality.
    - [`FlowRateWithdrawalQueue`](../src/root/flowrate/FlowRateWithdrawalQueue.sol): Implements withdrawal queue functionality.
    - [`RootAxelarBridgeAdaptor`](../src/root/RootAxelarBridgeAdaptor.sol): Enables the bridge to send and receive messages to and from the Axelar GMP bridge.
2. [Child Chain](https://github.com/immutable/zkevm-bridge-contracts/tree/main/src/): Contracts deployed on the Child Chain:
    - [`ChildERC20Bridge`](../src/child/ChildERC20Bridge.sol): The bridge contract that handles mapping, deposits and withdrawals of ERC20 tokens, and native tokens between the Root and Child chains.
    - [`ChildAxelarBridgeAdaptor`](../src/child/ChildAxelarBridgeAdaptor.sol): Enables the bridge to send and receive messages to and from the Axelar GMP bridge.

### Transaction Lifecycle

#### Deposit Transaction Flow
The example below illustrates the lifecycle of transaction where a user deposits ETH on Ethereum. The example is illustrative of the lifecycle of a typical token deposit transaction. 

<img src="diagrams/deposit-transaction-flow.png" alt="drawing"/>

1. Alice initiates a call to `depositETH()` on the `RootERC20BridgeFlowRate` contract, sending her desired amount of ETH and a bridging fee. This fee covers the Axelar protocol services, which include validator attestation, relaying, and executing the cross-chain message on the destination chain.
2. The deposit request is then validated and a cross-chain message payload is sent to the bridge adaptor.
3. This bridge adaptor forwards the message payload to the `AxelarGateway` contract and sends the bridge fee to the `AxelarGasService` contract.
4. The `AxelarGateway` emits events associated with the request to send the cross-chain message. These events are observed by Axelar validators who then attest to the cross-chain message.
5. Once a quorum of Axelar validators attests to a message, an Axelar validator sends the approval information to the `AxelarGateway` contract on the destination chain.
6. Subsequently, the Axelar executor service triggers the execution of the cross-chain message to complete the deposit process on the destination chain. This is done by calling the `execute()` method on `ChildAxelarBridgeAdaptor`. While the Axelar executor service is compensated as part of the bridging fee, the process is permissionless and can be executed by any entity.
7. The bridge adaptor validates the cross-chain message, ensuring it has been attested by the Axelar validator set and originated from the `RootAxelarBridgeAdaptor` on Ethereum.
8. The bridge adaptor forwards the message to the `ChildERC20Bridge` contract.
9. The `ChildERC20Bridge` performs various validations and triggers a mint on the wrapped ETH ERC20 contract on the child chain, transferring `wETH` to Alice on the child chain.

The deposit of ERC20 tokens follows a similar flow with two subtle differences: 1) A prerequisite step where the user grants approval to the ERC20 token, enabling the bridge to transfer the deposit amount, and 2) As part of the deposit initiation step (step 1 in the process above), the bridge transfers the tokens from the user to the bridge itself.

#### Withdrawal Transaction Flow
The example below illustrates the lifecycle of transaction where a user withdraws wETH from the Immutable zkEVM chain. The example is illustrative of the lifecycle of a typical token withdrawal transaction. A prerequisite step to this withdrawal process is that a user approves the bridge's transfer of the required amount of the ERC20 token from the user's account.

<img src="diagrams/withdraw-transaction-flow.png" alt="drawing"/>

1. Alice initiates a call to `withdrawETH()` on the `ChildERC20Bridge` contract, sending her desired amount of wETH to withdraw and a bridging fee in IMX, the native currency of the Immutable zkEVM chain. The bridge fee covers the Axelar protocol services, which include validator attestation, relaying, and executing the cross-chain message on the destination chain.
2. The corresponding amount of wETH is burnt from Alice's balance, on the Wrapped ETH ERC20 contract.
3. The bridge sends a cross-chain message payload to the `ChildAxelarBridgeAdaptor`.
4. This bridge adaptor forwards the message payload to the `AxelarGateway` contract and sends the bridge fee to the `AxelarGasService` contract.
5. The `AxelarGateway` emits events associated with the request to send the cross-chain message. These events are observed by Axelar validators who then attest to the cross-chain message.
6. Once a quorum of Axelar validators attests to a message, an Axelar validator sends the approval information to the `AxelarGateway` contract on the destination chain.
7. Subsequently, the Axelar executor service triggers the execution of the cross-chain message to complete the deposit process on the destination chain. This is done by calling the `execute()` method on `RootAxelarBridgeAdaptor`. While the Axelar executor service is compensated as part of the bridging fee, the process is permissionless and can be executed by any entity.
8. The bridge adaptor validates the cross-chain message, ensuring it has been attested by the Axelar validator set and originated from the `ChildAxelarBridgeAdaptor` on Immutable zkEVM.
9. The bridge adaptor forwards the message to the `RootERC20BridgeFlowRate` contract.
10. The `RootERC20BridgeFlowRate` performs various validations. These checks include determining if the withdrawal exceeds the configured flow rate for ETH. If it does, the transaction is placed in a withdrawal queue. Requiring Alice to manually finalise the withdrawal, after the withdrawal delay (default of 1 day) has elapsed. If it doesn't, the bridge transfers a corresponding amount of native ETH from the bridge to Alice, thus completing the withdrawal flow.

The withdrawal of native IMX follows a similar flow with two subtle differences. These differences are due to the fact that IMX is a native token on the child chain, not an ERC20 token: 1) A pre-requisite ERC20 token approval step is not required, and 2) The IMX sent by the user is locked in the bridge, and there is no token burning step.


----
### Withdrawal Delay Mechanism

[`RootERC20BridgeFlowRate`](../src/root/flowrate/RootERC20BridgeFlowRate.sol) implements a withdrawal queue. This is a mechanism in which withdrawals that meet certain conditions are delayed for a period of time before they can be processed. The rationale for having a queue is to give teams monitoring the bridge time to determine if suspicious withdrawals are valid or whether they relate to an attack in progress. Withdrawals enter the withdrawal queue in the following scenarios:

- All withdrawals:
    - Manual activation: An account with `RATE` role has called the `activateWithdrawalQueue` function.
    - Automatic activation: The flow rate for any configured token exceeds the configured maximum flow rate for that token.
- Individual withdrawals:
    - The number of tokens for the withdrawal exceeds the _large withdrawal_ threshold for the token.
    - The withdrawal is for a token for which flow rate and large withdrawal thresholds have not been configured.

An account with `RATE` role can:

- Activate the queue by calling the `activateWithdrawalQueue` function.
- Deactivate the queue by calling the `deactivateWithdrawalQueue` function.
- Configure the withdrawal delay (the length of time withdrawals remain in the queue) by calling the `setWithdrawalDelay` function.
- Configure the flow rate and large withdrawal thresholds for a token by calling the `setRateControlThreshold` function.

The rationale for having the same role for activating, deactivating, and configuring the withdrawal queue is that it is expected that the threshold number signers of the multi-sig for these operations should be all high.

The default withdrawal delay is 24 hours. The rationale for this length of delay is that it would give the teams monitoring the bridge enough time to make a determination that an attack was in progress and arrange for all of the multi-sig signers required to pause the bridge to sign and execute the `pause` function.

#### Withdrawal Queue

When a user initiates a withdrawal transaction from the Immutable zkEVM to Ethereum, as discussed in the [withdrawal transaction flow section](#withdrawal-transaction-flow)), the request eventually triggers the `_withdraw` function in `RootERC20BridgeFlowRate` contract on the root chain. As described above, the withdrawal may then be enqueued into the withdrawal queue. Each `receiver` account has their own withdrawal queue, where the `receiver` is the recipient of the withdrawal. After the withdrawal delay, anyone can call the `RootERC20BridgeFlowRate` contract’s `finaliseQueuedWithdrawal` function or `finaliseQueuedWithdrawalsAggregated` function to complete the withdrawal.

The withdrawal queue is implemented as a map of arrays:

```solidity
    struct PendingWithdrawal {
        // The account that initiated the cross-chain transfer on the child chain.
        address withdrawer;
        // The token being withdrawn.
        address token;
        // The number of tokens.
        uint256 amount;
        // The time when the withdraw was requested. The pending withdrawal can be
        // withdrawn at time timestamp + withdrawalDelay. Note that it is possible
        // that the withdrawalDelay is updated while the withdrawal is still pending.
        uint256 timestamp;
    }
    // Mapping of user addresses to withdrawal queue.
    mapping(address => PendingWithdrawal[]) private pendingWithdrawals;
```

Each `receiver` account has their own array of `PendingWithdrawal` structures. New withdrawals are added to the end of the array. Users can choose to finalise any withdrawal. That is, they do not need to finalise withdrawals that they are not interested in. This is important as `receiver` accounts could be sent _attack_ tokens that cause ERC 20 `transfer` to fail, or they could be sent low value tokens that would cost more to finalise than they are worth.

The timestamp is the block timestamp when the withdrawal entered the queue. That is, when the `_withdraw()` function was called on the `RootERC20BridgeFlowRate` contract. The withdrawal delay is added to this time when assessing if the withdrawal can be finalised. Adding the withdrawal delay when the withdrawal is being finalised, rather than when it entered the queue means than changes to the withdrawal queue affect all withdrawals in all queues.

Users know which withdrawals in their withdrawal queue to finalise in the following ways:

- By observing `QueuedWithdrawal` events which are emitted when a withdrawal is enqueued. This event includes the offset into the array of the withdrawal, known as the index.
- By calling `getPendingWithdrawals` to get information about pending withdrawals with certain indices.
- By calling `findPendingWithdrawals` to fetch information about pending withdrawals based on a token type.

### Flow Rate Detection

The flow rate detection mechanism operates using a bucket system. This can be likened to a bucket that's constantly filled with water. Glasses of varying sizes can take water from this bucket. If the bucket, initially full, ever gets emptied by the glasses, it signifies that the inflow rate of water has been exceeded.

Each token has its own virtual bucket. Each bucket has a capacity, which is the total number of tokens the bucket can hold, the current depth, the refill rate, and the time when tokens were last removed from the bucket. The refill rate is the number of tokens added to the bucket each second. The capacity is the refill rate multiplied by the period over which the flow rate will be averaged. For instance, if the flow rate was going to be 10,000,000,000 tokens per hour, then the capacity and refill rate can be calculated as:

```
  capacity = 10_000_000_000
  refill rate = capacity ÷ (60 minutes per hour x 60 seconds per minute)
              = 10_000_000_000 ÷ (60 x 60)
              = 2_777_777
```

A possible issue with this methodology is that the calculations are quantized, being subject to rounding issues. That is, rather than using floating point numbers, integers are used. For the tokens envisaged to be used in the Immutable system, rounding issues should not present a problem as the ERC 20 contracts have been configured to have large numbers of decimal places. For instance, IMX and MATIC have 18 decimal places configured, as will the wrapped Ether.

The `_updateFlowRateBucket` function in [`FlowRateDetection.sol`](../src/root/flowrate/FlowRateDetection.sol) implements the bucket update calculations.

---

## Glossary
- **General Message Passing (GMP) bridge**: A bridge that enables the transfer of arbitrary messages between two chains. The GMP bridge used by the Immutable zkEVM token bridge is [Axelar](https://axelar.network/).
- **Token bridge**: A bridge that enables the transfer of tokens between two chains, using an underlying GMP. The Immutable zkEVM bridge is a token bridge.
- **Root chain**: Refers to Ethereum, which is also referred to as the L1 in this document.
- **Child chain**: Refers to the Immutable Chain, which is also referred to as the L2 in this document.
- **Layer 1 (L1)**: Refers to Ethereum, which is also referred to as the Root chain in this document.
- **Layer 2 (L2)**: Refers to Immutable zkEVM, which is also referred to as the Child chain in this document.
- **Root token**: An original token that is deployed on the Root chain.
- **Child token**: A wrapped token that is deployed on the Child chain, which is used to represent the Root token on the Child chain.

## Appendix A: Smart Contract State Mutation Functions
**RootERC20BridgeFlowRate**

The `RootERC20BridgeFlowRate` contract is the contract that users will interact with on the Root chain in order to bridge their assets.
The table below lists all the state mutating methods in the contract. In this table, methods that involve privileged operations are listed first.

| Method Name                                                                                                     | Function Selector | Access Control          |
|-----------------------------------------------------------------------------------------------------------------|-------------------|-------------------------|
| `grantRole(bytes32,address)`                                                                                    | `2f2ff15d`        | `DEFAULT_ADMIN`         |
| `revokeRole(bytes32,address)`                                                                                   | `d547741f`        | `DEFAULT_ADMIN`         |
| `grantPauserRole(address)`                                                                                      | `6c11c21c`        | `DEFAULT_ADMIN`         |
| `revokePauserRole(address)`                                                                                     | `f865af08`        | `DEFAULT_ADMIN`         |
| `grantUnpauserRole(address)`                                                                                    | `32968782`        | `DEFAULT_ADMIN`         |
| `revokeUnpauserRole(address)`                                                                                   | `2540e2da`        | `DEFAULT_ADMIN`         |
| `grantAdaptorManagerRole(address)`                                                                              | `8f70121f`        | `DEFAULT_ADMIN`         |
| `revokeAdaptorManagerRole(address)`                                                                             | `89c65d41`        | `DEFAULT_ADMIN`         |
| `grantVariableManagerRole(address)`                                                                             | `07b2b7ad`        | `DEFAULT_ADMIN`         |
| `revokeVariableManagerRole(address)`                                                                            | `6066ae87`        | `DEFAULT_ADMIN`         |
| `renounceRole(bytes32,address)`                                                                                 | `36568abe`        | `DEFAULT_ADMIN`         |
| `updateImxCumulativeDepositLimit(uint256)`                                                                      | `d68d5fd6`        | `VARIABLE_MANAGER_ROLE` |
| `updateRootBridgeAdaptor(address)`                                                                              | `a8deae56`        | `ADAPTOR_MANAGER_ROLE`  |
| `setWithdrawalDelay(uint256)`                                                                                   | `d2c13da5`        | `RATE_ROLE`             |
| `setRateControlThreshold(address,uint256,uint256,uint256)`                                                      | `8f3a4e4f`        | `RATE_ROLE`             |
| `activateWithdrawalQueue()`                                                                                     | `af8bbb5e`        | `RATE_ROLE`             |
| `deactivateWithdrawalQueue()`                                                                                   | `1657a6e5`        | `RATE_ROLE`             |
| `pause()`                                                                                                       | `8456cb59`        | `PAUSER_ROLE`           |
| `unpause()`                                                                                                     | `3f4ba83a`        | `UNPAUSER_ROLE`         |
| `onMessageReceive(bytes)`                                                                                       | `7248c77c`        | (Only Bridge Adaptor)   |
| `initialize((address,address,address,address,address),address,address,address,address,address,uint256)`         | `c880d915`        | -                       |
| `initialize((address,address,address,address,address),address,address,address,address,address,uint256,address)` | `0800dd27`        | -                       |
| `mapToken(address)`                                                                                             | `f4a120f7`        | -                       |
| `deposit(address,uint256)`                                                                                      | `47e7ef24`        | -                       |
| `depositETH(uint256)`                                                                                           | `5358fbda`        | -                       |
| `depositTo(address,address,uint256)`                                                                            | `f213159c`        | -                       |
| `depositToETH(address,uint256)`                                                                                 | `e0410432`        | -                       |
| `finaliseQueuedWithdrawal(address,uint256)`                                                                     | `3a7a228e`        | -                       |
| `finaliseQueuedWithdrawalsAggregated(address,address,uint256[])`                                                | `5d3a22ab`        | -                       |

**RootAxelarBridgeAdaptor**

The `RootAxelarBridgeAdaptor` contract is the contract that enables `RootERC20BridgeFlowRate` contract to send and receive messages using the Axelar GMP bridge.
The table below lists all the state mutating methods in the contract. In this table, methods that involve privileged operations are listed first.

| Method Name                                                                   | Function Selector | Access Control              |
|-------------------------------------------------------------------------------|-------------------|-----------------------------|
| `grantBridgeManager(address)`                                                 | `a76d8067`        | `DEFAULT_ADMIN`             |
| `grantGasServiceManager(address)`                                             | `2ee5d49e`        | `DEFAULT_ADMIN`             |
| `grantRole(bytes32,address)`                                                  | `2f2ff15d`        | `DEFAULT_ADMIN`             |
| `grantTargetManagerRole(address)`                                             | `96d220ce`        | `DEFAULT_ADMIN`             |
| `renounceRole(bytes32,address)`                                               | `36568abe`        | `DEFAULT_ADMIN`             |
| `revokeBridgeManagerRole(address)`                                            | `7d9da79b`        | `DEFAULT_ADMIN`             |
| `revokeGasServiceManagerRole(address)`                                        | `bd655992`        | `DEFAULT_ADMIN`             |
| `revokeRole(bytes32,address)`                                                 | `d547741f`        | `DEFAULT_ADMIN`             |
| `revokeTargetManagerRole(address)`                                            | `8e6444a8`        | `DEFAULT_ADMIN`             |
| `updateChildBridgeAdaptor(string)`                                            | `0bbf3766`        | `TARGET_MANAGER_ROLE`       |
| `updateChildChain(string)`                                                    | `17a0e3e2`        | `TARGET_MANAGER_ROLE`       |
| `updateGasService(address)`                                                   | `3bed20e8`        | `GAS_SERVICE_MANAGER_ROLE`  |
| `updateRootBridge(address)`                                                   | `e4426af4`        | `BRIDGE_MANAGER_ROLE`       |
| `sendMessage(bytes,address)`                                                  | `f20755ba`        | (Only Root Bridge Contract) |
| `initialize((address,address,address,address),address,string,string,address)` | `381fe249`        | -                           |
| `execute(bytes32,string,string,bytes)`                                        | `49160658`        | -                           |


**ChildERC20Bridge**

The `ChildERC20Bridge` contract is the contract that users will interact with on the Child chain in order to bridge their assets.
The table below lists all the state mutating methods in the contract. In this table, methods that involve privileged operations are listed first.

| Method Name                                                                                     | Function Selector | Access Control              |
|-------------------------------------------------------------------------------------------------|-------------------|-----------------------------|
| `privilegedDeposit()`                                                                           | `18428c50`        | `PRIVILEGED_DEPOSITOR_ROLE` |
| `grantAdaptorManagerRole(address)`                                                              | `8f70121f`        | `DEFAULT_ADMIN`             |
| `grantPauserRole(address)`                                                                      | `6c11c21c`        | `DEFAULT_ADMIN`             |
| `grantRole(bytes32,address)`                                                                    | `2f2ff15d`        | `DEFAULT_ADMIN`             |
| `grantUnpauserRole(address)`                                                                    | `32968782`        | `DEFAULT_ADMIN`             |
| `renounceRole(bytes32,address)`                                                                 | `36568abe`        | `DEFAULT_ADMIN`             |
| `revokeAdaptorManagerRole(address)`                                                             | `89c65d41`        | `DEFAULT_ADMIN`             |
| `revokePauserRole(address)`                                                                     | `f865af08`        | `DEFAULT_ADMIN`             |
| `revokeRole(bytes32,address)`                                                                   | `d547741f`        | `DEFAULT_ADMIN`             |
| `revokeUnpauserRole(address)`                                                                   | `2540e2da`        | `DEFAULT_ADMIN`             |
| `pause()`                                                                                       | `8456cb59`        | `PAUSER_ROLE`               |
| `unpause()`                                                                                     | `3f4ba83a`        | `UNPAUSER_ROLE`             |
| `updateChildBridgeAdaptor(address)`                                                             | `0765c405`        | `ADAPTOR_MANAGER_ROLE`      |
| `initialize((address,address,address,address,address,address),address,address,address,address)` | `f3dfce1d`        | -                           |
| `withdraw(address,uint256)`                                                                     | `f3fef3a3`        | -                           |
| `withdrawETH(uint256)`                                                                          | `f14210a6`        | -                           |
| `withdrawETHTo(address,uint256)`                                                                | `697b894a`        | -                           |
| `withdrawIMX(uint256)`                                                                          | `de65c2e4`        | -                           |
| `withdrawIMXTo(address,uint256)`                                                                | `92ffd2e2`        | -                           |
| `withdrawTo(address,address,uint256)`                                                           | `c3b35a7e`        | -                           |
| `withdrawWIMX(uint256)`                                                                         | `52b61e36`        | -                           |
| `withdrawWIMXTo(address,uint256)`                                                               | `274346b9`        | -                           |


**ChildAxelarBridgeAdaptor**

The `ChildAxelarBridgeAdaptor` contract is the contract that enables `ChildERC20Bridge` contract to send and receive messages using the Axelar GMP bridge.
The table below lists all the state mutating methods in the contract. In this table, methods that involve privileged operations are listed first.

| Method Name                                                                   | Function Selector | Access Control               |
|-------------------------------------------------------------------------------|-------------------|------------------------------|
| `grantBridgeManager(address)`                                                 | `a76d8067`        | `DEFAULT_ADMIN`              |
| `grantGasServiceManager(address)`                                             | `2ee5d49e`        | `DEFAULT_ADMIN`              |
| `grantRole(bytes32,address)`                                                  | `2f2ff15d`        | `DEFAULT_ADMIN`              |
| `grantTargetManagerRole(address)`                                             | `96d220ce`        | `DEFAULT_ADMIN`              |
| `renounceRole(bytes32,address)`                                               | `36568abe`        | `DEFAULT_ADMIN`              |
| `revokeBridgeManagerRole(address)`                                            | `7d9da79b`        | `DEFAULT_ADMIN`              |
| `revokeGasServiceManagerRole(address)`                                        | `bd655992`        | `DEFAULT_ADMIN`              |
| `revokeRole(bytes32,address)`                                                 | `d547741f`        | `DEFAULT_ADMIN`              |
| `revokeTargetManagerRole(address)`                                            | `8e6444a8`        | `DEFAULT_ADMIN`              |
| `updateChildBridge(address)`                                                  | `49ffc2e8`        | `BRIDGE_MANAGER_ROLE`        |
| `updateGasService(address)`                                                   | `3bed20e8`        | `GAS_SERVICE_MANAGER_ROLE`   |
| `updateRootBridgeAdaptor(string)`                                             | `fab10bd6`        | `TARGET_MANAGER_ROLE`        |
| `updateRootChain(string)`                                                     | `8f2e3f38`        | `TARGET_MANAGER_ROLE`        |
| `sendMessage(bytes,address)`                                                  | `f20755ba`        | (Only Child Bridge Contract) |
| `initialize((address,address,address,address),address,string,string,address)` | `381fe249`        | -                            |
| `execute(bytes32,string,string,bytes)`                                        | `49160658`        | -                            |


**ChildERC20**

The `ChildERC20` contract is the contract that represents ERC20 tokens on the Child chain.
The table below lists all the state mutating methods in the contract. In this table, methods that involve privileged operations are listed first.


| Method Name                                                   | Function Selector | Access Control               |
|---------------------------------------------------------------|-------------------|------------------------------|
| `burn(address,uint256)`                                       | `9dc29fac`        | (Only Child Bridge Contract) |
| `mint(address,uint256)`                                       | `40c10f19`        | (Only Child Bridge Contract) |
| `initialize(address,string,string,uint8)`                     | `f6d2ee86`        | -                            |
| `decreaseAllowance(address,uint256)`                          | `a457c2d7`        | -                            |
| `executeMetaTransaction(address,bytes,bytes32,bytes32,uint8)` | `0c53c51c`        | -                            |
| `increaseAllowance(address,uint256)`                          | `39509351`        | -                            |
| `invalidateNext(uint256)`                                     | `9b77ef11`        | -                            |
| `transfer(address,uint256)`                                   | `a9059cbb`        | -                            |
| `transferFrom(address,address,uint256)`                       | `23b872dd`        | -                            |
