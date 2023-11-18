'use strict';
const { Network, networks, EvmRelayer, relay } = require('@axelar-network/axelar-local-dev');
const helper = require("./helpers.js");
const { ethers } = require("ethers");
const fs = require('fs');
require('dotenv').config();

let relaying = false;
const defaultEvmRelayer = new EvmRelayer();

async function main() {
    let rootChainName = helper.requireEnv("ROOT_CHAIN_NAME");
    let rootRPCURL = helper.requireEnv("ROOT_RPC_URL");
    let rootChainID = helper.requireEnv("ROOT_CHAIN_ID");
    let childChainName = helper.requireEnv("CHILD_CHAIN_NAME");
    let childRPCURL = helper.requireEnv("CHILD_RPC_URL");
    let childChainID = helper.requireEnv("CHILD_CHAIN_ID");
    let axelarRootDeployerKey = helper.requireEnv("AXELAR_ROOT_EOA_SECRET");
    let axelarChildDeployerKey = helper.requireEnv("AXELAR_CHILD_EOA_SECRET");

    // Create root chain.
    let rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let rootChain = new Network();
    rootChain.name = rootChainName;
    rootChain.chainId = Number(rootChainID);
    rootChain.provider = rootProvider;
    rootChain.ownerWallet = ethers.Wallet.createRandom().connect(rootProvider);
    rootChain.operatorWallet = ethers.Wallet.createRandom().connect(rootProvider);
    rootChain.relayerWallet = ethers.Wallet.createRandom().connect(rootProvider);
    rootChain.adminWallets = [
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
        ethers.Wallet.createRandom().connect(rootProvider),
    ];
    rootChain.threshold = 3;
    rootChain.lastRelayedBlock = await rootProvider.getBlockNumber();
    rootChain.lastExpressedBlock = rootChain.lastRelayedBlock;
    // Fund accounts
    let axelarRootDeployer = new ethers.Wallet(axelarRootDeployerKey, rootProvider);
    let resp = await axelarRootDeployer.sendTransaction({
        to: rootChain.ownerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, rootProvider);
    resp = await axelarRootDeployer.sendTransaction({
        to: rootChain.operatorWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, rootProvider);
    resp = await axelarRootDeployer.sendTransaction({
        to: rootChain.relayerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, rootProvider);
    for (let i = 0; i < 10; i++) {
        resp = await axelarRootDeployer.sendTransaction({
            to: rootChain.adminWallets[i].address,
            value: ethers.utils.parseEther("35.0"),
        })
        await helper.waitForReceipt(resp.hash, rootProvider);
    }
    // Deploy root contracts.
    await rootChain.deployConstAddressDeployer();
    await rootChain.deployCreate3Deployer();
    let rootGateway = await rootChain.deployGateway();
    let rootGasService = await rootChain.deployGasReceiver();
    networks.push(rootChain);

    // Create child chain.
    let childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let childChain = new Network();
    childChain.name = childChainName;
    childChain.chainId = Number(childChainID);
    childChain.provider = childProvider;
    childChain.ownerWallet = ethers.Wallet.createRandom().connect(childProvider);
    childChain.operatorWallet = ethers.Wallet.createRandom().connect(childProvider);
    childChain.relayerWallet = ethers.Wallet.createRandom().connect(childProvider);
    childChain.adminWallets = [
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
        ethers.Wallet.createRandom().connect(childProvider),
    ];
    childChain.threshold = 3;
    childChain.lastRelayedBlock = await childProvider.getBlockNumber();
    childChain.lastExpressedBlock = childChain.lastRelayedBlock;
    // Fund accounts
    let axelarChildDeployer = new ethers.Wallet(axelarChildDeployerKey, childProvider);
    resp = await axelarChildDeployer.sendTransaction({
        to: childChain.ownerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, childProvider);
    resp = await axelarChildDeployer.sendTransaction({
        to: childChain.operatorWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, childProvider);
    resp = await axelarChildDeployer.sendTransaction({
        to: childChain.relayerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, childProvider);
    for (let i = 0; i < 10; i++) {
        resp = await axelarChildDeployer.sendTransaction({
            to: childChain.adminWallets[i].address,
            value: ethers.utils.parseEther("35.0"),
        })
        await helper.waitForReceipt(resp.hash, childProvider);
    }
    // Deploy child contracts.
    await childChain.deployConstAddressDeployer();
    await childChain.deployCreate3Deployer();
    let childGateway = await childChain.deployGateway();
    let childGasService = await childChain.deployGasReceiver();
    networks.push(childChain);

    console.log("Axelar network started.")
    let contractData = {
        ROOT_GATEWAY_ADDRESS: rootGateway.address,
        ROOT_GAS_SERVICE_ADDRESS: rootGasService.address,
        CHILD_GATEWAY_ADDRESS: childGateway.address,
        CHILD_GAS_SERVICE_ADDRESS: childGasService.address,
    };
    fs.writeFileSync(".axelar.contracts.json", JSON.stringify(contractData));

    setInterval(async () => {
        if (relaying) return;
        relaying = true;
        await relay({ evm: defaultEvmRelayer }).catch(() => undefined);
        relaying = false;
    }, 2000);

    await defaultEvmRelayer.subscribeExpressCall();
}
main();