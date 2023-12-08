# End to End Tests

This folder contains the end to end tests that can be ran against the on chain contracts to verify basic functionalities. 

To run end to end tests:

1. Create `.env` file and contract addresses file
```
cp .env.example .env
cp .child.bridge.contracts.json.example .child.bridge.contracts.json
cp .root.bridge.contracts.json.example .root.bridge.contracts.json
```

2. Set the following fields inside each of the file

`.env`:
```
## Chain RPC
ROOT_RPC_URL=
ROOT_CHAIN_ID=
CHILD_RPC_URL=
CHILD_CHAIN_ID=
## The IMX token address on root chain.
ROOT_IMX_ADDR=
## The Wrapped ETH token address on the root chain.
ROOT_WETH_ADDR=
## The private key for rate admin.
ROOT_BRIDGE_RATE_ADMIN_SECRET=
## The private key for the test account.
TEST_ACCOUNT_SECRET=
```

`.child.bridge.contracts.json`:
```
{
  "CHILD_BRIDGE_ADDRESS": "",
  "CHILD_ADAPTOR_ADDRESS": "",
  "WRAPPED_IMX_ADDRESS": "",
  "CHILD_TOKEN_TEMPLATE": ""
}
```

`.root.bridge.contracts.json`:
```
{
  "ROOT_BRIDGE_ADDRESS": "",
  "ROOT_ADAPTOR_ADDRESS": "",
  "ROOT_TOKEN_TEMPLATE": "",
  "ROOT_TEST_CUSTOM_TOKEN": ""
}
```

3. Run end to end tests
```
AXELAR_API_URL=${Axelar API URL or "skip" if run on local} npx mocha --require mocha-suppress-logs ./e2e.ts
```