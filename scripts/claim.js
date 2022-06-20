const config = require('config');

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();

  // const token = await Token.attach();
  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  const pool = await ethers.getContractAt("StakingPools", config.poolAddr);

  // pool.connect(user).deposit(0, 100);
  let tx = await pool.connect(user).claim(0, 2);
  let rc = await tx.wait();

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
