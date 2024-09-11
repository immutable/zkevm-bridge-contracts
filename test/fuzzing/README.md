## Overview

Immutable engaged [Perimeter](https://www.perimetersec.io) for an in-depth invariant suite for the Immutable zkEVM Bridge. The focus of this engagement was to replicate all of the invariants that made sense to be replicated from the existing foundry suite to an Echidna/Medusa invariant suite. Additionally, many more invariants were added with a emphasis on the flow rate mechanism. This engagement was conducted by [@0xScourgedev](https://twitter.com/0xScourgedev), and concluded on September 1st, 2024. The fuzzing suite was successfully delivered upon the engagement's conclusion.

## Contents

This fuzzing suite was created for the scope below. The primary objective of this engagement was to replicate the invariants from the existing Foundry suite into an Echidna/Medusa invariant suite for long-term use. Additionally, the engagement aimed to incorporate numerous new invariants, many related to the root bridge's flow rate, to conduct thorough stress testing of the contracts and ensure high coverage rates for the invariant suite.

The invariant suite developed for this engagement tests each side of the bridge individually with a superset of expected values to thoroughly test for edge cases and to reach additional coverage. Fuzzing across the root bridge and the child bridge is out of scope of this engagement and can be addressed in a follow-up engagement.

All properties tested can be found in `Properties.md`.

## Setup

1. Installing Echidna and Medusa

    a. Install Echidna, follow the steps here: [Installation Guide](https://github.com/crytic/echidna#installation) using the latest master branch

    b. Install Medusa, follow the steps here: [Installation Guide](https://github.com/crytic/medusa/blob/master/docs/src/getting_started/installation.md)

2. Install dependencies with `yarn install`

3. Running the Fuzzing Invariants

    a. To fuzz all invariants using Echidna, run the command: 
    ```
    echidna . --contract Fuzz --config echidna-config.yaml
    ```

    b. To fuzz all invariants using Medusa, run the command: 
    ```
    medusa fuzz
    ```

## Scope

Repo: [https://github.com/immutable/zkevm-bridge-contracts](https://github.com/immutable/zkevm-bridge-contracts)

Branch: `main`

Commit: `0a56c7cf3675ff9c71010d2d768da4bf1dd7f204`

```
src/child/ChildERC20Bridge.sol
src/child/ChildERC20.sol
src/child/WIMX.sol
src/root/flowrate/RootERC20BridgeFlowRate.sol
src/root/flowrate/FlowRateWithdrawalQueue.sol
src/root/flowrate/FlowRateDetection.sol
src/root/RootERC20Bridge.sol
```
