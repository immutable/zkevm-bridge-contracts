import { ContractFactory, providers, ethers } from "ethers";
import { LedgerSigner } from "./ledger_signer";
import * as fs from "fs";

export function delay(time: number) {
    return new Promise(resolve => setTimeout(resolve, time));
}

export function requireEnv(envName: string) {
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

export async function waitForReceipt(txHash: string, provider: providers.JsonRpcProvider) {
    let receipt;
    while (receipt == null) {
        receipt = await provider.getTransactionReceipt(txHash)
        await exports.delay(1000);
    }
    console.log("Receipt: " + JSON.stringify(receipt, null, 2));
    if (receipt.status != 1) {
        throw("Fail to execute: " + txHash);
    }
    console.log("Tx " + txHash + " succeed.");
}

export async function waitForConfirmation() {
    if (process.env["SKIP_WAIT_FOR_CONFIRMATION"] == null) {
        for (let i = 10; i >= 0; i--) {
            console.log(i)
            await exports.delay(1000);
        }
    }
}

export async function getFee(provider: providers.JsonRpcProvider) {
    let feeData = await provider.getFeeData();
    let baseFee = feeData.lastBaseFeePerGas;
    let gasPrice = feeData.gasPrice;
    let priorityFee;
    let maxFee;
    if (gasPrice && baseFee) {
        priorityFee = gasPrice.mul(150).div(100);
        maxFee = baseFee.mul(113).div(100).add(priorityFee);
    } else {
        priorityFee = ethers.utils.parseUnits("110", "gwei");
        maxFee = ethers.utils.parseUnits("120", "gwei");
    }
    return [priorityFee, maxFee];
}

export async function requireNonEmptyCode(provider: providers.JsonRpcProvider, addr: string) {
    if (await provider.getCode(addr) == "0x") {
        throw(addr + " has empty code!");
    }
    console.log(addr + " has code.");
}

export function hasDuplicates(array: string[]) {
    return (new Set(array)).size !== array.length;
}

export async function deployChildContract(contract: string, adminWallet: ethers.Wallet | LedgerSigner, ...args: any) {
    let contractObj = JSON.parse(fs.readFileSync(`../../out/${contract}.sol/${contract}.json`, 'utf8'));
    let [priorityFee, maxFee] = await exports.getFee(adminWallet);
    let factory = new ContractFactory(contractObj.abi, contractObj.bytecode, adminWallet);
    return await factory.deploy(...args, {
        maxPriorityFeePerGas: priorityFee,
        maxFeePerGas: maxFee,
    });
}

export async function deployRootContract(contract: string, adminWallet: ethers.Wallet | LedgerSigner, ...args: any) {
    let contractObj = JSON.parse(fs.readFileSync(`../../out/${contract}.sol/${contract}.json`, 'utf8'));
    let factory = new ContractFactory(contractObj.abi, contractObj.bytecode, adminWallet);
    return await factory.deploy(...args);
}

export function getContract(contract: string, contractAddr: string, provider: providers.JsonRpcProvider) {
    let contractObj = JSON.parse(fs.readFileSync(`../../out/${contract}.sol/${contract}.json`, 'utf8'));
    return new ethers.Contract(contractAddr, contractObj.abi, provider);
}