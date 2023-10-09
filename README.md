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

### Local Deployment

To set up the contracts on two separate local networks, you need to start running the local networks, then run `./deploy.sh`, which will run all four Forge scripts to deploy and initialize the contracts.

1. Set up the two local networks. e.g:
`anvil -p 8545 --chain-id 31337`
and in another terminal:
`anvil -p 8546 --chain-id 31338`
Note that we set the ports and chain IDs to be unique.

2. Update environment variables with RPC URLs, chain IDs, and private keys. Using the networks set up in step 1, our .env file will include the following lines:
```
ROOT_RPC_URL="http://127.0.0.1:8545"
CHILD_RPC_URL="http://127.0.0.1:8546"
ROOT_CHAIN_ID="31338"
CHILD_CHAIN_ID="31337"
ROOT_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
CHILD_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```
The private keys used are the default `anvil` keys.

3. Fill other environment variables. The variables needed are:
```
ROOT_GATEWAY_ADDRESS=
CHILD_GATEWAY_ADDRESS=
ROOT_GAS_SERVICE_ADDRESS=
CHILD_GAS_SERVICE_ADDRESS=
ROOT_CHAIN_NAME="ROOT"
CHILD_CHAIN_NAME="CHILD"
```
where `{ROOT,CHILD}_{GATEWAY,GAS_SERVICE}_ADDRESS` refers to the gateway and gas service addresses used by Axelar.

You can just deploy with dummy gateway/gas service addresses if you only want to test the deployment, and not bridging functionality.

4. Run the deploy script.
`deploy.sh`

5. Get contract addresses from `output.json`.
