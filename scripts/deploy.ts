import { ethers } from 'hardhat'
import Consul from "consul"

async function main () {
    const [ owner ] = await ethers.getSigners()
  
    const deployerPrivateKey = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY || "nokey", 
      new ethers.providers.JsonRpcProvider('https://ethereum-goerli.publicnode.com'))
        || owner
    
    console.log(`Deploying contract...`)
    
    const Contract = await ethers.getContractFactory('ATOR', deployerPrivateKey)
    
    const result = await Contract.deploy()
    await result.deployed()
    console.log(`Contract deployed to ${result.address}`)
    
  if (process.env.PHASE !== undefined && process.env.CONSUL_IP !== undefined) {
    const consulKey = process.env.CONSUL_KEY || 'smart-contracts/stage/test-deploy'
    const consulToken = process.env.CONSUL_TOKEN || 'no-token'
    console.log(`Connecting to Consul at ${process.env.CONSUL_IP}:${process.env.CONSUL_PORT}...`)
    const consul = new Consul({
      host: process.env.CONSUL_IP,
      port: process.env.CONSUL_PORT,
    });

    const updateResult = await consul.kv.set({
      key: consulKey,
      value: result.address,
      token: consulToken
    });
    console.log(`Cluster variable updated: ${updateResult}`)
  } else {
    console.warn('Deployment env var PHASE not defined, skipping update of cluster variable in Consul.')
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
