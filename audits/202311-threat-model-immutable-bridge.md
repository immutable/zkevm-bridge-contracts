# ERC20 and Ether Bridge Threat Model

# Contents

- [Introduction](#introduction)
- [Architecture](#architecture)
- [Attack Surfaces](#attack-surfaces)
- [Perceived Attackers](#preceived-attackers)
- [Attack Mitigation](#attack-mitigation)
- [Conclusion](#conclusion)

# Introduction

This document is a threat model for Ether and ERC 20 bridge changes that Immutable have build to integrate with the Axelar GMP, General Messaging Passing bridge. The Immutable token bridge contract was built from a fork of Polygon Edge's RootERC20Predicate and ChildERC20Predicate contract. Most of the Edge-specific functionality was removed.

############################################################################################################
############################################################################################################

This document is a threat model for the Ether and ERC 20 bridge changes that Immutable made to Polygon's ERC 20 bridge in preparation for external audit. The changes are generally additive, building on top of code that has been audited at multiple stages during development by Polygon. The version of code that the changes described in this report build on are identical to a code set that is in the process of being audited by Polygon.

The threat model is limited to the following Solidity file: `RootERC20PredicateFlowRate.sol`, and the contracts that it includes: `RootERC20Predicate.sol`, `IRootERC20Predicate.sol`, `IL2StateReceiver.sol`, `FlowRateDetection.sol`, and `FlowRateWithdrawalQueue.sol`. See the [Source Code](#source-code) for links to these files and more information about the how the code has been tested.

The changes made to the ERC 20 Bridge are security related plus enabling Ether
transfer. The changes only relate to the ERC 20 bridge designed to bridge tokens
that originates on Ethereum to the Immutable zkEVM; and not to a bridge that
would allow tokens created on the Immutable zkEVM to be bridged to Ethereum.

The features of the enhancements are:

- Add Ether support. Ether is represented on Immutable zkEVM as wrapped
  Ether, an ERC 20 token. Note that it is intended that wrapped Ether on Immutable
  zkEVM be separate from wrapped wEth from Ethereum that might be bridged to
  Immutable zkEVM.
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

Almost all users will be unaffected by the security enhancements. For them the bridge will appear to operate as if `RootERC20Predicate` contract had been deployed. That is, almost all withdrawals will not go into a withdrawal queue if the
`RootERC20PredicateFlowRate` contract has been configured for all tokens
that are likely to be used on the bridge with appropriate thresholds.

# Architecture

## Overview of Immutable zkEVM to Ethereum Bridge

### Immutable zkEVM, App Chains, and Ethereum

The diagram below shows the top level architecture of the system.

![Bridge Layering](./202308-threat-model-erc20-bridge-diagrams/top-level-architecture.png)

The Immutable zkEVM will be a Validium using a Proof of Stake (PoS) blockchain to determine the sequence of transactions. Zero knowledge proofs will be posted to Ethereum, though initially, no proofs will be posted. The validators of the Immutable zkEVM operate the bridge between Ethereum and the Immutable zkEVM. The bridge has a set of contracts on the Immutable zkEVM called collectively as Child Chain Bridge Contracts, and on Ethereum called collectively as Root Chain Bridge Contracts.

Immutable may deploy other App Chains. Each of these chains would have their own set of bridge contracts, operated by the validators of each App Chain.

### Bridge Layering

The bridge design is a layered approach. Application level bridges rely on the Arbitrary Message Bridge to communicate messages across chains.

![Bridge Layering](./202308-threat-model-erc20-bridge-diagrams/bridge-layers.png)

That is, the ERC 20 bridge takes a set of parameters: token type, amount, sender on the source chain and recipient on the target chain. This information is packaged as a message. From the Arbitrary Message Bridge’s perspective, it is routing a blob of data from a contract on the source chain to a contract on the target chain.

### Bi-directional Bridges

Crosschain Bridges are unidirectional. Bi-directional bridges are constructed by using two unidirectional bridges. This means that the mechanics of the Arbitrary Message Bridge and the application bridge that sit on top of it can be completely different for the different directions of the bridge. Importantly, it means that the ERC 20 bridge can operate differently in the Immutable zkEVM to Ethereum direction compared to the Ethereum to Immutable zkEVM direction.

![Bi-directional Bridges](./202308-threat-model-erc20-bridge-diagrams/bi-directional-bridges.png)

### Bridges as Honey Pots for Attackers

When users transfer value from Ethereum to the Immutable zkEVM, at a high level, the flow is as shown in the diagram below.

![Honey Pot](./202308-threat-model-erc20-bridge-diagrams/honey-pot.png)

The flow is:

- The user submits a transaction to the ERC 20 contract to approve of the bridge transferring some value on their behalf.
- The user submits a transaction to the ERC 20 bridge contract to request a crosschain transfer. This is the deposit function. They specify the ERC 20 contract, and the number of tokens (the amount), and the recipient address on the Immutable zkEVM. The ERC 20 bridge contract transfers the tokens from the user to their own address. That is, the tokens are now owned by the ERC 20 bridge contract.
- The Immutable zkEVM validators cooperate to make the crosschain transaction happen. For the purposes of this section, the details are not important. The result is that the ERC 20 bridge contract on Immutable zkEVM mints some new wrapped tokens and transfers them to the recipient.
- The user can now submit a view call to check their balance.

What this means is that if the Immutable zkEVM "holds", say $1B, then all of that money will be owned by the ERC 20 bridge contract on Ethereum. This makes the contract and the systems controlling the contract a huge target, typically called a honey pot.

### Ethereum to Immutable zkEVM ERC 20 Bridge Flow

The detailed deposit flow is shown below.

![Deposit Detail](./202308-threat-model-erc20-bridge-diagrams/deposit-detail.png)

The steps are:

1. User submits a transaction to ERC 20 `approve` the bridge contract transferring some of their tokens.
2. User submits a transaction to call `deposit` on the `RootERC20Predicate` contract.
3. `RootERC20Predicate` contract transfers the number of tokens to be transferred in the crosschain transfer from the user to itself. That is, the `RootERC20Predicate` contract holds the tokens in escrow while the tokens are on the Immutable zkEVM.
4. `RootERC20Predicate` contract calls `syncState` on the `StateSender` contract. This function wraps the details of the transfer into a data blob.
5. `StateSender` contract emits an event indicating the information for the crosschain transfer. That is, the crosschain transfer id, sending contract (`RootERC20Predicate`), target contract address (`ChildERC20Predicate`) and the data blob.
6. Validators monitor Ethereum. They put the event into a Merkle Tree. They cooperatively BLS aggregated threshold sign the root of the Merkle Tree once each Sprint (set to 5 blocks / 10 seconds for our deployment). At the end of each Sprint, the validator that is the block proposer submits a transaction containing the signed Merkle root and submits this to the `StateReceiver` contract.
7. The user submits a transaction calling the `StateReceiver` contract’s `execute` function.
8. The `StateReceiver` contract calls the `ChildERC20Predicate` contract’s `onStateReceive` function.
9. The `ChildERC20Predicate` contract decodes the message and uses the decoded message type to determine that it should call its own `_deposit` function.
10. The `ChildERC20Predicate` contract’s `_deposit` function calls `mint` on the ERC 20 contract, to give tokens to the user.

Alternative flows:

- Ether is transferred by calling the `depositNative` function in step 2, and not having the step 1.

### Immutable zkEVM to Ethereum ERC 20 Bridge Flow

The detailed withdrawal flow is shown below.

![Withdrawal Detail](./202308-threat-model-erc20-bridge-diagrams/withdrawal-detail.png)

The steps are:

1. User submits a transaction to ERC 20 `approve` the bridge contract transferring or burning some of their tokens.
2. User submits a transaction to call `withdraw` on the `ChildERC20Predicate` contract.
3. `ChildERC20Predicate` contract burns the tokens to be transferred.
4. `ChildERC20Predicate` contract calls `syncState` on the `L2StateSender` contract. This function wraps the details of the transfer into a data blob.
5. `L2StateSender` contract emits an event indicating the information for the crosschain transfer. THat is the crosschain transfer id, sending contract (`ChildERC20Predicate`), target contract address (`RootERC20Predicate`) and the data blob.
6. Validators put the event into a Merkle Tree. They cooperatively BLS threshold aggregated sign the root of the Merkle Tree once each Epoch (set to 300 blocks / 10 minutes for our deployment). At the end of each Epoch, the validator that is the block proposer submits a transaction containing the signed Merkle root and submits this to the `CheckpointManager` contract. The information submitted is known as a Check Point.
7. The user submits a transaction calling the `ExitHelper` contract’s `exit` function.
8. The `ExitHelper` contract checks that the event information is correct by calling the `CheckPointManager` contract.
9. The `ExitHelper` contract calls the `RootERC20Predicate` contract’s `onL2StateReceive` function.
10. The `RootERC20Predicate` contract decodes the message and uses the decoded message type to determine that it should call its own `_withdraw` function.
11. The `RootERC20Predicate` contract’s `withdraw` function calls `transfer` on the ERC 20 contract, to transfer tokens to the user.

Alternative flows:

- If the transferred ERC 20 represents Ether on Ethereum, then for step 11, rather than calling `transfer`, the Ether is sent to the user via a call.
- In certain situations described later in this document, if an `RootERC20PredicateFlowRate.sol` is used for the Ethereum side ERC 20 bridge, the withdrawal may be placed in a queue. Further function calls are needed to withdraw the tokens from the withdrawal queue.

## RootERC20Predicate Improvements

### Overall Design Approach

The changes have been restricted to the "Root ERC 20 Predicate" box in the diagrams above. For the Ether support, the changes have been added to the `RootERC20Predicate` contract directly. For the security features, the `RootERC20PredicateFlowRate` contract has been created, which extends the `RootERC20Predicate` contract. In this way, the plain ERC 20 bridge can be deployed, or the security enhanced ERC 20 bridge can be deployed.

### Ether Support

To add Ether support to `RootERC20Predicate`, a special address has been defined that corresponds to Ether.

```
    address public constant NATIVE_TOKEN = address(1);
```

When Ether is deposited, this virtual token is bridged to the Immutable zkEVM. When this token is withdrawn, it is converted back to Ether.

Ether support was added to the bridge as an alternative to users buying, then ERC 20 approving, wrapped Ether (wETH), and finally depositing their wETH. It was felt that two additional transactions on Ethereum was a high cost. Additionally, when users withdrew their value from the Immutable zkEVM, they would need to convert the wETH back to Ether.

A downside of directly transferring Ether rather than requiring users to first wrap their Ether as wETH is that bridged Ether and bridged wETH will be separate ERC 20s on Immutable zkEVM. This downside is acknowledged by Immutable and not seen as a defect.

### Pausing Bridge

`RootERC20PredicateFlowRate` allows deposits and withdrawals to be paused. To pause the bridge, the `pause` function is called by an account that has `PAUSE` role. To unpause the bridge, the `unpause` function is called by an account that has `UNPAUSE` role. The rationale for having separate roles for pause and unpause is that the multi-sig wallet for pausing might require fewer signers to agree than the multi-sig wallet to unpause the bridge. For example, the "pause" multi-sig might require 3 of 11 signers whereas the unpause multi-sig might require 7 of 11 signers. In this way, the bridge should be able to be paused more quickly. However, if an attacker has compromised multiple admin accounts, they will not be able to unpause the bridge.

The functions that the pausing capability controls is:

- `deposit`
- `depositTo`
- `depositNativeTo`
- `_withdrawaw`
- `finaliseQueuedWithdrawal`
- `finaliseQueuedWithdrawalsAggregated`

### Rate Administration and Withdrawal Queue

`RootERC20PredicateFlowRate` has a withdrawal queue. The rationale for having a queue is to give teams monitoring the bridge time to determine if suspicious withdrawals are valid or are in-progress attacks. Withdrawals enter the withdrawal queue in the following scenarios:

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

### Withdrawal Queue Implementation

When a crosschain transfer from Immutable zkEVM to Ethereum occurs, the user will call the `ExitHelper` contract’s `exit` function with the event information emitted from the Immutable zkEVM. This results in the `RootERC20PredicateFlowRate` contract’s `_withdraw` function being called. As described above, the withdrawal may then be enqueued into the withdrawal queue. Each `receiver` account has their own withdrawal queue, where the `receiver` is the recipient of the withdrawal. After the withdrawal delay, anyone can call the `RootERC20PredicateFlowRate` contract’s `finaliseQueuedWithdrawal` function or `finaliseQueuedWithdrawalsAggregated` function to complete the withdrawal.

The withdrawal queue is implemented as a map of arrays:

```solidity
    struct PendingWithdrawal {
        // The account that initiated the crosschain transfer on the child chain.
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

The timestamp is the block timestamp when the withdrawal entered the queue. That is, when `ExitHelper`'s `exit` function was called. The withdrawal delay is added to this time when assessing if the withdrawal can be finalised. Adding the withdrawal delay when the withdrawal is being finalised, rather than when it entered the queue means than changes to the withdrawal queue affect all withdrawals in all queues.

Users know which withdrawals in their withdrawal queue to finalise in the following ways:

- By observing `QueuedWithdrawal` events which are emitted when a withdrawal is enqueued. This event includes the offset into the array of the withdrawal, known as the index.
- By calling `getPendingWithdrawals` to get information about pending withdrawals with certain indices.
- By calling `findPendingWithdrawals` to fetch information about pending withdrawals based on a token type.

### Flow Rate Detection

The flow rate of a token is detected using the bucket approach shown diagrammatically below.

![Withdrawal Detail](./202308-threat-model-erc20-bridge-diagrams/bucket.png)

In the diagram, water flows into the bucket at a constant rate. Water is removed from the bucket using varying sized glasses. Assume that the buckets starts off full. If the glasses removing water from the bucket ever empty the bucket, it indicates that they have exceeded the flow rate of water coming into the bucket.

Each token has its own virtual bucket. Each bucket has a capacity, which is the total number of tokens the bucket can hold, the current depth, the refill rate, and the time when tokens were last removed from the bucket. The refill rate is the number of tokens added to the bucket each second. The capacity is the refill rate multiplied by the period over which the flow rate will be averaged. For instance, if the flow rate was going to be 10,000,000,000 tokens per hour, then the capacity and refill rate can be calculated as:

```
  capacity = 10000000000
  refill rate = capacity ÷ (60 minutes per hour x 60 seconds per minute)
              = 10000000000 ÷ (60 x 60)
              = 2777777
```

A possible issue with this methodology is that the calculations are quantized, being subject to rounding issues. That is, rather than using floating point numbers, integers are used. For the tokens envisaged to be used in the Immutable system, rounding issues should not present a problem as the ERC 20 contracts have been configured to have large numbers of decimal places. For instance, IMX and MATIC have 18 decimal places configured, as will the wrapped Ether.

The `_updateFlowRateBucket` function in `FlowRateDetection.sol` implements the bucket update calculations.

## Other Information

This section provides links to all source code, test plans, test code.

### Source Code

This threat model pertains to the following source code:

- [RootERC20PredicateFlowRate.sol](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/contracts/root/flowrate/RootERC20PredicateFlowRate.sol): Version of ERC 20 Bridge contract to be deployed on Ethereum for ERC 20 tokens that originate on Ethereum, that includes security features.
- [RootERC20Predicate](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/contracts/root/RootERC20Predicate.sol): Version of ERC 20 Bridge contract to be deployed on Ethereum for ERC 20 tokens that originate on Ethereum. This contract is extended by RootERC20PredicateFlowRate.sol.
- [IL2StateReceiver.sol](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/contracts/interfaces/root/IL2StateReceiver.sol): Interface for contracts that receive messages from Immutable zkEVM.
- [IRootERC20Predicate.sol](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/contracts/interfaces/root/IRootERC20Predicate.sol): Interface describing the public interface of RootERC20Predicate.sol. Extends IL2StateReceiver.sol.
- [FlowRateDetection.sol](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/contracts/root/flowrate/FlowRateDetection.sol): Abstract contract that implements flow rate detection. This contract is extended by RootERC20PredicateFlowRate.sol.
- [FlowRateWithdrawalQueue.sol](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/contracts/root/flowrate/FlowRateWithdrawalQueue.sol): Abstract contract that implements a withdrawal queue. This contract is extended by RootERC20PredicateFlowRate.sol.

Note: In source code, the term _L2_ and _Child_ is used to refer to the Immutable zkEVM
and _L1_ or _Root_ is used to refer to Ethereum.

### Test Plans

The following test plans were created to evaluate the tests required for adding Ether support and the security enhancements to the ERC 20 bridge. All tests described in the test plans were implemented.

- [Root ERC 20 Predicate, Ether Support](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/test/forge/root/RootERC20Predicate.tree)
- [Root ERC 20 Predicate, Security Enhancements](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/test/forge/root/flowrate/README.md)

### Test Code

The following test code was created to test the ERC 20 bridge Ether support and security enhancements.

- [Tests for RootERC20Predicate.sol, focusing on Ether support](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/test/forge/root/RootERC20Predicate.t.sol)
- [Tests for FlowRateWithdrawalQueue.sol](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/test/forge/root/flowrate/FlowRateWithdrawalQueue.t.sol)
- [Tests for FlowRateDetection.sol](https://github.com/immutable/poly-core-contracts/blob/flow-control-bridge3/test/forge/root/flowrate/FlowRateDetection.t.sol)
- [Tests for RootERC20PredicateFlowRate.sol](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/test/forge/root/flowrate/RootERC20PredicateFlowRate.t.sol)

These tests were in addition to the [existing tests for RootERC20Predicate](https://github.com/immutable/poly-core-contracts/blob/flow-control-bridge3/test/root/RootERC20Predicate.test.ts).

### Continuous Integration

Each time a commit is pushed to a pull request, the [continuous integration loop executes](https://github.com/immutable/poly-core-contracts/actions).

### Building, Testing, Coverage and Static Code Analysis

For instructions on building the code, running tests, coverage, and Slither, see the [Using this Repo](https://github.com/immutable/poly-core-contracts/blob/d0a3be95ac9d2d7820903558d4668197f9d77d9a/README.md#using-this-repo) section of the README.md at the root of this repo.

# Attack Surfaces

The following sections list attack surfaces evaluated as part of this threat modelling exercise.

## RootERC20PredicateFlowRate Externally Visible Functions

This section describes the externally visible functions available in `RootERC20PredicateFlowRate`. An attacker could formulate an attack in which they send one or more transactions that execute one or more of these functions.

The table below shows the list of externally visible functions. In addition to the name and function selector, the function type (transaction or view), and access control mechanisms are listed.

The list of functions and their function selectors was determined by the following command. The additional information was obtained by reviewing the code.

```
cd contracts/root/flowrate
forge inspect RootERC20PredicateFlowRate --pretty methods
```

| Name                                                                                 | Function Selector | Type        | Access Control       |
| ------------------------------------------------------------------------------------ | ----------------- | ----------- | -------------------- |
| DEFAULT_ADMIN_ROLE()                                                                 | a217fddf          | view        | -                    |
| DEPOSIT_SIG()                                                                        | d41f1771          | view        | -                    |
| MAP_TOKEN_SIG()                                                                      | f6451255          | view        | -                    |
| NATIVE_TOKEN()                                                                       | 31f7d964          | view        | -                    |
| WITHDRAW_SIG()                                                                       | b1768065          | view        | -                    |
| activateWithdrawalQueue()                                                            | af8bbb5e          | transaction | RATE role            |
| childERC20Predicate()                                                                | d57184e4          | view        | -                    |
| childTokenTemplate()                                                                 | b68ad1e4          | view        | -                    |
| deactivateWithdrawalQueue()                                                          | 1657a6e5          | transaction | RATE role            |
| deposit(address,uint256)                                                             | 47e7ef24          | transactoin | None                 |
| depositNativeTo(address)                                                             | 8ca41808          | transaction | None                 |
| depositTo(address,address,uint256)                                                   | f213159c          | transaction | None                 |
| exitHelper()                                                                         | 95c7041c          | view        | -                    |
| finaliseQueuedWithdrawal(address,uint256)                                            | 3a7a228e          | transaction | None                 |
| finaliseQueuedWithdrawalsAggregated(address,address,uint256[])                       | 5d3a22ab          | transaction | None                 |
| findPendingWithdrawals(address,address,uint256,uint256,uint256)                      | 2bf83911          | view        | -                    |
| flowRateBuckets(address)                                                             | 366963ea          | view        | -                    |
| getPendingWithdrawals(address,uint256[])                                             | 28a6ff1e          | view        | -                    |
| getPendingWithdrawalsLength(address)                                                 | 7b1929b7          | view        | -                    |
| getRoleAdmin(bytes32)                                                                | 248a9ca3          | view        | -                    |
| grantRole(bytes32,address)                                                           | 2f2ff15d          | transaction | Role Admin for role. |
| hasRole(bytes32,address)                                                             | 91d14854          | view        | -                    |
| initialize(address,address,address,address,address)                                  | 1459457a          | transaction | Reverts              |
| initialize(address,address,address,address,address, address,address,address,address) | f5e95acb          | transaction | First time init      |
| largeTransferThresholds(address)                                                     | 84a3291a          | view        | -                    |
| mapToken(address)                                                                    | f4a120f7          | transaction | None                 |
| onL2StateReceive(uint256,address,bytes)                                              | f43cda8b          | transaction | ExitHelper contract  |
| pause()                                                                              | 8456cb59          | transaction | PAUSE role           |
| paused()                                                                             | 5c975abb          | view        | -                    |
| renounceRole(bytes32,address)                                                        | 36568abe          | transaction | msg.sender           |
| revokeRole(bytes32,address)                                                          | d547741f          | transaction | Role Admin for role. |
| rootTokenToChildToken(address)                                                       | 7efab4f5          | view        | -                    |
| setRateControlThreshold(address,uint256,uint256,uint256)                             | 8f3a4e4f          | transaction | RATE role            |
| setWithdrawalDelay(uint256)                                                          | d2c13da5          | transaction | RATE role            |
| stateSender()                                                                        | cb10f94c          | view        | -                    |
| supportsInterface(bytes4)                                                            | 01ffc9a7          | view        | -                    |
| unpause()                                                                            | 3f4ba83a          | transaction | UNPAUSE role         |
| withdrawalDelay()                                                                    | a7ab6961          | view        | -                    |
| withdrawalQueueActivated()                                                           | a6f72cb8          | view        | -                    |

## Root Chain Bridge Contracts

This section defines an attack surface that leads to maliciously executing `RootERC20PredicateFlowRate` contract's `onL2StateReceive` function.

An attacker could formulate a way of compromising the `CheckpointManager.sol` such that malicious exits submitted by the `ExitHelper.sol` were deemed correct. The attacker could use this flaw to submit malicious crosschain communications messages, importantly, withdrawals.

## Child Chain Bridge Contracts

This section defines an attack surface that leads to maliciously executing `RootERC20PredicateFlowRate` contract's `onL2StateReceive` function.

An attacker could formulate a way of compromising `ChildERC20Predicate.sol` or `L2StateSender.sol` such that malicious exits could be generated by these contracts. These malicious exits would be deemed valid by `CheckpointManager.sol` and `ExitHelper.sol`. The attacker could use these malicious exits to execute a malicious withdrawal.

## Immutable zkEVM Validators

This section defines an attack surface that leads to maliciously executing `RootERC20PredicateFlowRate` contract's `onL2StateReceive` function.

A two-thirds majority of validators based on their stake could sign a malicious Check Point, which contained a malicious exit event. Alternatively, an attacker could compromise a validator, and then submit a large amount of stake, thus having more than a two-thirds majority of stake. They could use this voting power to sign a malicious Check Point, which contained a malicious exit event. These malicious exits would be deemed valid by `CheckpointManager.sol` and `ExitHelper.sol`. The attacker could use these malicious exits to execute malicious withdrawals.

## Ethereum Block Timing Attacks

The flow rate and withdrawal queue features of `RootERC20PredicateFlowRate` rely on the block timestamp. As such, the block proposers on Ethereum could manipulate the timestamp of a block to attempt to manipulate whether a withdrawal should enter or be allowed to exit the withdrawal queue.

## Accounts with DEFAULT_ADMIN, PAUSE, UNPAUSE, and RATE roles

Accounts with administrative privileges could be used by attackers to facilitate attacks. For example, an attacker could maliciously pause the bridge thus disrupting the bridge. Alternatively, used in conjunction with other attacks, the attacker could post malicious exits, which might enter the withdrawal queue, and then disable the withdrawal queue. Exploiting this attack surface requires compromising the administrative accounts with certain administrative roles.

## Custom Supernets Manager, Owner role

This section describes an attack surface relating to the ability to add validators, that can then launch attacks against the chain. The [CustomSupernetManager](https://github.com/immutable/poly-core-contracts/blob/802a3391b7cfc02133ddf7c6303ad23a6bdf173d/contracts/root/staking/CustomSupernetManager.sol#L69) contract's `whitelistValidators` function can only be executed by the `Owner` of the contract. If this account was compromised, additional validators could be approved. Once an attacker has approved their own malicious validator, they could add stake to their validator such that they owned more than two-thirds stake. They could use this voting power to sign malicious Check Points.

## RootERC20PredicateFlowRate, ExitHelper, CheckpointManager, CustomSupernetsManager Contract Upgrade

This RootERC20PredicateFlowRate, ExitHelper, CheckpointManager, CustomSupernetsManager, StakeManager, and StateSender contracts are each deployed with a [TransparentUpgradeProxy](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/17c1a3a4584e2cbbca4131f2f1d16168c92f2310/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) and a [Proxy Admin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/17c1a3a4584e2cbbca4131f2f1d16168c92f2310/contracts/proxy/transparent/ProxyAdmin.sol) contract. An account, that can be thought of as the Proxy Administrator, deploys the `TransparentUpgradeProxy` contract and the `ProxyAdmin` contract. This Proxy Administrator can at some later point call the [upgradeAndCall](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/17c1a3a4584e2cbbca4131f2f1d16168c92f2310/contracts/proxy/transparent/ProxyAdmin.sol#L74) function to upgrade the implementation of the contract. The `TransparentUpgradeProxy` contract executes code in the contracts via `delegateCall`, thus executing the code in logic contract in the context of the `TransparentUpgradeProxy` contract. For example, the Proxy Administrator could use the ability to update the implementation of `RootERC20PredicateFlowRate` to deploy a malicious version of the contract.Exploiting this attack surface requires compromising the administrative account responsible for upgrading the contracts.

## RootERC20PredicateFlowRate Contract Storage Slots: Upgrade

An attack vector on future versions of this contract could be misaligned storage slots between a version and the subsequent version. That is, a new storage variable could be added without adjusting the storage gap variable for the file the variable is added to, thus moving the storage locations used by the new version of code relative to the old version of code. To monitor this attack surface, the storage slot utilisation or this initial version is shown in the table below. The table was constructed by using the commands described below.

```
cd contracts/root/flowrate
forge inspect RootERC20PredicateFlowRate --pretty storage
```

| Name                              | Type                                                                   | Slot | Offset | Bytes |
| --------------------------------- | ---------------------------------------------------------------------- | ---- | ------ | ----- |
| \_initialized                     | uint8                                                                  | 0    | 0      | 1     |
| \_initializing                    | bool                                                                   | 0    | 1      | 1     |
| stateSender                       | contract IStateSender                                                  | 0    | 2      | 20    |
| exitHelper                        | address                                                                | 1    | 0      | 20    |
| childERC20Predicate               | address                                                                | 2    | 0      | 20    |
| childTokenTemplate                | address                                                                | 3    | 0      | 20    |
| rootTokenToChildToken             | mapping(address => address)                                            | 4    | 0      | 32    |
| \_\_gapRootERC20Predicate         | uint256[50]                                                            | 5    | 0      | 1600  |
| \_\_gap                           | uint256[50]                                                            | 55   | 0      | 1600  |
| \_paused                          | bool                                                                   | 105  | 0      | 1     |
| \_\_gap                           | uint256[49]                                                            | 106  | 0      | 1568  |
| \_\_gap                           | uint256[50]                                                            | 155  | 0      | 1600  |
| \_roles                           | mapping(bytes32 => struct AccessControlUpgradeable.RoleData)           | 205  | 0      | 32    |
| \_\_gap                           | uint256[49]                                                            | 206  | 0      | 1568  |
| \_status                          | uint256                                                                | 255  | 0      | 32    |
| \_\_gap                           | uint256[49]                                                            | 256  | 0      | 1568  |
| flowRateBuckets                   | mapping(address => struct FlowRateDetection.Bucket)                    | 305  | 0      | 32    |
| withdrawalQueueActivated          | bool                                                                   | 306  | 0      | 1     |
| \_\_gapFlowRateDetecton           | uint256[50]                                                            | 307  | 0      | 1600  |
| pendingWithdrawals                | mapping(address => struct FlowRateWithdrawalQueue.PendingWithdrawal[]) | 357  | 0      | 32    |
| withdrawalDelay                   | uint256                                                                | 358  | 0      | 32    |
| \_\_gapFlowRateWithdrawalQueue    | uint256[50]                                                            | 359  | 0      | 1600  |
| largeTransferThresholds           | mapping(address => uint256)                                            | 409  | 0      | 32    |
| \_\_gapRootERC20PredicateFlowRate | uint256[50]                                                            | 410  | 0      | 1600  |

# Perceived Attackers

This section lists the attackers that could attack the ERC 20 bridge system.

It is assumed that all attackers have access to all documentation and source code of all systems related to the Immutable zkEVM, irrespective of whether the information resides in a public or private GitHub repository, email, Slack, Confluence, or any other information system.

## General Public

The General Public attacker can submit transactions on Ethereum or on the Immutable zkEVM. They use the standard interfaces of contracts to attempt to compromise the briding system.

## MEV Bot

MEV Bots observe transactions in the transaction pool either on Ethereum or on the Immutable zkEVM. They can front run transactions.

## Ethereum Block Proposer

Operator of an Ethereum Block Proposer could, within narrow limits, alter the block time stamp of the block they produce. If this block included transactions related to the withdrawal queue or flow rate mechanism, they might be able to have an affect on this mechanism.

## Spear Phisher

This attacker compromises accounts of people by using Spear Phishing attacks. For example they send a malicious PDF file to a user, which the user opens, the PDF file then installs malware on the user's computer. At this point, it is assumed that the Spear Phisher Attacker can detect all key strokes, mouse clicks, see all information retrieved, see any file in the user's file system, and execute any program on the user's computer.

## Server Powner

This attacker is able to compromise any server computer, _Powerfully Owning_ the computer. For instance, they can compromise a validator node on the Immutable zkEVM. They might do this by finding a buffer overflow vulnerability in the public API of the computer. They can read values from the computer's RAM. Importantly, they can access the BLS private key of the validator node.

## Insider

This attacker works for a company helping operate the Immutable zkEVM. This attacker could be being bribed or blackmailed. They can access the keys that they as an individual employee has access to. For instance, they might be one of the signers of the multi-signer administrative role.

# Attack Mitigation

This section outlines possible attacks against the attack surfaces by the attackers, and how those attacks are mitigated.

## Overview of Attacks on Functions in RootERC20PredicateFlowRate

The functions in RootERC20PredicateFlowRate fall into five categories:

- View functions that don't update state. These functions can not be used to attack the system as they do not alter the state of the blockchain.
- Transaction functions that have access control. These functions are considered in the section [Functions with Access Control](#functions-with-access-control).
- Transaction functions that have no access control. These functions are considered in the section [Functions with no Access Control](#functions-with-no-access-control).
- The `onL2StateReceive(uint256,address,bytes)` function has a form of access control, being limited to only being called by the `ExitHelper`. It is considered in the section [onL2StateReceiver](#onl2statereceive).
- The `initialize(address,address,address,address,address)` function is needed for compatibility with `RootERC20Predicate`. Transactions that call this function in the context of `RootERC20PredicateFlowRate` revert.
- The `initialize(address,address,address,address,address, address,address,address,address)` function can only be called once. It is called by the [TransparentUpgradeProxy](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/17c1a3a4584e2cbbca4131f2f1d16168c92f2310/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) during the `TransparentUpgradeProxy`'s [constructor](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/17c1a3a4584e2cbbca4131f2f1d16168c92f2310/contracts/proxy/ERC1967/ERC1967Proxy.sol#L23), in the [context of the `TransparentUpgradeProxy`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/17c1a3a4584e2cbbca4131f2f1d16168c92f2310/contracts/proxy/ERC1967/ERC1967Upgrade.sol#L62). An attacker could not call this function again in the context of the `TransparentUpgradeProxy`, as it reverts when called a second time. Calling this function on the `RootERC20PredicateFlowRate` contract directly would only change the state of `RootERC20PredicateFlowRate`, and not that of the `TransparentUpgradeProxy`.

## Attacks on RootERC20PredicateFlowRate Functions with no Access Control

The [General Public Attacker](#general-public) could attempt to attack functions with no access control. The [MEV Bot Attacker](#mev-bot) could see transactions to these functions and attempt to front run them. The following sections analyse what a [General Public Attacker](#general-public) and an [MEV Bot Attacker](#mev-bot) could achieve.

### deposit(address,uint256), depositTo(address,address,uint256), and depositNativeTo(address)

The `deposit` and `depositTo` functions allow users to deposit ERC 20 tokens into the bridge, and have them bridged to the Immutable zkEVM. The `depositNativeTo` allows users to deposit Ether into the bridge, and wrapped Ether tokens bridge to the Immutable zkEVM. For the function variants ending in `To`, the recipient account on the Immutable zkEVM can be specified.

Attackers need to supply their own tokens. They are unable to switch the type of token to a more desirable token, or increase the amount of tokens they receive. The [General Public Attacker](#general-public) and the [MEV Bot Attacker](#mev-bot) are unable to mount successful attacks on these functions.

### finaliseQueuedWithdrawal(address,uint256) and finaliseQueuedWithdrawalsAggregated(address,address,uint256[])

The `finaliseQueuedWithdrawal` and the `finaliseQueuedWithdrawalsAggregated` allow withdrawals that are in the withdrawal queue to be dequeued and the funds distributed. Whereas the `finaliseQueuedWithdrawal` finalises one withdrawal, the `finaliseQueuedWithdrawalsAggregated` allows multiple withdrawals for the same token to be accumulated into a single withdrawal, thus saving on gas cost of executing multiple ERC 20 transfers or multiple Ether transfers.

The receiver of the funds is specified in the function call. The receiver only receives tokens or Ether that are in their withdrawal queue, and which have been in the withdrawal queue longer than the withdrawal period. The `finaliseQueuedWithdrawalsAggregated` checks that all withdrawals are for the same specified token.

The [General Public Attacker](#general-public) could send the receiver some coins that the receiver did not want. For example, they could attempt to implicate the receiver in a scandal, by sending the receiver tainted coins. Then, despite the receiver not finalising the tainted coins, a [General Public Attacker](#general-public) could finalise the coins on the receiver's behalf. This is not deemed to be an attack as the account submitting the transaction to `finaliseQueuedWithdrawal` or `finaliseQueuedWithdrawalsAggregated` to dequeue the tainted coins is recorded in Ethereum, and could be readily identified as not being associated with the receiver.

The [MEV Bot Attacker](#mev-bot) can not front run these calls as the tokens are sent to the receiver, and not to `msg.sender`.

The [Ethereum Block Proposer](#ethereum-block-proposer) could mount an attack by slightly altering the [block timestamp](#ethereum-block-timing-attacks). The attacker could force a withdrawal that was on the very of becoming available to have to wait an extra block. Any transactions hoping to finalise the withdrawal would revert as the finalise function call would be deemed too early. The attacker could change the block timestamp slightly, thus causing a withdrawal to cause the automatic flow rate detection mechanism to activate. These attacks seem unlikely to occur because [Ethereum Block Proposers](#ethereum-block-proposer) are not focused on attacking the Immutable zkEVM, a single system within the larger Ethereum ecosystem. Additionally, these attacks on withdrawal time or flow rate are only slightly moving the timing and thresholds, in a way that is insignificant relative to the standard settings. That is, the default withdrawal delay is one day. Causing the delay to be even one second longer appears insignificant. Assuming the flow rate bucket has its capacity set such that it is averaging the flow rate over a period of an hour or more, changing the block timestamp by even a second will have little effect.

### mapToken(address)

The `mapToken` function sets the mapping between a token contract address on Ethereum and the corresponding token contract on the Immutable zkEVM. The mapping algorithm is deterministic. The function call initiates a crosschain transaction, which results in the token contract on the Immutable zkEVM being deployed.

The [General Public Attacker](#general-public) could call this function multiple times for any token. They could then complete the crosschain transaction on the Immutable zkEVM, calling `commit` on the `StateReceiver` contract. The first time the function was called, the `ChildERC20Predicate` contract would deploy the contract. On the second attempt the function call would revert when the `ChildERC20Predicate` contract attempted to re-deploy the token contract. As such, the only possible attack could be that the [General Public Attacker](#general-public) deploys a multitude of ERC 20 contracts, filling up the Immutable zkEVM state. This is not deemed a significant attack.

The [MEV Bot Attacker](#mev-bot) would gain no benefit from front running calls to this function. As such, it would not call this function.

## Attacks on RootERC20PredicateFlowRate Functions with Access Control

The table below outlines functions in `RootERC20PredicateFlowRate` that have access control. The mitigation for all is to assume that all roles will be operated by multi-signature addresses such that an attacker would need to compromise multiple signers simultaneously. As such, even if some keys are compromised due to the [Spear Phishing Attacker](#spear-phisher) or the [Insider Attacker](#insider), the administrative actions will not be able to be executed as a threshold number of keys will not be available.

It should be noted that the intention is to have the threshold of number of signatures for the PAUSE role lower than for the other roles to make it easier for administrators to pause the bridge in a time of attack. However, the threshold will still be high enough that it will be difficult for an attacker to successfully mount such an attack. Even if they did successfully mount this attack, they would cause reputational damage, but would be unable to steal funds.

| Name                                                     | Function Selector | Type        | Access Control       |
| -------------------------------------------------------- | ----------------- | ----------- | -------------------- |
| activateWithdrawalQueue()                                | af8bbb5e          | transaction | RATE role            |
| deactivateWithdrawalQueue()                              | 1657a6e5          | transaction | RATE role            |
| grantRole(bytes32,address)                               | 2f2ff15d          | transaction | Role Admin for role. |
| pause()                                                  | 8456cb59          | transaction | PAUSE role           |
| renounceRole(bytes32,address)                            | 36568abe          | transaction | msg.sender           |
| revokeRole(bytes32,address)                              | d547741f          | transaction | Role Admin for role. |
| setRateControlThreshold(address,uint256,uint256,uint256) | 8f3a4e4f          | transaction | RATE role            |
| setWithdrawalDelay(uint256)                              | d2c13da5          | transaction | RATE role            |
| unpause()                                                | 3f4ba83a          | transaction | UNPAUSE role         |

## Attacks on RootERC20PredicateFlowRate onL2StateReceive Function

Attacks related to compromising the attack surfaces [Root Chain Bridge Contracts](#root-chain-bridge-contracts), [Child Chain Bridge Contracts](#child-chain-bridge-contracts), [Immutable zkEVM Validators](#immutable-zkevm-validators), and [Custom Supernets Manager, Owner role](#custom-supernets-manager-owner-role) all result in creating a malicious `exit`. `Exits` supplied to the `ExitHelper` call the `RootERC20PredicateFlowRate`'s `onL2StateReceive` function. These are used to execute withdrawals. These attacks are mitigated by the high value withdrawal threshold and flow rate detection mechanisms that will detect large outflows, and add the withdrawals to the withdrawal queue. The administrators of the system would then have time to make the determination that the system was under attack and pause the bridge. Once the bridge has been paused, the attack could be mitigated, possibly by upgrading the RootERC20PredicateFlowRate to remove the malicious withdrawals.

The [Server Powner Attacker](#server-powner) or other attacker that could create a malicious `exit`. They could then work with a [Spear Phishing Attacker](#spear-phisher) or the [Insider Attacker](#insider), to attempt to unpause the bridge and reduce the withdrawal delay so that they could finalise their malicious withdrawal. As per the [Attacks on RootERC20PredicateFlowRate Functions with Access Control](#attacks-on-rooterc20predicateflowrate-functions-with-access-control) section, the mitigation for this attack is to assume that all roles will be operated by multi-signature addresses such that an attacker would need to compromise multiple signers simultaneously.

## Upgrade Attacks

As described in the [RootERC20PredicateFlowRate, ExitHelper, CheckpointManager, CustomSupernetsManager Contract Upgrade](#rooterc20predicateflowrate-exithelper-checkpointmanager-customsupernetsmanager-contract-upgrade) section, a Proxy Administrator can upgrade the RootERC20PredicateFlowRate contract and other important contracts, changing the functionality to allow them to steal funds. As per the [Attacks on RootERC20PredicateFlowRate Functions with Access Control](#attacks-on-rooterc20predicateflowrate-functions-with-access-control) section, the mitigation for this attack is to assume that the Proxy Administrator will be operated by multi-signature addresses such that an attacker would need to compromise multiple signers simultaneously.

# Conclusion

This thread model has presented the architecture of the system, determined attack surfaces, and identified possible attackers and their capabilities. It has walked through each attack surface and based on the attackers, determined how the attacks are mitigated.

The most likely attack will be compromising administrative keys that are part of multi-signature systems that control administrative roles via a combination of insider attacks or spear phishing attacks. The threshold number of signatures will be high for all but the PAUSE role, and hence attackers are extremely unlikely to compromise enough keys to mount an attack. The threshold number of signers for the PAUSE role is lower, so could possibly enough keys could be compromised to mount an attack. Pausing the bridge though disruptive, will not allow attackers to steal funds.
