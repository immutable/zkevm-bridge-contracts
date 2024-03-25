// Deployment validation
import * as dotenv from "dotenv";
dotenv.config();
import { ethers } from "ethers";
import { requireEnv, hasDuplicates, requireNonEmptyCode } from "../helpers/helpers";
import { RetryProvider } from "../helpers/retry";

async function run() {
    console.log("=======Start Deployment Validation=======");

    // Check environment variables
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let rootRPCURL = requireEnv("ROOT_RPC_URL");
    let rootChainID = requireEnv("ROOT_CHAIN_ID");
    let childGatewayAddr = requireEnv("CHILD_GATEWAY_ADDRESS");
    let childGasServiceAddr = requireEnv("CHILD_GAS_SERVICE_ADDRESS");
    let multisigAddr = requireEnv("MULTISIG_CONTRACT_ADDRESS");
    let rootGatewayAddr = requireEnv("ROOT_GATEWAY_ADDRESS");
    let rootGasService = requireEnv("ROOT_GAS_SERVICE_ADDRESS");

    // Check duplicates
    if (hasDuplicates([childGatewayAddr, childGasServiceAddr, multisigAddr])) {
        throw("Duplicate address detected!");
    }
    if (hasDuplicates([rootGatewayAddr, rootGasService])) {
        throw("Duplicate address detected!");
    }

    const childProvider = new RetryProvider(childRPCURL, Number(childChainID));
    const rootProvider = new RetryProvider(rootRPCURL, Number(rootChainID));

    // Check child chain.
    console.log("Check contracts on child chain...");
    console.log("Check gateway contract...")
    await requireNonEmptyCode(childProvider, childGatewayAddr);
    console.log("Succeed.");
    console.log("Check gas service contract...")
    await requireNonEmptyCode(childProvider, childGasServiceAddr);
    console.log("Succeed.");
    if (process.env["SKIP_MULTISIG_CHECK"] != null) {
        console.log("Skip multisig contract check...");
    } else {
        console.log("Check multisig contract...");
        await requireNonEmptyCode(childProvider, multisigAddr);
        console.log("Succeed.");
    }

    // Check root chain.
    console.log("Check contracts on root chain...");
    console.log("Check gateway contract...");
    await requireNonEmptyCode(rootProvider, rootGatewayAddr);
    console.log("Succeed.");
    console.log("Check gas service contract...");
    await requireNonEmptyCode(rootProvider, rootGasService);
    console.log("Succeed.");

    console.log("=======End Deployment Validation=======");
}

run();