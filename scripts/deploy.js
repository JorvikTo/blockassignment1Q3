import hre from "hardhat";
const { ethers } = hre;

async function main() {
  console.log("Deploying Decentralized Treasury Management System...\n");

  // Get deployer
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log(
    "Account balance:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "ETH\n"
  );

  // Deploy GovernanceToken
  console.log("Deploying GovernanceToken...");
  const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
  const initialSupply = ethers.parseEther("1000000"); // 1 million tokens
  const governanceToken = await GovernanceToken.deploy(
    "Treasury Governance Token",
    "TGT",
    initialSupply
  );
  await governanceToken.waitForDeployment();
  const tokenAddress = await governanceToken.getAddress();
  console.log("GovernanceToken deployed to:", tokenAddress);

  // Deploy DecentralizedTreasury
  console.log("\nDeploying DecentralizedTreasury...");
  const Treasury = await ethers.getContractFactory("DecentralizedTreasury");
  const treasury = await Treasury.deploy(tokenAddress);
  await treasury.waitForDeployment();
  const treasuryAddress = await treasury.getAddress();
  console.log("DecentralizedTreasury deployed to:", treasuryAddress);

  // Display deployment summary
  console.log("\n=== Deployment Summary ===");
  console.log("GovernanceToken:", tokenAddress);
  console.log("DecentralizedTreasury:", treasuryAddress);
  console.log("Initial Token Supply:", ethers.formatEther(initialSupply), "TGT");
  console.log("\nVoting Parameters:");
  console.log("- Voting Period:", (await treasury.votingPeriod()) / 86400n, "days");
  console.log("- Quorum Percentage:", (await treasury.quorumPercentage()).toString(), "%");
  console.log("- Majority Percentage:", (await treasury.majorityPercentage()).toString(), "%");
  console.log("\n✅ Deployment completed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
