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
CHILD_CHAIN_NAME=
CHILD_RPC_URL=
CHILD_CHAIN_ID=
ROOT_CHAIN_NAME=
ROOT_RPC_URL=
ROOT_CHAIN_ID=
## The admin EOA address on the child chain that is allowed to top up the child bridge contract.
CHILD_ADMIN_ADDR=
## The multisig contract that is allowed to top up the child bridge contract.
MULTISIG_CONTRACT_ADDRESS=
## The private key for the deployer on child chain or "ledger" if using hardware wallet.
CHILD_DEPLOYER_SECRET=
## The ledger index for the deployer on child chain, required if using ledger.
CHILD_DEPLOYER_LEDGER_INDEX=
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