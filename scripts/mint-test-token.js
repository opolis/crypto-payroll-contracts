// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const ethers = hre.ethers;
const config = require("../config.json");

async function main() {
  const TT = await ethers.getContractAt(
    "TestToken",
    "0x22a8fe0109b5457aE5C9E916838e807dd8B0A5B6" // TestToken address
  );
  const TT2 = await ethers.getContractAt(
    "TestToken2",
    "0x695937229C8Ad9a424506aE0cb1bd23fF6F7330e" // TestToken address
  );

  await TT.mint(config.opolisAdmin, ethers.utils.parseEther("100000000"));
  await TT2.mint(config.opolisAdmin, ethers.utils.parseEther("100000000"));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
