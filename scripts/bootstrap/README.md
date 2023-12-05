# Bridge bootstrapping

## Prerequisite
1. Coordinate with Axelar to obtain their admin address for initial funding as well as the desired amount in $IMX. (500 IMX in previous discussion).
2. Obtain the deployer account on both child chain and root chain.
3. Obtain the nonce reserved deployer account and reserved nonce on both child chain and root chain.
4. Obtain the amount to fund reserved deployer on child chain in $IMX. (10 IMX by default).
5. Obtain the amount to fund deployer on child chain in $IMX. (500 IMX by default).
6. Fund deployer with `ETH` and `IMX` on root chain. (As a rule of thumb, _0.1 ETH and 1100 IMX_ (TBD)).
7. Fund a test account with `ETH` and `IMX` on root chain. (As a rule of thumb, _0.1 ETH and 50 IMX_ (TBD)).

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
# Set prior to 0_pre_validation.js
# Name of the child chain MUST match Axelar's definition.
CHILD_CHAIN_NAME=
# The RPC URL of child chain.
CHILD_RPC_URL=
# The chain ID of the child chain.
CHILD_CHAIN_ID=
# Name of the root chain MUST match Axelar's definition.
ROOT_CHAIN_NAME=
# The RPC URL of root chain.
ROOT_RPC_URL=
# The chain ID of the root chain.
ROOT_CHAIN_ID=
## The deployer address on child & root chains.
DEPLOYER_ADDR=
## The private key for the deployer on child & root chains or "ledger" if using hardware wallet.
DEPLOYER_SECRET=
## The ledger index for the deployer on child & root chains, required if using ledger.
DEPLOYER_LEDGER_INDEX=
## The nonce reserved deployer address on child & root chains.
NONCE_RESERVED_DEPLOYER_ADDR=
## The nonce reserved deployer, or "ledger" if using hardware wallet.
NONCE_RESERVED_DEPLOYER_SECRET=
## The ledger index for the nonce reserved deployer.
NONCE_RESERVED_DEPLOYER_INDEX=
## The reserved nonce for token template deployment.
NONCE_RESERVED=
## The IMX token address on root chain.
ROOT_IMX_ADDR=
## The Wrapped ETH token address on the root chain.
ROOT_WETH_ADDR=
## The Axelar address to receive initial funding on the child chain.
AXELAR_EOA=
## The amount of fund Axelar requested, unit is in IMX or 10^18 Wei.
AXELAR_FUND=
## The amount of fund deployer to be left with after bootstrapping on L2, unit is in IMX or 10^18 Wei.
CHILD_DEPLOYER_FUND=
## The amount of fund nonce reserved deployer required on L2, unit is in IMX or 10^18 Wei.
CHILD_NONCE_RESERVED_DEPLOYER_FUND=
## The maximum amount of IMX that can be deposited to L2, unit is in IMX or 10^18 Wei.
IMX_DEPOSIT_LIMIT=
## The privileged transaction Multisig address on the root chain.
PRIVILEGED_ROOT_MULTISIG_ADDR=
# The pauser address on the root chain.
ROOT_PAUSER_ADDR=
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
3. Pre validation
```
npx ts-node 0_pre_validation.ts 2>&1 | tee bootstrap.out
```
4. Fund deployer
```
npx ts-node 1_deployer_funding.ts 2>&1 | tee bootstrap.out
```
5. Wait for Axelar to deploy & setup their system and Security team to deploy & setup multisig wallet.
6. Set the following environment variables
```
CHILD_GATEWAY_ADDRESS=
CHILD_GAS_SERVICE_ADDRESS=
MULTISIG_CONTRACT_ADDRESS=
ROOT_GATEWAY_ADDRESS=
ROOT_GAS_SERVICE_ADDRESS=
```
7. Basic contract validation
If multisig is deployed:
```
npx ts-node 2_deployment_validation.ts 2>&1 | tee -a bootstrap.out
```
If multisig isn't deployed:
```
SKIP_MULTISIG_CHECK=true npx ts-node 2_deployment_validation.ts 2>&1 | tee -a bootstrap.out
```
8. Deploy bridge contracts on child and root chain.
```
npx ts-node 3_child_deployment.ts 2>&1 | tee -a bootstrap.out
npx ts-node 4_root_deployment.ts 2>&1 | tee -a bootstrap.out
```
9. Initialise bridge contracts on child chain.
```
npx ts-node 5_child_initialisation.ts 2>&1 | tee -a bootstrap.out
```
10. IMX Burning
```
npx ts-node 6_imx_burning.ts 2>&1 | tee -a bootstrap.out
```
11. IMX Rebalancing
```
npx ts-node 7_imx_rebalancing.ts 2>&1 | tee -a bootstrap.out
```
12. Initialise bridge contracts on root chain.
```
npx ts-node 8_root_initialisation.ts 2>&1 | tee -a bootstrap.out
```
13. Set the following environment variable
```
TEST_ACCOUNT_SECRET=
```
14. Prepare for test
```
npx ts-node 9_test_preparation.ts 2>&1 | tee -a bootstrap.out
```
15. Test bridge functions
```
LONG_WAIT=1200000 SHORT_WAIT=300000 npx mocha --require mocha-suppress-logs ../e2e/e2e.ts 2>&1 | tee -a bootstrap.out
```