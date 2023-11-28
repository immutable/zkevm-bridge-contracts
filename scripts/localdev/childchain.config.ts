import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      mining: {
        auto: false,
        interval: 200
      },
      chainId: 2501,
      accounts: [],
    },
    localhost: {
      url: "http://127.0.0.1:8501/",
    }
  },
  solidity: "0.8.19",
};
export default config;