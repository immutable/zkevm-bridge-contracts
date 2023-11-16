/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  networks: {
    hardhat: {
      // Child chain has 2 seconds of block time to mimic Immutable zkEVM
      mining: {
        auto: false,
        interval: 2000
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
