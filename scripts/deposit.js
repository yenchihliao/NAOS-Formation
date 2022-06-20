const config = require('config')

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();
  console.log(deployer.address, rewarder.address, user.address);

  // const token = await Token.attach();
  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  const pool = await ethers.getContractAt("StakingPools", config.poolAddr);

  console.log("before");
  console.log(await token.balanceOf(deployer.address));
  console.log(await token.balanceOf(rewarder.address));
  console.log(await token.balanceOf(user.address));

  const tx = await pool.connect(user).deposit(0, 100);
  const rc = await tx.wait();
  console.log(rc);
  // await expect(pool.connect(user).deposit(0, 1))
  //   .to.emit(pool, 'TokensDeposited')
  //   .withArgs(user.address, 0, 1); 
  // console.log(rc);
  // console.log(await pool.getStakeTotalDeposited(user.address, 0));

  console.log("after");
  console.log(await token.balanceOf(deployer.address));
  console.log(await token.balanceOf(rewarder.address));
  console.log(await token.balanceOf(user.address));

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
