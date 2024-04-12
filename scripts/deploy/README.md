# Contracts deployment

This folder contains scripts to deploy and setup bridge contracts.

To deploy and setup contracts:

1. Create `.env` file
```
cp .env.example .env
```

2. Set the following fields inside `.env`
```
# Access to child and root chains.
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
## The passport nonce reserver
PASSPORT_NONCE_RESERVER_ADDR=
## The amount of fund Axelar requested, unit is in IMX or 10^18 Wei.
AXELAR_FUND=
## The amount of fund deployer to be left with after bootstrapping on L2, unit is in IMX or 10^18 Wei.
CHILD_DEPLOYER_FUND=
## The amount of fund nonce reserved deployer required on L2, unit is in IMX or 10^18 Wei.
CHILD_NONCE_RESERVED_DEPLOYER_FUND=
## The amount of fund passport reserver required on L2, unit is in IMX or 10^18 Wei.
PASSPORT_NONCE_RESERVER_FUND=
## The maximum amount of IMX that can be deposited to L2, unit is in IMX or 10^18 Wei.
IMX_DEPOSIT_LIMIT=
## The privileged transaction Multisig address on the root chain.
ROOT_PRIVILEGED_MULTISIG_ADDR=
# The break glass signer address on the root chain.
ROOT_BREAKGLASS_ADDR=
## The privileged transaction Multisig address on the child chain.
CHILD_PRIVILEGED_MULTISIG_ADDR=
# The break glass signer address on the child chain.
CHILD_BREAKGLASS_ADDR=
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
## The capacity of the rate limit policy of USDC token, unit is in 10^6.
RATE_LIMIT_USDC_CAPACITY=
## The refill rate of the rate limit policy of USDC token, unit is in 10^6.
RATE_LIMIT_USDC_REFILL_RATE=
## The large threshold of the rate limit policy of USDC token, unit is in 10^6.
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
## The gateway contract on the child chain.
CHILD_GATEWAY_ADDRESS=
## The gas service contract on the child chain.
CHILD_GAS_SERVICE_ADDRESS=
## The gateway contract on the root chain.
ROOT_GATEWAY_ADDRESS=
## The gas service contract on the child chain.
ROOT_GAS_SERVICE_ADDRESS=
```

3. Deploy and setup contracts:
```
npx ts-node deployAndInit.ts
```