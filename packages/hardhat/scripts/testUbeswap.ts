import * as dotenv from "dotenv";
dotenv.config();
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Testing Ubeswap with account:", deployer.address);

  // Deploy a standalone token
  const JazmeenToken = await hre.ethers.getContractFactory("JazmeenToken");
  const token = await JazmeenToken.deploy(
    "TestCoin",
    "TST",
    1_000_000, // TOTAL_SUPPLY
    "https://example.com/test.jpg",
    deployer.address // Factory is deployer for this test
  );
  await token.waitForDeployment();
  console.log("Token deployed at:", token.target);

  // Ubeswap router
  const UBESWAP_ROUTER = "0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121";
  const liquidityAmount = hre.ethers.parseEther("100000"); // 100,000 tokens
  const celoAmount = hre.ethers.parseEther("1"); // 1 CELO (increased for testing)

  // Approve Ubeswap
  await token.approve(UBESWAP_ROUTER, liquidityAmount);
  console.log("Approved Ubeswap for tokens");

  // Add liquidity
  const UbeswapRouter = await hre.ethers.getContractAt("IUbeswapRouter", UBESWAP_ROUTER, deployer);
  try {
    const tx = await UbeswapRouter.addLiquidityETH(
      token.target,
      liquidityAmount,
      0, // Min token amount
      0, // Min CELO amount
      "0x000000000000000000000000000000000000dEaD",
      Math.floor(Date.now() / 1000) + 300,
      { value: celoAmount, gasLimit: 7000000 }
    );
    const receipt = await tx.wait();
    console.log("Liquidity added, tx hash:", receipt.hash);
  } catch (error) {
    console.error("Ubeswap error:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });