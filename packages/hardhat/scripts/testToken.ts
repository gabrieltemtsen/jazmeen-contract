import * as dotenv from "dotenv";
dotenv.config();
const hre = require("hardhat");

const UBESWAP_ROUTER = "0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121";
const UBESWAP_FACTORY = "0x62d5b84bE28a183aBB507E125eF99330F7C443e";
const CELO_ADDRESS = "0x471EcE3750Da237f93B8E339c536989b8978a438"; // Wrapped CELO

const UBESWAP_ROUTER_ABI = [
  "function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity)",
];
const UBESWAP_FACTORY_ABI = [
  "function getPair(address tokenA, address tokenB) external view returns (address pair)",
  "function createPair(address tokenA, address tokenB) external returns (address pair)",
];

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Launching memecoin with account:", deployer.address);

  // Check CELO balance
  const celoBalance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Deployer CELO balance:", hre.ethers.formatEther(celoBalance));

  // Deploy token
  const JazmeenToken = await hre.ethers.getContractFactory("JazmeenToken");
  const token = await JazmeenToken.deploy(
    "GabedevCoin101",
    "GABDEV101",
    1_000_000,
    "https://example.com/image.jpg",
    deployer.address,
    { gasLimit: 7000000 }
  );
  await token.waitForDeployment();
  console.log("Token deployed at:", token.target);

  // Check token balance
  const totalSupply = hre.ethers.parseEther("1000000");
  const liquidityAmount = hre.ethers.parseEther("100000"); // 10% of supply
  const celoAmount = hre.ethers.parseEther("2"); // 2 CELO
  const excess = totalSupply - liquidityAmount;

  console.log("Deployer token balance:", hre.ethers.formatEther(await token.balanceOf(deployer.address)));

  // Burn excess
  await token.transfer("0x000000000000000000000000000000000000dEaD", excess, { gasLimit: 1000000 });
  console.log("Excess burned");

  // Setup Ubeswap
  const UbeswapRouter = new hre.ethers.Contract(UBESWAP_ROUTER, UBESWAP_ROUTER_ABI, deployer);
  const UbeswapFactory = new hre.ethers.Contract(UBESWAP_FACTORY, UBESWAP_FACTORY_ABI, deployer);

  // Create pair manually
  try {
    const pairTx = await UbeswapFactory.createPair(token.target, CELO_ADDRESS, { gasLimit: 7000000 });
    const pairReceipt = await pairTx.wait();
    console.log("Pair created, tx hash:", pairReceipt.hash);
  } catch (error) {
    console.error("Pair creation error:", error);
    throw error;
  }
  const pairAddress = await UbeswapFactory.getPair(token.target, CELO_ADDRESS);
  console.log("Pair address:", pairAddress);

  // Approve tokens
  await token.approve(UBESWAP_ROUTER, liquidityAmount, { gasLimit: 1000000 });
  console.log("Approved Ubeswap for tokens:", hre.ethers.formatEther(await token.allowance(deployer.address, UBESWAP_ROUTER)));

  // Add liquidity
  try {
    const deadline = Math.floor(Date.now() / 1000) + 600; // 10 minutes
    const tx = await UbeswapRouter.addLiquidityETH(
      token.target,
      liquidityAmount,
      0, // Min token amount
      0, // Min CELO amount
      "0x000000000000000000000000000000000000dEaD",
      deadline,
      { value: celoAmount, gasLimit: 7000000 }
    );
    const receipt = await tx.wait();
    console.log("Liquidity added, tx hash:", receipt.hash);
  } catch (error) {
    console.error("Ubeswap error:", error);
    if (error.data) {
      try {
        const decoded = hre.ethers.AbiCoder.defaultAbiCoder().decode(["string"], "0x" + error.data.slice(10));
        console.error("Revert reason:", decoded);
      } catch (decodeError) {
        console.error("Could not decode revert reason:", error.data);
      }
    }
    throw error;
  }

  // Verify pair
  console.log("Pair address after liquidity:", await UbeswapFactory.getPair(token.target, CELO_ADDRESS));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error launching memecoin:", error);
    process.exit(1);
  });