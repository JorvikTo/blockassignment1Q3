import hre from "hardhat";
const { ethers } = hre;

/**
 * Example usage of the Decentralized Treasury Management System
 * This script demonstrates a complete workflow:
 * 1. Deploy contracts
 * 2. Distribute governance tokens
 * 3. Fund the treasury
 * 4. Create a proposal
 * 5. Vote on the proposal
 * 6. Execute the proposal
 */
async function main() {
  console.log("=== Decentralized Treasury Example Usage ===\n");

  // Get signers (simulating different members)
  const [deployer, member1, member2, member3, recipient] = await ethers.getSigners();
  
  console.log("Participants:");
  console.log("- Deployer:", deployer.address);
  console.log("- Member 1:", member1.address);
  console.log("- Member 2:", member2.address);
  console.log("- Member 3:", member3.address);
  console.log("- Recipient:", recipient.address);
  console.log();

  // Step 1: Deploy GovernanceToken
  console.log("Step 1: Deploying GovernanceToken...");
  const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
  const initialSupply = ethers.parseEther("10000");
  const governanceToken = await GovernanceToken.deploy(
    "Treasury Governance Token",
    "TGT",
    initialSupply
  );
  await governanceToken.waitForDeployment();
  console.log("✓ GovernanceToken deployed at:", await governanceToken.getAddress());
  console.log("  Initial Supply:", ethers.formatEther(initialSupply), "TGT\n");

  // Step 2: Deploy DecentralizedTreasury
  console.log("Step 2: Deploying DecentralizedTreasury...");
  const Treasury = await ethers.getContractFactory("DecentralizedTreasury");
  const treasury = await Treasury.deploy(await governanceToken.getAddress());
  await treasury.waitForDeployment();
  console.log("✓ DecentralizedTreasury deployed at:", await treasury.getAddress());
  console.log();

  // Step 3: Distribute governance tokens
  console.log("Step 3: Distributing governance tokens...");
  await governanceToken.transfer(member1.address, ethers.parseEther("3000"));
  await governanceToken.transfer(member2.address, ethers.parseEther("2500"));
  await governanceToken.transfer(member3.address, ethers.parseEther("1500"));
  
  console.log("✓ Token distribution:");
  console.log("  - Deployer:", ethers.formatEther(await governanceToken.balanceOf(deployer.address)), "TGT");
  console.log("  - Member 1:", ethers.formatEther(await governanceToken.balanceOf(member1.address)), "TGT");
  console.log("  - Member 2:", ethers.formatEther(await governanceToken.balanceOf(member2.address)), "TGT");
  console.log("  - Member 3:", ethers.formatEther(await governanceToken.balanceOf(member3.address)), "TGT");
  console.log();

  // Step 4: Fund the treasury
  console.log("Step 4: Funding the treasury...");
  const treasuryFunding = ethers.parseEther("10");
  await treasury.deposit({ value: treasuryFunding });
  console.log("✓ Treasury funded with:", ethers.formatEther(treasuryFunding), "ETH");
  console.log("  Treasury balance:", ethers.formatEther(await treasury.getTreasuryBalance()), "ETH");
  console.log();

  // Step 5: Create a proposal
  console.log("Step 5: Creating a proposal...");
  const proposalAmount = ethers.parseEther("2");
  const proposalDescription = "Fund development team for Q1 2025";
  
  const tx = await treasury.connect(member1).createProposal(
    recipient.address,
    proposalAmount,
    proposalDescription
  );
  const receipt = await tx.wait();
  
  // Get proposal ID from event
  const proposalCreatedEvent = receipt.logs.find(
    log => log.fragment && log.fragment.name === "ProposalCreated"
  );
  const proposalId = proposalCreatedEvent.args[0];
  
  console.log("✓ Proposal created:");
  console.log("  - ID:", proposalId.toString());
  console.log("  - Amount:", ethers.formatEther(proposalAmount), "ETH");
  console.log("  - Recipient:", recipient.address);
  console.log("  - Description:", proposalDescription);
  console.log();

  // Step 6: Vote on the proposal
  console.log("Step 6: Voting on the proposal...");
  
  // Member 1 votes FOR (3000 tokens)
  await treasury.connect(member1).vote(proposalId, true);
  console.log("✓ Member 1 voted FOR with 3000 TGT");
  
  // Member 2 votes FOR (2500 tokens)
  await treasury.connect(member2).vote(proposalId, true);
  console.log("✓ Member 2 voted FOR with 2500 TGT");
  
  // Member 3 votes AGAINST (1500 tokens)
  await treasury.connect(member3).vote(proposalId, false);
  console.log("✓ Member 3 voted AGAINST with 1500 TGT");
  
  // Get current proposal state
  const proposal = await treasury.getProposal(proposalId);
  console.log("\n  Vote tally:");
  console.log("  - Votes FOR:", ethers.formatEther(proposal.votesFor), "TGT");
  console.log("  - Votes AGAINST:", ethers.formatEther(proposal.votesAgainst), "TGT");
  console.log("  - Total votes:", ethers.formatEther(proposal.votesFor + proposal.votesAgainst), "TGT");
  console.log();

  // Step 7: Fast forward time to end voting period
  console.log("Step 7: Waiting for voting period to end...");
  const votingPeriod = await treasury.votingPeriod();
  console.log("  (Fast-forwarding", Number(votingPeriod) / 86400, "days in simulation)");
  await ethers.provider.send("evm_increaseTime", [Number(votingPeriod) + 1]);
  await ethers.provider.send("evm_mine");
  console.log("✓ Voting period ended");
  console.log();

  // Step 8: Execute the proposal
  console.log("Step 8: Executing the proposal...");
  const recipientBalanceBefore = await ethers.provider.getBalance(recipient.address);
  
  await treasury.executeProposal(proposalId);
  
  const recipientBalanceAfter = await ethers.provider.getBalance(recipient.address);
  const received = recipientBalanceAfter - recipientBalanceBefore;
  
  console.log("✓ Proposal executed successfully!");
  console.log("  - Funds transferred:", ethers.formatEther(received), "ETH");
  console.log("  - Recipient new balance:", ethers.formatEther(recipientBalanceAfter), "ETH");
  console.log();

  // Final state
  console.log("=== Final State ===");
  const finalProposal = await treasury.getProposal(proposalId);
  console.log("Proposal state:", finalProposal.state === 2n ? "✓ Executed" : "✗ Not Executed");
  console.log("Treasury balance:", ethers.formatEther(await treasury.getTreasuryBalance()), "ETH");
  console.log();

  // Summary
  console.log("=== Summary ===");
  console.log("✓ Token-weighted voting worked correctly");
  console.log("  - Total supply: 10,000 TGT");
  console.log("  - Votes cast: 7,000 TGT (70% - exceeds 50% quorum)");
  console.log("  - Votes FOR: 5,500 TGT (78.6% - exceeds 51% majority)");
  console.log("✓ Proposal executed automatically");
  console.log("✓ Funds transferred to recipient");
  console.log("✓ Decentralized governance successful!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
