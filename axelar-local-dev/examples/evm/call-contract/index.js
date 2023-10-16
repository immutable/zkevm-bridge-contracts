'use strict';

const {
    utils: { deployContract },
} = require('@axelar-network/axelar-local-dev');

const ExecutableSample = rootRequire('./artifacts/examples/evm/call-contract/ExecutableSample.sol/ExecutableSample.json');

async function deploy(chain, wallet) {
    console.log(`Deploying ExecutableSample for ${chain.name}.`);
    chain.contract = await deployContract(wallet, ExecutableSample, [chain.gateway, chain.gasService]);
    // chain.contract = "EXECUTABLE_ADDRESS"
    chain.wallet = wallet;
    console.log(`Deployed ExecutableSample for ${chain.name} at ${chain.contract.address}.`);
}

async function execute(chains, wallet, options) {

    console.log('execute call-contract');
    const args = options.args || [];
    const { source, destination, calculateBridgeFee } = options;
    const message = args[2] || `Hello ${destination.name} from ${source.name}, it is ${new Date().toLocaleTimeString()}.`;

    async function logValue() {
        //console.log(destination.contract2)
        console.log(destination.name)
        console.log(`value at ${destination.name} is "${await destination.contract.rootTokenToChildToken("0x38Aa1Cb12E5263eC0c6e9febC25B01116D346CD4")}"`);
        //console.log(await destination.contract2.rootTokenToChildToken("0x38Aa1Cb12E5263eC0c6e9febC25B01116D346CD4"));
    }

    console.log('--- Initially ---');
    await logValue();

    const fee = await calculateBridgeFee(source, destination);

    console.log('fee',fee);

    // const tx = await source.contract.setRemoteValue(destination.name, destination.contract.address, message, {
        // value: fee,
    // });
    console.log("SOURCE CONTRACT: ", source.contract.address)
    console.log("Calling mapToken");
    // const tx = await source.contract.deposit("0x38C50773CdA2E79a9217f40d63A8faF8fb0D4d73", "9999", {value: fee})
    const tx = await source.contract.mapToken("0x38Aa1Cb12E5263eC0c6e9febC25B01116D346CD4", {value: fee})
    await tx.wait();
    console.log("Called ++++++++++++")

    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

    while ((await destination.contract.rootTokenToChildToken("0x38Aa1Cb12E5263eC0c6e9febC25B01116D346CD4")) == "0x0000000000000000000000000000000000000000") {
        console.log('Waiting...');
        await sleep(3000);
    }

    console.log('--- After ---');
    await logValue();
}

module.exports = {
    deploy,
    execute,
};