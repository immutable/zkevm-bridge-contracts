# Manual Bridging Guide
<!-- TOC -->
  * [Overview](#overview)
  * [Mapping ERC-20 Token](#mapping-erc-20-token)
    * [Checking if a token is mapped](#checking-if-a-token-is-mapped)
    * [Mapping Token](#mapping-token)
  * [Depositing ERC-20 Token](#depositing-erc-20-token)
    * [ERC-20 Approval](#erc-20-approval)
    * [Depositing Token](#depositing-token)
  * [Depositing ETH](#depositing-eth)
  * [Estimating Bridge Fee](#estimating-bridge-fee)
  * [Resources](#resources)
    * [Bridge Addresses](#bridge-addresses)
    * [Supporting Tools](#supporting-tools)
<!-- TOC -->

## Overview
This document outlines the procedure for manually transferring funds to Immutable zkEVM from Ethereum through direct interaction with the bridge contracts. This method serves as an alternative to the recommended [Immutable Toolkit](https://toolkit.immutable.com/bridge/) user interface. The document also provides details about registering (mapping) new tokens.

This guide involves interacting directly with contracts using Etherscan. It assumes the reader has a basic familiarity with how to interact with contracts, including reading state and performing transactions, via Etherscan.

## Mapping ERC-20 Token
For a token to be bridged through the Immutable zkEVM bridge, it first needs to be mapped (registered). The mapping process creates a representative token contract on L2 for each token contract on L1. Mapping is a permissionless process that anyone can perform. Although many tokens have already been mapped on the bridge, the token you want to bridge may not have been. Therefore, it's important to check first.

### Checking if a token is mapped
- Navigate to the Root bridge contract on Etherscan ([mainnet](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6), [testnet](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5))
- Select Contract → “Read as Proxy”.
- Invoke the `rootTokenToChildToken()` function by providing the L1 ERC-20 token's address.
- If the returned value isn't the `0x0` address, the token has already been mapped and you can proceed to depositing funds. If it hasn't been mapped yet, see below for how to map a token.

### Mapping Token
- Navigate to the Root bridge contract on Etherscan ([mainnet](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6), [testnet](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5))
- Select Contract → “Write as Proxy”.
- Execute the `mapToken()` function by providing:
    - `payableAmount` : Bridge fee estimate in ETH (see [Estimating Bridge Fee](#estimating-bridge-fee) for details)
    - `rootToken`: L1 ERC-20 token address
- The transaction will perform a cross-chain call to the L2, where a representative token will be created for the given L1 token.
- This process can take ~20minutes to be completed on the destination chain.  You can track the progress of this cross-chain call by going to Axelarscan ([mainnet](https://axelarscan.io/), [testnet](https://testnet.axelarscan.io/)) and providing the transaction hash in the search field at the top right.

Note: The bridge only supports standard ERC-20 tokens, so make sure your token adheres to this interface

## Depositing ERC-20 Token
Depositing ERC-20, requires two separate steps: 1) Approving the bridge contract to transfer funds on-behalf of the user, for the given ERC-20 contract and 2) Depositing funds on the bridge

### ERC-20 Approval
- For the ERC-20 token that you would like to deposit, navigate to its address on Etherscan
- Select Contract → “Write Contract”
  - If the contract is behind a proxy (e.g. USDC), you’ll see “Write as Proxy” as an option. If so, choose this option instead
  - This process assumes the ERC-20 contract is verified. If you don’t see any of the above options, it means the contract is not verified on Etherscan and should be verified before proceeding. This process is not covered in this document.
- Execute `approve()` function providing the following parameters:
  - `spender` : The address of the Root bridge. For mainnet you’d use [`0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6`](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6) for testnet [`0x0d3c59c779fd552c27b23f723e80246c840100f5`](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5)
   - `amount`: The amount to approve in the base unit of the token. This would be equal to or higher than the amount you intend to deposit in the next step.
        e.g. 10IMX would be represented as `10000000000000000000`, because IMX uses 18 decimals, whereas 10USDC would be represented as `10000000`, because USDC uses 6 decimals.

### Depositing Token
- Navigate to the Root bridge contract on Etherscan ([mainnet](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6), [testnet](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5))
- Select Contract → “Write as Proxy”.
- Execute the `deposit()` function, providing the following parameters:
  - `payableAmount` : Bridge fee estimate in ETH (see [Estimating Bridge Fee](#estimating-bridge-fee) for details)
  - `rootToken` : Address of ERC-20 contract on L1
  - `amount`: Amount to transfer in the base unit of the token e.g. 10IMX would be represented as `10000000000000000000`, because IMX uses 18 decimals, whereas 10USDC would be represented as `10000000`, because USDC uses 6 decimals.
  - **Note:** The `deposit()` function will transfer funds to the same address on L2 as the sender executing this transaction on L1. If however, you’d like to deposit to a different address use the `depositTo` function, which will take an additional parameter `receiver` which is the address of the receiver on L2.
- The transaction will first transfer the specified amount of ERC-20 from the user to the bridge and perform a cross-chain call to the L2 to mint a corresponding amount of tokens to the intended receiver address.
- This process can take ~20minutes to be completed on the destination chain.  You can track the progress of this cross-chain call by going to Axelarscan ([mainnet](https://axelarscan.io/), [testnet](https://testnet.axelarscan.io/)) and providing the transaction hash in the search field at the top right.
- Once completed, the funds will be available in the recipient's address on L2.

Note: The bridge only supports standard ERC-20 tokens, so make sure your token adheres to this interface

## Depositing ETH
- Navigate to the Root bridge contract on Etherscan  ([mainnet](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6), [testnet](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5))
- Select Contract → “Write as Proxy”.
- Execute the `depositETH()` function, providing the following parameters:
    - `payableAmount` : This amount should be the sum of two things
        - Amount to transfer in ETH
        - Bridge fee estimate in ETH (see [Estimating Bridge Fee](#estimating-bridge-fee) for details)
    - `amount`: Amount to transfer in wei e.g. 1 ETH would be represented as `100000000000000`
    - **Note:** The `depositETH()` function will transfer funds to the same address on L2 as the sender executing this transaction on L1. If however, you’d like to deposit to a different address use the `depositToETH`function, which will take an additional parameter `receiver` which is the address of the receiver on L2.
- The transaction will first transfer the specified amount of ERC-20 from the user to the bridge and perform a cross-chain call to the L2 to mint a corresponding amount of tokens to the intended receiver address.
- This process can take ~20minutes to be completed on the destination chain.  You can track the progress of this cross-chain call by going to Axelarscan ([mainnet](https://axelarscan.io/), [testnet](https://testnet.axelarscan.io/)) and providing the transaction hash in the search field at the top right.
- Once completed, the funds will be available in the recipient's address on L2. Note that whether you deposit native ETH using this method or wrapped ETH via the ERC-20 token deposit method, the wrapped ETH token received on Layer 2 will be the same.

## Estimating Bridge Fee
Estimates for bridge fees are obtained through Axelar's API. These fees encompass the costs for Axelar validators to validate transactions, as well as the gas costs incurred when executing a transaction on the destination chain.

- Go to Axelar’s API docs [here](https://docs.axelarscan.io/gmp#estimateGasFee)
- Select the environment that you’d like a quote for (Testnet or Mainnet)
- Execute the `estimateGasFee` endpoint, providing the following parameter details
    - Source Chain: if mainnet, use `Ethereum` if testnet use `Sepolia`
    - Destination Chain: `immutable`
    - Gas Limit: `200000`
    - Gasa Multiplier: `1.1`
- The result will be the gas cost in wei. If you need the amount in ETH, use the [Wei to Eth converter](https://www.eth-to-wei.com/) to convert the value.


## Resources
### Bridge Addresses
- Mainnet:
  - Ethereum (Root Bridge): [0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6](https://etherscan.io/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6)
  - Immutable zkEVM (Child Bridge): [0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6](https://explorer.immutable.com/address/0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6)
- Testnet:
  - Sepolia (Root Bridge): [0x0d3c59c779fd552c27b23f723e80246c840100f5](https://sepolia.etherscan.io/address/0x0d3c59c779fd552c27b23f723e80246c840100f5)
  - Immutable zkEVM Testnet (Child Bridge): [0x0D3C59c779Fd552C27b23F723E80246c840100F5](https://explorer.testnet.immutable.com/address/0x0D3C59c779Fd552C27b23F723E80246c840100F5)

### Supporting Tools
- [Convert Ether to Wei](https://www.eth-to-wei.com/)
- [Axelar API](https://docs.axelarscan.io/gmp#estimateGasFee)
- [Axelarscan Mainnet](https://axelarscan.io/)
- [Axelarscan Testnet](https://testnet.axelarscan.io/)