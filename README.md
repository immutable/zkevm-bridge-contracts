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

### Deploy

TODO

