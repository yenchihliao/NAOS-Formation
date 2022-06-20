const { ethers } = require('hardhat')
const config = require('config')

async function main() {

    const [deployer, rewardAddress] = await ethers.getSigners()
    const governance = deployer.address
    const sentinel = deployer.address

    // const ERC20Mock = await ethers.getContractFactory('ERC20Mock')
    // const daiToken = await ERC20Mock.deploy('Mock DAI', 'DAI', 18)
    // console.log(`DAI Token: ${daiToken.address}`)
    // let token = daiToken.address;
    let token = config.tokenAddr;

    const StakingPools = await ethers.getContractFactory('StakingPools')
    const pools = await StakingPools.deploy(token, governance)
    console.log(`StakingPools: ${pools.address}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
