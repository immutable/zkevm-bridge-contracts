/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  networks: {
    hardhat: {
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