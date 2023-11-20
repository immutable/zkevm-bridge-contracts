# Bridge bootstrapping

## Prerequisite
1. Coordinate with Axelar to obtain their admin address for initial funding as well as the desired amount in $IMX. (500 IMX in previous discussion).
2. Obtain the deployer account on both child chain and root chain.
3. Obtain the amount to fund deployer on child chain in $IMX. (500 IMX by default).
4. Coordinate with security to obtain the addresses for different roles.
5. Fund deployer with `ETH` and `IMX` on root chain. (As a rule of thumb, _0.1 ETH and 1100 IMX_ (TBD)).
6. Fund a test account with `ETH` and `IMX` on root chain. (As a rule of thumb, _0.1 ETH and 10 IMX_ (TBD)).


## Bootstrapping
0. Install dependency and compile contracts (Run in root directory)
```
yarn install
yarn build
```
1. Create environment file
```
cd scripts/bootstrap
cp .env.example .env
```
2. Set the following environment variables
```
CHILD_CHAIN_NAME=
CHILD_RPC_URL=
CHILD_CHAIN_ID=
ROOT_CHAIN_NAME=
ROOT_RPC_URL=
ROOT_CHAIN_ID=
## The admin EOA address on the child chain.
CHILD_ADMIN_ADDR=
## The private key for the admin EOA or "ledger" if using hardware wallet.
CHILD_ADMIN_EOA_SECRET=
## The deployer address on child chain.
CHILD_DEPLOYER_ADDR=
## The private key for the deployer on child chain or "ledger" if using hardware wallet.
CHILD_DEPLOYER_SECRET=
## The amount of fund deployer required on L2, unit is in IMX or 10^18 Wei.
CHILD_DEPLOYER_FUND=
## The deployer address on root chain.
ROOT_DEPLOYER_ADDR=
## The private key for the deployer on root chain or "ledger" if using hardware wallet.
ROOT_DEPLOYER_SECRET=
## The IMX token address on root chain.
ROOT_IMX_ADDR=
## The Wrapped ETH token address on the root chain.
ROOT_WETH_ADDR=
## The Axelar address for receive initial funding on the child chain.
AXELAR_EOA=
## The amount of fund Axelar requested, unit is in IMX or 10^18 Wei.
AXELAR_FUND=
## The maximum amount of IMX that can be deposited to L2, unit is in IMX or 10^18 Wei.
IMX_DEPOSIT_LIMIT=
## The address to perform child bridge upgrade.
CHILD_PROXY_ADMIN=
## The address to be assigned with DEFAULT_ADMIN_ROLE in child bridge.
CHILD_BRIDGE_DEFAULT_ADMIN=
## The address to be assigned with PAUSER_ROLE in child bridge.
CHILD_BRIDGE_PAUSER=
## The address to be assigned with UNPAUSER_ROLE in child bridge.
CHILD_BRIDGE_UNPAUSER=
## The address to be assigned with ADAPTOR_MANAGER_ROLE in child bridge.
CHILD_BRIDGE_ADAPTOR_MANAGER=
## The address to perform root adaptor upgrade.
ROOT_PROXY_ADMIN=
## The address to be assigned with DEFAULT_ADMIN_ROLE in root bridge.
ROOT_BRIDGE_DEFAULT_ADMIN=
## The address to be assigned with PAUSER_ROLE in root bridge.
ROOT_BRIDGE_PAUSER=
## The address to be assigned with UNPAUSER_ROLE in root bridge.
ROOT_BRIDGE_UNPAUSER=
## The address to be assigned with VARIABLE_MANAGER_ROLE in root bridge.
ROOT_BRIDGE_VARIABLE_MANAGER=
## The address to be assigned with ADAPTOR_MANAGER_ROLE in root bridge.
ROOT_BRIDGE_ADAPTOR_MANAGER=
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

If multisig is deployed:
```
node 2_deployment_validation.js
```
If multisig isn't deployed:
```
SKIP_MULTISIG_CHECK=true node 2_deployment_validation.js
```
7. Deploy bridge contracts on child and root chain.
```
node 3_child_deployment.js
node 4_root_deployment.js
```
8. Initialise bridge contracts on child chain.
```
node 5_child_initialisation.js
```
9. IMX Burning
```
node 6_imx_burning.js
```
10. IMX Rebalancing
```
node 7_imx_rebalancing.js
```
11. Initialise bridge contracts on root chain.
```
node 8_root_initialisation.js
```
12. Set the following environment variable
```
TEST_ACCOUNT_SECRET=
```
13. Test bridge functions
```
npx mocha ../e2e/
```