const { expect } = require("chai");
const config = require('config');

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();
  console.log(deployer.address, rewarder.address);

  // const token = await Token.attach();
  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  const pool = await ethers.getContractAt("StakingPools", config.poolAddr);

  console.log("# staking pool, stake balances: ");
  console.log(await pool.getPoolTotalDeposited(0));
  console.log(await pool.getStakeTotalDeposited(user.address, 0));
  console.log("# ERC20 deployer, rewarder, user balances: ");
  console.log(await token.balanceOf(deployer.address));
  console.log(await token.balanceOf(rewarder.address));
  console.log(await token.balanceOf(user.address));
  console.log(await pool.getPoolToken(0));
  console.log("# contract period, threshold, rewardAddr, levels");
  console.log(await pool.getPeriod());
  console.log(await pool.getPeriodThreshold());
  console.log(await pool.getRewardingAddress());
  let n = await pool.getLevelCount();
  for(let i = 0;i < n;i++){
    console.log(await pool.getLevel(i));
  }

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
