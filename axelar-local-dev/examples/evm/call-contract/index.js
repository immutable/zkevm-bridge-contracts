'use strict';

const util = require('util')
const {
    utils: { deployContract },
} = require('@axelar-network/axelar-local-dev');
const { ethers } = require('ethers');

const ExecutableSample = rootRequire('./artifacts/examples/evm/call-contract/ExecutableSample.sol/ExecutableSample.json');
const TOKEN = "0x38Aa1Cb12E5263eC0c6e9febC25B01116D346CD4"
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

async function execute(chains, wallet, options) {
    const { source, destination, calculateBridgeFee } = options;
    let functionToCall = options.args[2]
    if (functionToCall === "map") {
        await map(source, destination, calculateBridgeFee)
    } else if (functionToCall === "deposit") {
        await deposit(source, destination, calculateBridgeFee)
    } else {
        console.error("final arg must be either `deposit` or `map`")
        process.exit(1)
    }
}

async function map(source, destination, calculateBridgeFee) {
    console.log("======================================")
    console.log("ATTEMPTING TO SEND `MAP_TOKEN` MESSAGE")
    console.log("======================================")
    console.log()

    async function logValue() {
        let childTokenAddress = await destination.contract2.rootTokenToChildToken(TOKEN);
        console.log(`The L1 => L2 token mapping for token ${TOKEN.slice(0,8)}... is ${childTokenAddress.slice(0,8)}...`)
        if (childTokenAddress === ZERO_ADDRESS){
            console.log("This is empty, indicating that the L1 token hasn't been deployed yet on L2. :( :(")
        } else {
            console.log(childTokenAddress)
            console.log("This is no longer the zero address. The token has been mapped successfully!!! 📜 ☕ 📜 ☕ 📜 ☕ 📜 ☕ 📜 ☕ ")
        }
        console.log()
    }

    await logValue();

    console.log(`Calculating service fee...`);
    console.log()

    const fee = await calculateBridgeFee(source, destination);

    console.log(`Calling mapToken with a service fee of ${fee} ETH`);
    console.log()
    await source.contract.mapToken(TOKEN, {value: fee})

    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

    while ((await destination.contract2.rootTokenToChildToken(TOKEN)) === ZERO_ADDRESS) {
        console.log('Waiting...');
        console.log();
        await sleep(1000);
    }

    await logValue();
}

async function deposit(source, destination, calculateBridgeFee) {
    console.log("======================================")
    console.log("ATTEMPTING TO SEND `DEPOSIT` MESSAGE")
    console.log("======================================")
    console.log()

    const depositAmount = ethers.utils.parseEther("0.1")
    const userAddress = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    const balanceOfAbi = `
    [
        {
            "inputs": [
                {
                "internalType": "address",
                "name": "account",
                "type": "address"
                }
            ],
            "name": "balanceOf",
            "outputs": [
                {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [
              {
                "internalType": "address",
                "name": "spender",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
              }
            ],
            "name": "approve",
            "outputs": [
              {
                "internalType": "bool",
                "name": "",
                "type": "bool"
              }
            ],
            "stateMutability": "nonpayable",
            "type": "function"
          }
    ]
    `

    let l2TokenAddress = await destination.contract2.rootTokenToChildToken(TOKEN);
    if (l2TokenAddress == ZERO_ADDRESS) {
        console.log("The L1 token hasn't been mapped to L2 yet. Please run the `map` first first.");
        process.exit(1);
    }

    // User ethers to call the balanceOf function on the TOKEN contract
    let l2TokenContract = new ethers.Contract(l2TokenAddress, balanceOfAbi, destination.contract.signer)
    let l1TokenContract = new ethers.Contract(TOKEN, balanceOfAbi, source.contract.signer)

    const initialBal = await l2TokenContract.balanceOf(userAddress)

    async function logValue() {
        let l2Balance = await l2TokenContract.balanceOf(userAddress)
        let l1Balance = await l1TokenContract.balanceOf(userAddress)
        console.log(`The user currently has ${ethers.utils.formatEther(l2Balance).toString()} L2 token(s), and ${ethers.utils.formatEther(l1Balance).toString()} L1 token(s)`)
        console.log()
    }

    await logValue();

    console.log("Calling ERC20 approve...")
    console.log()

    await l1TokenContract.approve(source.contract.address, depositAmount);

    console.log(`Calculating service fee...`);
    console.log()

    const fee = await calculateBridgeFee(source, destination);

    console.log(`Calling deposit with ${ethers.utils.formatEther(depositAmount).toString()} tokens, and a service fee of ${fee} ETH`);
    console.log()
    await source.contract.deposit(TOKEN, depositAmount, {value: fee})

    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

    while ((await l2TokenContract.balanceOf(userAddress)).toString() === initialBal.toString()) {
        console.log('Waiting...');
        console.log();
        await sleep(1000);
    }

    await logValue();
}

module.exports = {
    execute,
};