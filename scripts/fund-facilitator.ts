import 'dotenv/config'
import '@nomiclabs/hardhat-ethers'
import { ethers } from 'hardhat'
import Consul from 'consul'

import { abi } from '../artifacts/contracts/ator-token-nodex.sol/ATOR.json'

async function main() {
  const isLocal = (process.env.PHASE === undefined)
  let atorContractAddress = process.env.ATOR_TOKEN_CONTRACT_ADDRESS
    || 'ator-token-address-not-set'
    let facilitatorContractAddress = process.env.FACILITATOR_CONTRACT_ADDRESS
    || 'ator-token-address-not-set'

  const consulToken = process.env.CONSUL_TOKEN || undefined
  if (process.env.PHASE !== undefined && process.env.CONSUL_IP !== undefined) {
    console.log(`Connecting to Consul at ${process.env.CONSUL_IP}:${process.env.CONSUL_PORT}...`)
    const consul = new Consul({
      host: process.env.CONSUL_IP,
      port: process.env.CONSUL_PORT,
    });

    atorContractAddress = (await consul.kv.get<{ Value: string }>({
      key: process.env.TOKEN_CONSUL_KEY || 'dummy-path',
      token: consulToken
    })).Value

    facilitatorContractAddress = (await consul.kv.get<{ Value: string }>({
      key: process.env.FACILITATOR_CONSUL_KEY || 'dummy-path',
      token: consulToken
    })).Value
  }

  const provider = new ethers.providers.JsonRpcProvider(
    (isLocal)
      ? 'http://127.0.0.1:8545/'
      : process.env.JSON_RPC || 'http://127.0.0.1:8545/'
  )

  const deployer = new ethers.Wallet(
    process.env.TOKEN_DEPLOYER_KEY || 
      '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', // HH #1 
    provider
  )

  const atorToken = new ethers.Contract(atorContractAddress, abi, deployer)
  const fundValue = process.env.FUND_VALUE || '10'
  const enableTradingResult = await atorToken.transfer(facilitatorContractAddress, ethers.utils.parseEther(fundValue))
  await enableTradingResult.wait()
  console.log(`Operator ${deployer.address} of ${atorContractAddress} sent ${fundValue} tokens to facilitator contract ${facilitatorContractAddress}`)  
  console.log(`removeLimits() tx ${enableTradingResult.hash} confirmed!`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
