'use strict';
const { Network, networks, EvmRelayer, relay } = require('@axelar-network/axelar-local-dev');
const helper = require("../helpers/helpers.js");
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
    let axelarRootEOAKey = helper.requireEnv("AXELAR_ROOT_EOA_SECRET");
    let axelarChildEOAKey = helper.requireEnv("AXELAR_CHILD_EOA_SECRET");
    let axelarDeployerKey = helper.requireEnv("AXELAR_DEPLOYER_SECRET");

    // Create root chain.
    let rootProvider = new ethers.providers.JsonRpcProvider(rootRPCURL, Number(rootChainID));
    let rootChain = new Network();
    rootChain.name = rootChainName;
    rootChain.chainId = Number(rootChainID);
    rootChain.provider = rootProvider;
    rootChain.ownerWallet = new ethers.Wallet(axelarDeployerKey, rootProvider);
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

    // Create child chain.
    let childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));
    let childChain = new Network();
    childChain.name = childChainName;
    childChain.chainId = Number(childChainID);
    childChain.provider = childProvider;
    childChain.ownerWallet = rootChain.ownerWallet.connect(childProvider);
    childChain.operatorWallet = rootChain.operatorWallet.connect(childProvider);
    childChain.relayerWallet = rootChain.relayerWallet.connect(childProvider);
    childChain.adminWallets = [
        rootChain.adminWallets[0].connect(childProvider),
        rootChain.adminWallets[1].connect(childProvider),
        rootChain.adminWallets[2].connect(childProvider),
        rootChain.adminWallets[3].connect(childProvider),
        rootChain.adminWallets[4].connect(childProvider),
        rootChain.adminWallets[5].connect(childProvider),
        rootChain.adminWallets[6].connect(childProvider),
        rootChain.adminWallets[7].connect(childProvider),
        rootChain.adminWallets[8].connect(childProvider),
        rootChain.adminWallets[9].connect(childProvider),
    ];
    childChain.threshold = 3;
    childChain.lastRelayedBlock = await childProvider.getBlockNumber();
    childChain.lastExpressedBlock = childChain.lastRelayedBlock;

    // Fund accounts on child chain.
    let axelarChildEOA = new ethers.Wallet(axelarChildEOAKey, childProvider);
    let resp = await axelarChildEOA.sendTransaction({
        to: childChain.ownerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, childProvider);
    resp = await axelarChildEOA.sendTransaction({
        to: childChain.operatorWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, childProvider);
    resp = await axelarChildEOA.sendTransaction({
        to: childChain.relayerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, childProvider);
    for (let i = 0; i < 10; i++) {
        resp = await axelarChildEOA.sendTransaction({
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

    // Fund accounts on root chain.
    let axelarRootEOA = new ethers.Wallet(axelarRootEOAKey, rootProvider);
    resp = await axelarRootEOA.sendTransaction({
        to: rootChain.ownerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, rootProvider);
    resp = await axelarRootEOA.sendTransaction({
        to: rootChain.operatorWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, rootProvider);
    resp = await axelarRootEOA.sendTransaction({
        to: rootChain.relayerWallet.address,
        value: ethers.utils.parseEther("35.0"),
    })
    await helper.waitForReceipt(resp.hash, rootProvider);
    for (let i = 0; i < 10; i++) {
        resp = await axelarRootEOA.sendTransaction({
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

    console.log("Axelar network started.")
    let contractData = {
        ROOT_GATEWAY_ADDRESS: rootGateway.address,
        ROOT_GAS_SERVICE_ADDRESS: rootGasService.address,
        CHILD_GATEWAY_ADDRESS: childGateway.address,
        CHILD_GAS_SERVICE_ADDRESS: childGasService.address,
    };
    fs.writeFileSync(".axelar.contracts.json", JSON.stringify(contractData, null, 2));

    setInterval(async () => {
        if (relaying) return;
        relaying = true;
        await relay({ evm: defaultEvmRelayer }).catch(() => undefined);
        relaying = false;
    }, 2000);

    await defaultEvmRelayer.subscribeExpressCall();
}
main();