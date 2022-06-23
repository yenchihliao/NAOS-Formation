const config = require('config')

async function main() {
  const [deployer, rewarder, user] = await ethers.getSigners();

  // const token = await Token.attach();
  const token = await ethers.getContractAt("ERC20Mock", config.tokenAddr);
  let tx;
  let rc;

  tx = await token.connect(user).transfer(rewarder.address, 1);
  rc = await tx.wait();
  console.log(rc['status']);

  tx = await token.connect(rewarder).transfer(user.address, 1);
  rc = await tx.wait();
  console.log(rc['status']);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
