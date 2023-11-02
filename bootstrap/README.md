# Bridge bootstrapping

## Prerequisite
1. Coordinate with Axelar to obtain their admin address for initial funding as well as the desired amount in $IMX. (50 IMX in previous discussion).
2. Fund admin EOA account with `ETH` and `IMX` on root chain. (As a rule of thumb, _0.1 ETH and 100 IMX_ (TBD))


## Bootstrapping
0. Install dependency and compile contracts (Run in root directory)
```
yarn install
forge build
```
1. Create environment file
```
cd bootstrap
cp ./env.example ./env
```
2. Set the following environment variables
```
CHILD_CHAIN_NAME=
CHILD_RPC_URL=
CHILD_CHAIN_ID=
ROOT_CHAIN_NAME=
ROOT_RPC_URL=
ROOT_CHAIN_ID=
IMX_ROOT_ADDR=
WETH_ROOT_ADDR=
ADMIN_EOA_SECRET= (Note: Use private key string or "ledger" if using hardware wallet)
AXELAR_EOA=
AXELAR_FUND=
```
3. Fund deployer
```
node 1_deployer_funding.js
```
4. Wait for Axelar to deploy & setup their system and Security team to deploy & setup multisig wallet.
5. Set the following environment variables
```
CHILD_GATEWAY_ADDRESS=
CHILD_GAS_SERVICE_ADDRESS=
MULTISIG_CONTRACT_ADDRESS=
ROOT_GATEWAY_ADDRESS=
ROOT_GAS_SERVICE_ADDRESS=
```
6. Basic contract validation
```
node 2_deployment_validation.js (Note, for testnet regenesis, line 41 needs to be disabled.)
```
7. Deploy bridge contracts on child and root chain. (see [here](../README.md#remote-deployment) for more details)
```
node 3_child_deployment.js
node 4_child_deployment.js
```
8. Set the following environment variables using the output `3.out.tmp` & `4.out.tmp` from the previous step.
```
CHILD_BRIDGE_ADDRESS=
CHILD_ADAPTER_ADDRESS=
WRAPPED_IMX_ADDRESS=
CHILD_TOKEN_TEMPLATE=
ROOT_BRIDGE_ADDRESS=
ROOT_ADAPTER_ADDRESS=
ROOT_TOKEN_TEMPLATE=
```
9. Initialise bridge contracts on child chain. (see [here](../README.md#remote-deployment) for more details)
```
node 5_child_initialisation.js
```
10. IMX Burning
```
node 6_imx_burning.js
```
11. IMX Rebalancing
```
node 7_imx_rebalancing.js
```
12. Initialise bridge contracts on root chain. (see [here](../README.md#remote-deployment) for more details)
```
node 8_root_initialisation.js
```
