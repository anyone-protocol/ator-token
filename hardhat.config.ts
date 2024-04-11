import '@nomiclabs/hardhat-ethers'
import { HardhatUserConfig } from 'hardhat/config'

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 5
      },
    },
  },
  networks: {
    hardhat: {
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      // timeout: 1800000
    },
    goerli: {
      url: "https://ethereum-goerli.publicnode.com",
      accounts: [],
    },
    sepolia: {
      url: "https://ethereum-goerli.publicnode.com",
      accounts: [],
    },
  }
}

export default config

// require('@nomiclabs/hardhat-ethers')

// /** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   solidity: {
//     version: "0.8.10",
//     settings: {
//       optimizer: {
//         enabled: true,
//         runs: 5
//       },
//     },
//   },
//   networks: {
//     hardhat: {
//       gas: 12000000,
//       blockGasLimit: 0x1fffffffffffff,
//       allowUnlimitedContractSize: true,
//       timeout: 1800000
//     },
//     goerli: {
//       url: "https://ethereum-goerli.publicnode.com",
//       accounts: [],
//     },
//   }
// };
