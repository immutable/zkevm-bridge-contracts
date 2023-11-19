const { ethers, ContractFactory } = require("ethers");

function delay(time) {
    return new Promise(resolve => setTimeout(resolve, time));
}

exports.requireEnv = (envName) => {
    let val = process.env[envName];
    if (val == null || val == "") {
        throw(envName + " not set!");
    }
    if (!envName.includes("SECRET")) {
        console.log(envName + ": ", val);
    } else {
        console.log(envName + " is set.");
    }
    return val
}
exports.waitForReceipt = async (txHash, provider) => {
    let receipt;
    while (receipt == null) {
        receipt = await provider.getTransactionReceipt(txHash)
        await delay(1000);
    }
    if (receipt.status != 1) {
        throw("Fail to execute: " + txHash);
    }
    console.log(txHash + " succeed.");
}
exports.waitForConfirmation = async () => {
    for (let i = 10; i >= 0; i--) {
        console.log(i)
        await delay(1000);
    }
}
exports.getFee = async (wallet) => {
    let feeData = await wallet.getFeeData();
    let baseFee = feeData.lastBaseFeePerGas;
    let gasPrice = feeData.gasPrice;
    let priorityFee = Math.round(gasPrice * 150 / 100);
    let maxFee = Math.round(1.13 * baseFee + priorityFee);
    return [priorityFee, maxFee];
}
exports.requireNonEmptyCode = async (provider, addr) => {
    if (await provider.getCode(addr) == "0x") {
        throw(addr + " has empty code!");
    }
    console.log(addr + " has code.");
}
exports.hasDuplicates = (array) => {
    return (new Set(array)).size !== array.length;
}
exports.deployChildContract = async (contractObj, adminWallet, ...args) => {
    let [priorityFee, maxFee] = await getFee(adminWallet);
    let factory = new ContractFactory(contractObj.abi, contractObj.bytecode, adminWallet);
    return await factory.deploy(...args, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
}
exports.deployRootContract = async (contractObj, adminWallet, ...args) => {
    let factory = new ContractFactory(contractObj.abi, contractObj.bytecode, adminWallet);
    return await factory.deploy(...args);
}