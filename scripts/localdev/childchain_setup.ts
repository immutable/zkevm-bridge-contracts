import * as dotenv from "dotenv";
dotenv.config();
import { ethers as hardhat } from "hardhat";
import { ethers } from "ethers";
import { requireEnv } from "../helpers/helpers";

async function main() {
    let childRPCURL = requireEnv("CHILD_RPC_URL");
    let childChainID = requireEnv("CHILD_CHAIN_ID");
    let childEOAKey = requireEnv("CHILD_ADMIN_EOA_SECRET");

    // Get child provider.
    let childProvider = new ethers.providers.JsonRpcProvider(childRPCURL, Number(childChainID));

    // Get admin EOA on the child chain.
    let childEOA = new ethers.Wallet(childEOAKey);

    // Give admin EOA account 2B IMX.
    await hardhat.provider.send("hardhat_setBalance", [
        childEOA.address,
        "0x6765c793fa10079d0000000",
    ]);

    console.log("Child admin EOA now has " + ethers.utils.formatEther(await childProvider.getBalance(childEOA.address)) + " IMX.");
    console.log("Finished setting up on child chain.")
}
main();