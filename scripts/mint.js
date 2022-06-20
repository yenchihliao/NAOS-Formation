const config = require('config')

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();
  console.log(deployer.address, rewarder.address, user.address);

  // const token = await Token.attach();
  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  const pool = await ethers.getContractAt("StakingPools", config.poolAddr);

  // console.log(await token.name());
  // token.mint(rewarder.address, 100000000);
  // token.mint(user.address, 100000000);
  let tx = await token.connect(rewarder).approve(config.poolAddr, 100000000);
  let rc = await tx.wait();
  console.log(rc);

  tx = await token.connect(user).approve(config.poolAddr, 100000000);
  rc = await tx.wait();
  console.log(rc);

  console.log(await token.balanceOf(deployer.address));
  console.log(await token.balanceOf(rewarder.address));
  console.log(await token.balanceOf(user.address));
  console.log(await pool.getPoolToken(0));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
