const config = require("./config");
async function main() {
  console.log(config.tokenAddr);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
