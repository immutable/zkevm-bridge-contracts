import * as dotenv from "dotenv";
dotenv.config();
import { BigNumber, ethers } from "ethers";
import { RetryProvider } from "../helpers/retry";
import { getContract, requireEnv } from "../helpers/helpers";

// 7 days of blocks
const DURATION = 40320;
// 1 hr of blocks
const SAMPLE_WINDOW = 240;
// All tokens to check
const TOKENS = {
    "IMX": "0xf57e7e7c23978c3caec3c3548e3d615c346e79ff",
    // "ETH": "0x0000000000000000000000000000000000000Eee",
    // "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    // "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    // "wBTC": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    // "GODS": "0xccC8cb5229B0ac8069C51fd58367Fd1e622aFD97",
    // "GOG": "0x9AB7bb7FdC60f4357ECFef43986818A2A3569c62",
};
// Bridge Addr
const BRIDGE_ADDR = "0xBa5E35E26Ae59c7aea6F029B68c6460De2d13eB6";

function printUsage(timestamp: number, cap: BigNumber, depth: BigNumber, refillTime: BigNumber, refillRate: BigNumber) {
    // Calculate depth
    let refill = BigNumber.from(timestamp).sub(refillTime).mul(refillRate);
    depth = depth.add(refill);
    if (depth.gt(cap)) {
        depth = cap;
    }
    // Draw
    let remain = depth.mul(100).div(cap).toNumber();
    let bar = "  [" + "█".repeat(100 - remain) + " ".repeat(remain) + "] ";
    console.log(new Date(timestamp * 1000).toLocaleString() + "\t" + bar + (100 - remain) + "%");
}

export async function run() {
    let rpcURL = requireEnv("RPC_URL");
    let provider = new RetryProvider(rpcURL, 1);

    // Get bridge
    let bridge = getContract("RootERC20BridgeFlowRate", BRIDGE_ADDR, provider);

    // Get current block number
    let currentNumber = await provider.getBlockNumber();

    // Iterate through token
    for (let [token, addr] of Object.entries(TOKENS)) {
        console.log("=== " + token + " ===");
        let buckets: Promise<any>[] = [];
        let blocks: Promise<ethers.providers.Block>[] = [];
        for (let i = 0; i < DURATION / SAMPLE_WINDOW; i++) {
            buckets.push(bridge.flowRateBuckets(addr, {
                blockTag: currentNumber - i * SAMPLE_WINDOW
            }));
            blocks.push(provider.getBlock(currentNumber - i * SAMPLE_WINDOW));
        }
        let actualBuckets = await Promise.all(buckets);
        let actualBlocks = await Promise.all(blocks);
        for (let i = 0; i < actualBuckets.length; i++) {
            let bucket = actualBuckets[i];
            let block = actualBlocks[i];
            printUsage(block.timestamp, bucket.capacity, bucket.depth, bucket.refillTime, bucket.refillRate);
        }
    }
}
run();