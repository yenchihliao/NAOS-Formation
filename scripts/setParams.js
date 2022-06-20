const { ethers } = require('hardhat')
const  config  = require('config')

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();
  // console.log(deployer.address, rewarder.address, user.address);

  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  const pools = await ethers.getContractAt("StakingPools", config.poolAddr);
  let tx;
  let rc;

  // (only once for diff tokens) create new token pool
  // tx = await pools.createPool(config.tokenAddr);
  // rc = await tx.wait();
  // console.log(rc);

  // set period
  tx = await pools.setPeriod(3 * 1e9);
  rc = await tx.wait();
  console.log(rc);

  // set period threshold
  tx = await pools.connect(deployer).setPeriodThreshold(10);
  rc = await tx.wait();
  console.log(rc);

  // set reward address
  tx = await pools.setRewardingAddress(rewarder.address);
  rc = await tx.wait();
  console.log(rc);

  // add a level
  tx = await pools.addLevel(1, 1, 10000000000);
  rc = await tx.wait();
  console.log(rc);


}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
