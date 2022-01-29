require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");

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
        enabled: true
      }
    }
  },
  defaultNetwork: "ropsten",
  networks: {
    hardhat: {},
		ropsten: {
			url: `https://ropsten.infura.io/v3/${config.infura}`,
			accounts: [config.privateKey],
		},
		mainnet: {
			url: `https://mainnet.infura.io/v3/${config.infura}`,
			accounts: [config.privateKey],
			gas: 3200000,
			gasPrice: 150000000000,
		},
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 100,
    excludeContracts: ['contracts/test'],
    coinmarketcap: config.coinmarketcap
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: config.etherscan
  }
};;
