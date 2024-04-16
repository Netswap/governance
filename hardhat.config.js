require("@nomiclabs/hardhat-waffle");
require("@openzeppelin/hardhat-upgrades");
const { config } = require('dotenv');
const { resolve } = require('path');

config({ path: resolve(__dirname, "./.env") });

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

let mnemonic;
if (!process.env.MNEMONIC && !process.env.PRIVATE_KEY) {
    throw new Error("Please set your MNEMONIC or PRIVATE_KEY in a .env file");
} else {
    mnemonic = process.env.MNEMONIC;
    privateKey = process.env.PRIVATE_KEY;
}

const accounts = privateKey ? [process.env.PRIVATE_KEY] : { mnemonic };

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    hardhat: {
    },
    mainnet: {
      chainId: 1088,
      url: 'https://andromeda.metis.io/?owner=1088',
      accounts
    },
    testnet: {
      chainId: 59902,
      url: 'https://sepolia.metisdevops.link',
      accounts,
      gasPrice: 1000000000,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999
          }
        }
      }
    ]
  },
  etherscan: {
    apiKey: {
      testnet: "a non-empty string or just use api-key",
      andromeda: "a non-empty string or just use api-key",
    },
    customChains: [
      {
        network: "andromeda",
        chainId: 1088,
        urls: {
          apiURL: "https://andromeda-explorer.metis.io/api",
          browserURL: "https://andromeda-explorer.metis.io",
        },
      },
      {
          network: "testnet",
          chainId: 59902,
          urls: {
              apiURL: "https://sepolia-explorer-api.metisdevops.link/api",
              browserURL: "https://sepolia-explorer.metisdevops.link/",
          }
      }
    ],
  },
};

