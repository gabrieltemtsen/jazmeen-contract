import * as dotenv from "dotenv";
dotenv.config();
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Launching memecoin with account:", deployer.address);

  const FACTORY_ADDRESS = "YOUR_FACTORY_ADDRESS_HERE"; // Replace after deploy
  const JazmeenFactory = await hre.ethers.getContractFactory("JazmeenFactory");
  const factory = JazmeenFactory.attach(FACTORY_ADDRESS).connect(deployer);

  const celoBalance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Deployer CELO balance:", hre.ethers.formatEther(celoBalance));

  const name = "GabedevCoin101";
  const symbol = "GABDEV101";
  const initiatorFid = 420564;
  const imageUrl = "https://example.com/image.jpg";
  const creator = deployer.address; // Replace with Farcaster user address if needed
  console.log(`Deploying ${name} (${symbol}) for Initiator FID ${initiatorFid} with image ${imageUrl}...`);

  const tx = await factory.deployToken(name, symbol, initiatorFid, imageUrl, creator, { 
    gasLimit: 5000000,
    value: hre.ethers.parseEther("2") // 2 CELO for liquidity
  });
  const receipt = await tx.wait();
  console.log("Transaction hash:", receipt.hash);

  const tokens = await factory.getTokens();
  const tokenInfo = tokens[tokens.length - 1];
  console.log(`Memecoin deployed at: ${tokenInfo.tokenAddress}`);
  console.log(`Initiator FID: ${tokenInfo.initiatorFid}, Image URL: ${tokenInfo.imageUrl}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error launching memecoin:", error);
    process.exit(1);
  });