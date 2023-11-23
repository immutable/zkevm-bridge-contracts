# Immutable zkEVM Bridge Contracts

(Work in progress doc)

<p align="center"><img src="https://cdn.dribbble.com/users/1299339/screenshots/7133657/media/837237d447d36581ebd59ec36d30daea.gif" width="280"/></p>

zkevm-bridge-contracts is a repository of smart contracts for bridging in the Immutable zkEVM, a general-purpose permissionless L2 zero-knowledge rollup.

These contracts are used in the ERC20 and native ETH bridging functionality of the Immutable zkEVM.

The main development toolkit for this repository is [Foundry](https://book.getfoundry.sh)
Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Usage

### Install Dependencies
```shell
$ yarn install
$ forge install
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Local Deployment

##### Instructions
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

4. (Optional) Run end to end tests
```
yarn local:test
```

### Remote Deployment

When deploying these contracts on remote networks (i.e. testnets or mainnets). Refer to [deployment](./scripts/deploy/README.md) or [bootstrap](./scripts/bootstrap/README.md).