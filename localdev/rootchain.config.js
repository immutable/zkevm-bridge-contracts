/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  networks: {
    hardhat: {
      // Root chain has 12 seconds of block time to mimic Ethereum Mainnet/Sepolia
      mining: {
        auto: false,
        interval: 12000
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