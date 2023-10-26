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

##### Pre-requisites
`jq` will need to be installed before running the scripts. This can be done with `brew install jq` on a mac, or see [here](https://codeahoy.com/learn/introtobash/ch15/#installing-jq) for an online guide.

You will also need to run `forge install` to install dependencies.

##### Instructions
To set up the contracts on two separate local networks, we need to start running the local networks, then run `./deploy.sh`, which will run all four Forge scripts to deploy and initialize the contracts.

1. Set up the two local networks. e.g:
`anvil -p 8545 --chain-id 31337`
and in another terminal:
`anvil -p 8546 --chain-id 31338`
Note that we set the ports and chain IDs to be unique.

2. Update environment variables with RPC URLs, chain IDs, and private keys. Using the networks set up in step 1, our .env file will include the following lines:
```
ROOT_RPC_URL="http://127.0.0.1:8545"
CHILD_RPC_URL="http://127.0.0.1:8546"
ROOT_CHAIN_ID="31337"
CHILD_CHAIN_ID="31338"
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
ROOT_IMX_ADDRESS=
CHILD_ETH_ADDRESS=
```
where `{ROOT,CHILD}_{GATEWAY,GAS_SERVICE}_ADDRESS` refers to the gateway and gas service addresses used by Axelar.

We can just use dummy gateway/gas service addresses if we only want to test the deployment, and not bridging functionality. If wanting to use dummy addresses, any valid Ethereum address can be used here.

4. Run the deploy script.
`deploy.sh`

5. Get contract addresses from `addresses.json`.

### Remote Deployment

When deploying these contracts on remote networks (i.e. testnets or mainnets), the instructions are the same as above, but:
- step 1 (deploying the networks) should be skipped.
- in step 2:
    - The RPC URLs and Chain IDs should be set for the targetted networks.
    - The private keys should be for addresses with which the contracts are to be deployed.


### Axelar Local Bridge

##### One-time setup

1. install the dependencies
```shell
yarn install
```

2. compile the smart contracts
```shell
forge build
```

##### Start & setup the local blockchains

1. Start the local blockchains and local Axelar network
```shell
yarn start
```

2. Set the following env vars in your `.env` file
```shell
ROOT_RPC_URL="http://localhost:8500/0"
CHILD_RPC_URL="http://localhost:8500/1"
ROOT_CHAIN_ID="2500"
CHILD_CHAIN_ID="2501"
ROOT_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
CHILD_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
```
(Note that `{ROOT,CHILD}_PRIVATE_KEY` can be any of the standard localhost private keys that get funded)

3. In a separate terminal window, deploy the smart contracts
```shell
./deploy.sh
```

4. Copy the config file with the correct addresses
```shell
cp axelar-local-dev/chain-config/local.template.json axelar-local-dev/chain-config/local.json
```

5. Run the script to execute the `axelar-local-dev/examples/evm/call-contract/index.js` file
```shell
yarn run execute evm/call-contract local Ethereum Polygon
```
