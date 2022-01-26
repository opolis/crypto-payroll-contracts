// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const ethers = hre.ethers;
const config = require("../config.json");

async function main() {

    console.log("Deploying test token...");
    const TestToken = await ethers.getContractFactory("TestToken");
    const TT = await TestToken.deploy();

    await TT.deployed();
    console.log("Test token deployed to:", TT.address);

    console.log("Deploying test payroll contract...");
    const OpolisPayroll = await ethers.getContractFactory("OpolisPay");
    const payroll = await OpolisPayroll.deploy(
      config.wyreAddress, 
      config.opolisAdmin, 
      config.opolisHelper,
      [TT.address]);

    await payroll.deployed();
    console.log("Opolis Pay deployed to:", payroll.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });