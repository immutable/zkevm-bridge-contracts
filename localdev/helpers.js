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
    console.log("Succeed.");
}