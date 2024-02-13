import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      hardfork: "shanghai",
      mining: {
        auto: false,
        interval: 1200
      },
      chainId: 2500,
      accounts: [],
    },
    localhost: {
      url: "http://127.0.0.1:8500/",
    }
  },
  solidity: "0.8.19",
};
export default config;