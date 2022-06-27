const config = require('config')

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();
  console.log(deployer.address, rewarder.address, user.address);

  // const token = await Token.attach();
  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  const pools = await ethers.getContractAt("StakingPools", config.poolAddr);

  // set period threshold
  // tx = await pools.connect(deployer).setPeriodThreshold(2);
  // rc = await tx.wait();
  // console.log(rc['status']);

  // set reward address
  // tx = await pools.setRewardingAddress(rewarder.address);
  // rc = await tx.wait();
  // console.log(rc['status']);

  // add a level
  tx = await pools.addLevel(1, 0, 100);
  rc = await tx.wait();
  console.log(rc['status']);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
