import * as dotenv from "dotenv";
dotenv.config();
const hre = require("hardhat");

async function main() {
    // Deploy JazmeenFactory with your deployer address
    const [deployer] = await hre.ethers.getSigners();
  
    console.log("Deploying contracts with account:", deployer.address);
  
    // Deploy the Factory contract
    const JazmeenFactory = await hre.ethers.deployContract("JazmeenFactory");
    const factory = await JazmeenFactory.deploy(deployer.address);  // Pass deployer address
  
    await factory.waitForDeployment();
    console.log("JazmeenFactory deployed to:", factory.address);
  }
  
  // Run the script
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });