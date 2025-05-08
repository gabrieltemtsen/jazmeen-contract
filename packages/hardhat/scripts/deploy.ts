import * as dotenv from "dotenv";
dotenv.config();
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const NFT_POSITION_MANAGER = "0x3b3f0A1948bAb88A88f54124523d120B1aA2d6a"; // Ubeswap V3 on Celo
  const JazmeenFactory = await hre.ethers.getContractFactory("JazmeenFactory");

   const factory = await JazmeenFactory.deploy(deployer.address, NFT_POSITION_MANAGER);
  await factory.waitForDeployment();
  console.log("JazmeenFactory deployed at:", factory.target); 

  //TODO add UBESWAP liquidity pool creation
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error deploying:", error);
    process.exit(1);
  });