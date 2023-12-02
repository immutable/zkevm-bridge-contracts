# Local Development Network

Local development network contains:
1. Two hardhat local nodes to simulate the root chain and the child chain respectively
2. One axelar network to bridge messages between these two chains.

This folder contains the following bash scripts required to setup a local development network:
1. `start.sh`: To start the local development network.
2. `stop.sh`: To stop the local development network.
3. `deploy.sh`: To deploy and configure Immutable bridge contracts on both child chain and root chain.
4. `ci.sh`: Used by CI that detects if network is up before running `deploy.sh` and end to end tests.

## Start local development network
1. Set environment variables
```
cp .env.local .env
```
2. Start network
```
./start.sh
```
3. In a separate terminal, deploy bridge contracts
```
./deploy.sh
```
The addresses of deployed contracts will be saved in: 

`.child.bridge.contracts.json` for bridge contracts on the child chain.

`.root.bridge.contracts.json`. for bridge contracts on the root chain.

To run end to end tests against local development network:
```
LONG_WAIT=0 SHORT_WAIT=0 npx mocha --require mocha-suppress-logs ../e2e/e2e.ts
```