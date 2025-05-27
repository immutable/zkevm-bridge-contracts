# Immutable Token Bridge

The Immutable token bridge facilitates the transfer of assets between two chains, namely Ethereum (the Root chain) and the Immutable chain (the Child chain). At present, the bridge only supports the transfer of standard ERC20 tokens originating from Ethereum, as well as native assets (ETH and IMX). Other types of assets (such as ERC721) and assets originating from the Child chain are not currently supported.

## Contents
<!-- TOC -->
* [Features](#features)
* [Build and Test](#build-and-test)
* [Contract Deployment](#contract-deployment)
* [Deployed Contract Addresses](#deployed-contract-addresses)
* [Flow Rate Parameters](#flow-rate-parameters)
* [Manual Bridging Guide](#manual-bridging-guide)
* [Audits](#audits)
<!-- TOC -->

## Features
### Core Features
The bridge provides two key functions, **deposits** and **withdrawals**.

#### Deposit Assets (Root Chain → Child Chain)
When a user wishes to transfer assets from Ethereum to Immutable, they initiate a deposit. This deposit moves an asset from the Root chain to the Child chain. It does so by first transferring the user's asset to the bridge (Root chain), then minting and transferring corresponding representation tokens of that asset to the user, on the Child chain. The following types of asset deposits flows are supported:
1. Native ETH on Ethereum  → Wrapped ETH on Immutable zkEVM (ERC20 token)
2. Wrapped ETH on Ethereum → Wrapped ETH on Immutable zkEVM (ERC20 token)
3. ERC20 IMX on Ethereum   → Native IMX on Immutable zkEVM. IMX is represented on Immutable zkEVM as the native gas token, see [here](https://etherscan.io/token/0xf57e7e7c23978c3caec3c3548e3d615c346e79ff)
4. Standard ERC20 tokens   → Wrapped equivalents on Immutable zkEVM (ERC20 token)

#### Withdraw Assets (Child Chain → Root Chain)
When a user wants to transfer bridged assets from Immutable back to Ethereum, they start a withdrawal. This process moves an asset from the Child chain to the Root chain. It includes burning the user's bridged tokens on the child chain and unlocking the corresponding asset on the Root chain. Only assets that were bridged using the deposit flow described above can be withdrawn. Therefore, the available withdrawal flows are as follows:
1. Native IMX on Immutable zkEVM →  for ERC20 IMX on Ethereum.
2. Wrapped ETH on Immutable zkEVM →  Native ETH on Ethereum
3. Wrapped IMX on Immutable zkEVM →  for ERC20 IMX on Ethereum
4. Wrapped ERC20 on Immutable zkEVM →  Original ERC20 on Ethereum

**Not supported:**
The following capabilities are not currently supported by the Immutable bridge:
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
- **Root Chain**
    - `RootERC20Bridge`: `mapToken()`, `deposit()`, `depositTo()`, `depositETH()`, `depositToETH()`, `onMessageReceive()`
    - `RootERC20BridgeFlowRate` contract: `finaliseQueuedWithdrawal()`, `finaliseQueuedWithdrawalsAggregated()`, as well as all functions from `RootERC20Bridge`.
- **Child Chain:**
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

## Build and Test
### Install Dependencies
```shell
$ yarn install
$ forge install
```
### Build

```shell
$ forge build
```

### Testing
To run unit, integration and fuzz tests execute the following command:
```shell
$ forge test --no-match-path "test/{fork,invariant}/**"
```

**Fork Tests**

The fork tests run a suite of tests against one or more deployments of the bridge.
To run these tests copy [`.env.example`](.env.example) file to a `.env` file and set the `MAINNET_RPC_URL` and `TESTNET_RPC_URL` environment variables. Set or update any other environment variables as required. 
Then run the following command to run the fork tests. 

```shell
$ forge test --match-path "test/fork/**"
```

## Contract Deployment
### Local Deployment
To set up the contracts on two separate local networks, we need to start running the local networks, then deploy and initialize the contracts.

1. Set up the two local networks and axelar network
```
yarn local:start
```

2. Run the deployment of contracts
```
yarn local:setup
```

3. Get contract addresses from `./scripts/localdev/.child.bridge.contracts.json` and `./scripts/localdev/.root.bridge.contracts.json`.

4. (Optional) Run end-to-end tests
```
yarn local:test
```

### Remote Deployment

When deploying these contracts on remote networks (i.e. testnet or mainnet), refer to the documentation in [deployment](./scripts/deploy/README.md) or [bootstrap](./scripts/bootstrap/README.md).

## Deployed Contract Addresses
Addresses for the core bridge contracts are listed below. For a full list of deployed contracts see [deployments/](./deployments) directory.
ABIs for contracts can be obtained from the blockchain explorer links for each contract provided below.

### Root Chain
#### Core Contracts

|                        | Mainnet (Ethereum)                                                                                                      | Testnet (Sepolia)                                                                                                                    |
|------------------------|-------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| Bridge Proxy           | [`0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6`](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6) | [`0x0D3C59c779Fd552C27b23F723E80246c840100F5`](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5)      |
| Bridge Implementation  | [`0x177EaFe0f1F3359375B1728dae0530a75C83E154`](https://etherscan.io/address/0x177EaFe0f1F3359375B1728dae0530a75C83E154) | [`0xac88a57943b5BBa1ecd931F8494cAd0B7F717590`](https://sepolia.etherscan.io/address/0xac88a57943b5bba1ecd931f8494cad0b7f717590#code) |
| Adaptor Proxy          | [`0x4f49B53928A71E553bB1B0F66a5BcB54Fd4E8932`](https://etherscan.io/address/0x4f49b53928a71e553bb1b0f66a5bcb54fd4e8932) | [`0x6328Ac88ba8D466a0F551FC7C42C61d1aC7f92ab`](https://sepolia.etherscan.io/address/0x6328Ac88ba8D466a0F551FC7C42C61d1aC7f92ab)      |
| Adaptor Implementation | [`0xE2E91C1Ae2873720C3b975a8034e887A35323345`](https://etherscan.io/address/0xE2E91C1Ae2873720C3b975a8034e887A35323345) | [`0xe9ec55e1fC90AB69B2Fb4C029d24a4622B94042e`](https://sepolia.etherscan.io/address/0x6328Ac88ba8D466a0F551FC7C42C61d1aC7f92ab)      |

#### Token Addresses
|             | Mainnet (Ethereum)                                                                                                    | Testnet (Sepolia)                                                                                                               |
|-------------|-----------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Wrapped ETH | [`0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2`](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) | [`0x7b79995e5f793a07bc00c21412e50ecae098e7f9`](https://sepolia.etherscan.io/address/0x7b79995e5f793a07bc00c21412e50ecae098e7f9) |
| IMX         | [`0xf57e7e7c23978c3caec3c3548e3d615c346e79ff`](https://etherscan.io/token/0xf57e7e7c23978c3caec3c3548e3d615c346e79ff) | [`0xe2629e08f4125d14e446660028bd98ee60ee69f2`](https://sepolia.etherscan.io/address/0xe2629e08f4125d14e446660028bd98ee60ee69f2) |
| USDC        | [`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`](https://etherscan.io/token/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) | [`0x40b87d235A5B010a20A241F15797C9debf1ecd01`](https://sepolia.etherscan.io/address/0x40b87d235A5B010a20A241F15797C9debf1ecd01) |

### Child Chain
#### Core Contracts
|                        | Mainnet                                                                                                                           | Testnet                                                                                                                                   |
|------------------------|-----------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| Bridge Proxy           | [`0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6`](https://explorer.immutable.com/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6) | [`0x0D3C59c779Fd552C27b23F723E80246c840100F5`](https://explorer.testnet.immutable.com/address/0x0D3C59c779Fd552C27b23F723E80246c840100F5) |
| Bridge Implementation  | [`0xb4c3597e6b090A2f6117780cEd103FB16B071A84`](https://explorer.immutable.com/address/0xb4c3597e6b090A2f6117780cEd103FB16B071A84) | [`0xA554Cf58b9524d43F1dee2fE1b0C928f18A93FE9`](https://explorer.testnet.immutable.com/address/0xA554Cf58b9524d43F1dee2fE1b0C928f18A93FE9) |
| Adaptor Proxy          | [`0x4f49B53928A71E553bB1B0F66a5BcB54Fd4E8932`](https://explorer.immutable.com/address/0x4f49B53928A71E553bB1B0F66a5BcB54Fd4E8932) | [`0x6328Ac88ba8D466a0F551FC7C42C61d1aC7f92ab`](https://explorer.testnet.immutable.com/address/0x6328Ac88ba8D466a0F551FC7C42C61d1aC7f92ab) |
| Adaptor Implementation | [`0x1d49c44dc4BbDE68D8D51a9C5732f3a24e48EFA6`](https://explorer.immutable.com/address/0x1d49c44dc4BbDE68D8D51a9C5732f3a24e48EFA6) | [`0xac88a57943b5BBa1ecd931F8494cAd0B7F717590`](https://explorer.testnet.immutable.com/address/0xac88a57943b5BBa1ecd931F8494cAd0B7F717590) |

#### Token Addresses
|                          | Mainnet                                                                                                                           | Testnet                                                                                                                                   |
|--------------------------|-----------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| Wrapped ETH              | [`0x52a6c53869ce09a731cd772f245b97a4401d3348`](https://explorer.immutable.com/address/0x52a6c53869ce09a731cd772f245b97a4401d3348) | [`0xe9E96d1aad82562b7588F03f49aD34186f996478`](https://explorer.testnet.immutable.com/address/0xe9E96d1aad82562b7588F03f49aD34186f996478) |
| Wrapped IMX              | [`0x3a0c2ba54d6cbd3121f01b96dfd20e99d1696c9d`](https://explorer.immutable.com/address/0x3a0c2ba54d6cbd3121f01b96dfd20e99d1696c9d) | [`0x1CcCa691501174B4A623CeDA58cC8f1a76dc3439`](https://explorer.testnet.immutable.com/address/0x1CcCa691501174B4A623CeDA58cC8f1a76dc3439) | TBA    |
| USDC                     | [`0x6de8aCC0D406837030CE4dd28e7c08C5a96a30d2`](https://explorer.immutable.com/address/0x6de8aCC0D406837030CE4dd28e7c08C5a96a30d2) | [`0x3B2d8A1931736Fc321C24864BceEe981B11c3c57`](https://explorer.testnet.immutable.com/address/0x3B2d8A1931736Fc321C24864BceEe981B11c3c57) |
| USDT                     | [`0x68bcc7F1190AF20e7b572BCfb431c3Ac10A936Ab`](https://explorer.immutable.com/address/0x68bcc7F1190AF20e7b572BCfb431c3Ac10A936Ab) | TBA                                                                                                                                       |
| Wrapped BTC              | [`0x235F9A2Dc29E51cE7D103bcC5Dfb4F5c9c3371De`](https://explorer.immutable.com/address/0x235F9A2Dc29E51cE7D103bcC5Dfb4F5c9c3371De) | TBA                                                                                                                                       |
| Gods Unchained (GODS)    | [`0xE0e0981D19eF2E0a57Cc48CA60D9454eD2D53fEB`](https://explorer.immutable.com/address/0xE0e0981D19eF2E0a57Cc48CA60D9454eD2D53fEB) | TBA                                                                                                                                       |
| Guild of Guardians (GOG) | [`0xb00ed913aAFf8280C17BfF33CcE82fE6D79e85e8`](https://explorer.immutable.com/address/0xb00ed913aAFf8280C17BfF33CcE82fE6D79e85e8) | TBA                                                                                                                                       |

## Flow Rate Parameters
The [flow rate parameters](./docs/high-level-architecture.md#flow-rate-detection) configured for assets on the Immutable zkEVM mainnet bridge are listed below.
- The *Flow Rate Capacity* is the maximum cumulative amount of a token that can be withdrawn within a 4-hour window. If the total amount of tokens withdrawn within this time window exceeds this threshold, the global withdrawal queue is activated. Consequently, all subsequent withdrawals for all tokens will be queued for 24 hours until the queue is manually deactivated.
- The *Large Withdrawal Threshold* is the size threshold for any single withdrawal of a token. If a withdrawal exceeds this amount, that particular withdrawal is queued for 24 hours on the bridge before it can be redeemed. This queuing does not affect other withdrawals by the same user or other users.

| Token Name                                                                            | Flow-Rate Capacity (4-Hour Window) | Large Withdrawal Threshold |
|---------------------------------------------------------------------------------------|------------------------------------|----------------------------|
| Ethereum                                                                              | 148                                | 29.60                      |
| [IMX](https://etherscan.io/token/0xF57e7e7C23978C3cAEC3C3548E3D615c346e79fF)          | 539,052                            | 107,230                    |
| [USDC](https://etherscan.io/token/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)         | 372,000                            | 74,000                     |
| [USDT](https://etherscan.io/token/0xdAC17F958D2ee523a2206206994597C13D831ec7)         | 372,000                            | 74,000                     |
| [wBTC](https://etherscan.io/token/0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599)         | 3.37                               | 0.67                       |
| [GODS](https://etherscan.io/token/0xccC8cb5229B0ac8069C51fd58367Fd1e622aFD97)         | 2,310,559                          | 459,627                    |
| [GOG](https://etherscan.io/token/0x9AB7bb7FdC60f4357ECFef43986818A2A3569c62)          | 9,386,828                          | 1,867,272                  |
| [Space Nation](https://etherscan.io/token/0x6e7f11641c1ec71591828e531334192d622703f7) | 15,000,000                         | 220,000                    |

These parameters can also be queried from the L1 bridge contract using a block explorer ([mainnet](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6#readProxyContract), [testnet](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5#readProxyContract)). The `flowRateBuckets()` function provides the bucket capacity and refill rate, while the `largeTransferThreshold()` function provides the withdrawal size threshold configured for a token.
The L1 address of the token to query parameters for needs to be provided as input to both functions.
If flow rate parameters have not been configured for a token, these functions will return zero values.

## Manual Bridging Guide
The process to manually bridge funds from Ethereum to Immutable zkEVM by directly interacting with the bridge contracts is documented [here](docs/manual-bridging.md). However, the recommended method for bridging to and from the Immutable zkEVM is to use the [Immutable Toolkit](https://toolkit.immutable.com/bridge/) user interface.

## Audits
The Immutable token bridge has been audited by [Trail of Bits](https://www.trailofbits.com/). The audit report can be found [here](./audits/Trail-of-Bits-2023-12-14.pdf).
Additionally, the bridge has undergone comprehensive fuzzing and invariant testing conducted by [Perimeter](https://www.perimetersec.io/). The report can be found [here](./audits/Perimeter-Fuzzing-2024-09-10.pdf).
