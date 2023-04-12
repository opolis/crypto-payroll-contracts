require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-abi-exporter");

const config = require("./config.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.5",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  defaultNetwork: "auroraTest",
  networks: {
    hardhat: {},
    mainnet: {
      url: `https://mainnet.infura.io/v3/${config.infura}`,
      accounts: [config.privateKey],
      gas: 3200000,
      gasPrice: 150000000000,
    },
    harmony: {
      url: `https://api.harmony.one`,
      accounts: [config.privateKey],
    },
    auroraTest: {
      url: `https://testnet.aurora.dev`,
      accounts: [config.privateKey],
    },
    aurora: {
      url: `https://mainnet.aurora.dev`,
      accounts: [config.privateKey],
    },
    auroraTestnet: {
      url: `https://testnet.aurora.dev`,
      accounts: [config.privateKey],
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${config.infura}`,
      accounts: [config.privateKey],
    },
    mumbai: {
      url: `https://matic-mumbai.chainstacklabs.com`,
      accounts: [config.privateKey],
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${config.infura}`,
      accounts: [config.privateKey],
      gas: 3200000,
      gasPrice: 150000000000,
    },
    xdai: {
      url: `https://rpc.xdaichain.com`,
      accounts: [config.privateKey],
    },
  },
  // gasReporter: {
  //   currency: 'USD',
  //   gasPrice: 100,
  //   excludeContracts: ['contracts/test'],
  //   coinmarketcap: config.coinmarketcap
  // },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: {
      mainnet: config.etherscan,
      polygon: config.polyscan,
      polygonMumbai: config.polyscan,
      harmony: "key",
      aurora: "key",
    },
  },
  abiExporter: {
    path: "./abi",
    clear: true,
    flat: true,
    runOnCompile: true,
    // only: [],
  },
};
