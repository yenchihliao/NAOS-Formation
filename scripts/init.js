const { ethers } = require('hardhat')
const  config  = require('config')

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();
  // console.log(deployer.address, rewarder.address, user.address);

  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  const pools = await ethers.getContractAt("StakingPools", config.poolAddr);
  let tx;
  let rc;

  // console.log(await token.name());
  // token.mint(rewarder.address, 100000000);
  // token.mint(user.address, 100000000);

  // approve erc20 token to staking contract
  tx = await token.connect(rewarder).approve(config.poolAddr, 100000000);
  rc = await tx.wait();
  console.log(rc['status']);
  tx = await token.connect(user).approve(config.poolAddr, 100000000);
  rc = await tx.wait();
  console.log(rc['status']);

  // (only once for diff tokens) create new token pool
  tx = await pools.createPool(config.tokenAddr);
  rc = await tx.wait();
  console.log(rc['status']);

  // set period
  tx = await pools.setPeriod(25 * 1e9);
  rc = await tx.wait();
  console.log(rc['status']);

  // set period threshold
  tx = await pools.connect(deployer).setPeriodThreshold(2);
  rc = await tx.wait();
  console.log(rc['status']);

  // set reward address
  tx = await pools.setRewardingAddress(rewarder.address);
  rc = await tx.wait();
  console.log(rc['status']);

  // add a level
  tx = await pools.addLevel(1, 0, 100);
  rc = await tx.wait();
  console.log(rc['status']);

  console.log(await token.balanceOf(deployer.address));
  console.log(await token.balanceOf(rewarder.address));
  console.log(await token.balanceOf(user.address));
  console.log(await pools.getPoolToken(0));

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
