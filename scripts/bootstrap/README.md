# Bridge bootstrapping

## Prerequisite
1. Coordinate with Axelar to obtain their admin address for initial funding as well as the desired amount in $IMX. (500 IMX in previous discussion).
2. Obtain the deployer account on both child chain and root chain.
3. Obtain the amount to fund deployer on child chain in $IMX. (500 IMX by default).
4. Coordinate with security to obtain the addresses for different roles.
5. Fund deployer with `ETH` and `IMX` on root chain. (As a rule of thumb, _0.1 ETH and 1100 IMX_ (TBD)).
6. Fund a test account with `ETH` and `IMX` on root chain. (As a rule of thumb, _0.1 ETH and 50 IMX_ (TBD)).
7. Fund a rate admin account with `ETH` on root chain. (As a rule of thumb, _0.1 ETH_ (TBD)).


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
# Set prior to 1_deployer_funding.js
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
## The ledger index for the admin EOA, required if using ledger.
CHILD_ADMIN_EOA_LEDGER_INDEX=
## The deployer address on child chain.
CHILD_DEPLOYER_ADDR=
## The private key for the deployer on child chain or "ledger" if using hardware wallet.
CHILD_DEPLOYER_SECRET=
## The ledger index for the deployer on child chain, required if using ledger.
CHILD_DEPLOYER_LEDGER_INDEX=
## The amount of fund deployer required on L2, unit is in IMX or 10^18 Wei.
CHILD_DEPLOYER_FUND=
## The deployer address on root chain.
ROOT_DEPLOYER_ADDR=
## The private key for the deployer on root chain or "ledger" if using hardware wallet.
ROOT_DEPLOYER_SECRET=
## The ledger index for the deployer on root chain, required if using ledger.
ROOT_DEPLOYER_LEDGER_INDEX=
## The private key for rate admin or "ledger" if using hardware wallet.
ROOT_BRIDGE_RATE_ADMIN_SECRET=
## The ledger index for the rate admin, required if using ledger.
ROOT_BRIDGE_RATE_ADMIN_LEDGER_INDEX=
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
## The address to be assigned with DEFAULT_ADMIN_ROLE in child adaptor.
CHILD_ADAPTOR_DEFAULT_ADMIN=
## The address to be assigned with BRIDGE_MANAGER_ROLE in child adaptor.
CHILD_ADAPTOR_BRIDGE_MANAGER=
## The address to be assigned with GAS_SERVICE_MANAGER_ROLE in child adaptor.
CHILD_ADAPTOR_GAS_SERVICE_MANAGER=
## The address to be assigned with TARGET_MANAGER_ROLE in child adaptor.
CHILD_ADAPTOR_TARGET_MANAGER=
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
## The address to be assigned with DEFAULT_ADMIN_ROLE in root adaptor.
ROOT_ADAPTOR_DEFAULT_ADMIN=
## The address to be assigned with BRIDGE_MANAGER_ROLE in root adaptor.
ROOT_ADAPTOR_BRIDGE_MANAGER=
## The address to be assigned with GAS_SERVICE_MANAGER_ROLE in root adaptor.
ROOT_ADAPTOR_GAS_SERVICE_MANAGER=
## The address to be assigned with TARGET_MANAGER_ROLE in root adaptor.
ROOT_ADAPTOR_TARGET_MANAGER=
## The capacity of the rate limit policy of IMX token, unit is in 10^18.
RATE_LIMIT_IMX_CAPACITY=
## The refill rate of the rate limit policy of IMX token, unit is in 10^18.
RATE_LIMIT_IMX_REFILL_RATE=
## The large threshold of the rate limit policy of IMX token, unit is in 10^18.
RATE_LIMIT_IMX_LARGE_THRESHOLD=
## The capacity of the rate limit policy of ETH token, unit is in 10^18.
RATE_LIMIT_ETH_CAPACITY=
## The refill rate of the rate limit policy of ETH token, unit is in 10^18.
RATE_LIMIT_ETH_REFILL_RATE=
## The large threshold of the rate limit policy of ETH token, unit is in 10^18.
RATE_LIMIT_ETH_LARGE_THRESHOLD=
## The address of USDC token to set rate limit policy.
RATE_LIMIT_USDC_ADDR=
## The capacity of the rate limit policy of USDC token, unit is in 10^18.
RATE_LIMIT_USDC_CAPACITY=
## The refill rate of the rate limit policy of USDC token, unit is in 10^18.
RATE_LIMIT_USDC_REFILL_RATE=
## The large threshold of the rate limit policy of USDC token, unit is in 10^18.
RATE_LIMIT_USDC_LARGE_THRESHOLD=
## The address of GU token to set rate limit policy.
RATE_LIMIT_GU_ADDR=
## The capacity of the rate limit policy of GU token, unit is in 10^18.
RATE_LIMIT_GU_CAPACITY=
## The refill rate of the rate limit policy of GU token, unit is in 10^18.
RATE_LIMIT_GU_REFILL_RATE=
## The large threshold of the rate limit policy of GU token, unit is in 10^18.
RATE_LIMIT_GU_LARGE_THRESHOLD=
## The address of CheckMate token to set rate limit policy.
RATE_LIMIT_CHECKMATE_ADDR=
## The capacity of the rate limit policy of CheckMate token, unit is in 10^18.
RATE_LIMIT_CHECKMATE_CAPACITY=
## The refill rate of the rate limit policy of CheckMate token, unit is in 10^18.
RATE_LIMIT_CHECKMATE_REFILL_RATE=
## The large threshold of the rate limit policy of CheckMate token, unit is in 10^18.
RATE_LIMIT_CHECKMATE_LARGE_THRESHOLD=
## The address of GOG token to set rate limit policy.
RATE_LIMIT_GOG_ADDR=
## The capacity of the rate limit policy of GOG token, unit is in 10^18.
RATE_LIMIT_GOG_CAPACITY=
## The refill rate of the rate limit policy of GOG token, unit is in 10^18.
RATE_LIMIT_GOG_REFILL_RATE=
## The large threshold of the rate limit policy of GOG token, unit is in 10^18.
RATE_LIMIT_GOG_LARGE_THRESHOLD=
```
3. Fund deployer
```
npx ts-node 1_deployer_funding.ts 2>&1 | tee bootstrap.out
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
npx ts-node 2_deployment_validation.ts 2>&1 | tee -a bootstrap.out
```
If multisig isn't deployed:
```
SKIP_MULTISIG_CHECK=true npx ts-node 2_deployment_validation.ts 2>&1 | tee -a bootstrap.out
```
7. Deploy bridge contracts on child and root chain.
```
npx ts-node 3_child_deployment.ts 2>&1 | tee -a bootstrap.out
npx ts-node 4_root_deployment.ts 2>&1 | tee -a bootstrap.out
```
8. Initialise bridge contracts on child chain.
```
npx ts-node 5_child_initialisation.ts 2>&1 | tee -a bootstrap.out
```
9. IMX Burning
```
npx ts-node 6_imx_burning.ts 2>&1 | tee -a bootstrap.out
```
10. IMX Rebalancing
```
npx ts-node 7_imx_rebalancing.ts 2>&1 | tee -a bootstrap.out
```
11. Initialise bridge contracts on root chain.
```
npx ts-node 8_root_initialisation.ts 2>&1 | tee -a bootstrap.out
```
12. Set the following environment variable
```
TEST_ACCOUNT_SECRET=
```
13. Test bridge functions
```
npx mocha --require mocha-suppress-logs ../e2e/ 2>&1 | tee -a bootstrap.out
```