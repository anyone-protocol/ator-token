import 'dotenv/config'
import { ethers } from 'hardhat'
import Consul from "consul"

async function main () {
    const deployerPrivateKey = process.env.TOKEN_DEPLOYER_KEY || '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d' // HH #1 
    const [ owner ] = await ethers.getSigners()
  
    const deployer = deployerPrivateKey
      ? new ethers.Wallet(
          deployerPrivateKey,
          new ethers.providers.JsonRpcProvider(process.env.JSON_RPC || 'http://127.0.0.1:8545/')
        )
      : owner
    
    console.log(`Deploying contract with deployer ${deployer.address}...`)
    
    const Contract = await ethers.getContractFactory('AnyoneProtocolToken', deployer)
    
    const result = await Contract.deploy(deployer.address)
    await result.deployed()
    console.log(`Contract deployed to ${result.address}`)
    
  if (process.env.PHASE !== undefined && process.env.CONSUL_IP !== undefined) {
    const consulKey = process.env.CONSUL_KEY || 'dummy-path'
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
