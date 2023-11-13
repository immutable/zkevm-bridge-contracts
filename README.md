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
INITIAL_IMX_CUMULATIVE_DEPOSIT_LIMIT="0"
```
where `{ROOT,CHILD}_{GATEWAY,GAS_SERVICE}_ADDRESS` refers to the gateway and gas service addresses used by Axelar.

`INITIAL_IMX_CUMULATIVE_DEPOSIT_LIMIT` refers to the cumulative amount of IMX that can be deposited. A value of `0` indicated unlimited.

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
ROOT_CHAIN_NAME="Ethereum"
CHILD_CHAIN_NAME="Polygon"
ROOT_IMX_ADDRESS="0x1111111111111111111111111111111111111111"
ROOT_GATEWAY_ADDRESS="0x013459EC3E8Aeced878C5C4bFfe126A366cd19E9"
CHILD_GATEWAY_ADDRESS="0xc7B788E88BAaB770A6d4936cdcCcd5250E1bbAd8"
ROOT_GAS_SERVICE_ADDRESS="0x28f8B50E1Be6152da35e923602a2641491E71Ed8"
CHILD_GAS_SERVICE_ADDRESS="0xC573c722e21eD7fadD38A8f189818433e01Ae466"
INITIAL_IMX_CUMULATIVE_DEPOSIT_LIMIT="0"
ENVIRONMENT="local"
```
(Note that `{ROOT,CHILD}_PRIVATE_KEY` can be any of the standard localhost private keys that get funded)
(Note that `ROOT_IMX_ADDRESS` is not currently used in this local environment. Therefore, any non-zero address is fine.)
(Note that `ENVIRONMENT` if the environment is not set to "local" then ROOT_WETH_ADDRESS will need to be manually set in the .env file since it is expected WETH to be already deployed on testnet or mainnet)

3. In a separate terminal window, deploy the smart contracts
```shell
./deploy.sh
```

4. Run the script that will send a `MAP_TOKEN` message
```shell
yarn run execute evm/call-contract local Ethereum Polygon map
```

5. (OPTIONAL) Check the token mapping has been populated using `cast`
```shell
source .env
cast call --rpc-url $CHILD_RPC_URL "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707" "rootTokenToChildToken(address)(address)" "0x38Aa1Cb12E5263eC0c6e9febC25B01116D346CD4"
```

6. Run the script that will send a `DEPOSIT` message
```shell
yarn run execute evm/call-contract local Ethereum Polygon deposit
```

7. (OPTIONAL) Check the tokens have been deposited using `cast`
```shell
source .env
cast call --rpc-url $CHILD_RPC_URL "0xa03647137120b00cae83751A82280A67df027F04" "balanceOf(address)(uint256)" "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
```
(Note: This assumes your address is the one associated with the above-specified private key)
