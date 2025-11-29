import { expect } from "chai";
import hre from "hardhat";
const { ethers } = hre;

/**
 * System Integration Tests
 * 
 * These tests verify the complete end-to-end workflow of the Decentralized Treasury system,
 * testing the integration between GovernanceToken and DecentralizedTreasury contracts.
 * 
 * Test scenarios include:
 * - Complete DAO lifecycle from token distribution to proposal execution
 * - Multi-user governance scenarios
 * - Complex voting patterns
 * - Treasury fund management flows
 * - Edge cases in integrated system behavior
 */
describe("System Integration Tests - Complete DAO Workflow", function () {
  let governanceToken;
  let treasury;
  let deployer, member1, member2, member3, member4, recipient1, recipient2;

  const INITIAL_SUPPLY = ethers.parseEther("100000");
  const TREASURY_FUNDING = ethers.parseEther("100");

  beforeEach(async function () {
    [deployer, member1, member2, member3, member4, recipient1, recipient2] =
      await ethers.getSigners();

    // Deploy GovernanceToken
    const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
    governanceToken = await GovernanceToken.deploy(
      "DAO Governance Token",
      "DAOGOV",
      INITIAL_SUPPLY
    );

    // Deploy Treasury
    const Treasury = await ethers.getContractFactory("DecentralizedTreasury");
    treasury = await Treasury.deploy(await governanceToken.getAddress());

    // Distribute governance tokens to DAO members
    // Total: 100,000 tokens
    // Deployer keeps: 40,000 (40%)
    // Member1: 25,000 (25%)
    // Member2: 20,000 (20%)
    // Member3: 10,000 (10%)
    // Member4: 5,000 (5%)
    await governanceToken.transfer(member1.address, ethers.parseEther("25000"));
    await governanceToken.transfer(member2.address, ethers.parseEther("20000"));
    await governanceToken.transfer(member3.address, ethers.parseEther("10000"));
    await governanceToken.transfer(member4.address, ethers.parseEther("5000"));

    // Fund the treasury
    await treasury.deposit({ value: TREASURY_FUNDING });
  });

  describe("Complete DAO Lifecycle - Happy Path", function () {
    it("Should execute full workflow: deploy -> fund -> propose -> vote -> execute", async function () {
      // 1. Verify initial state
      expect(await treasury.getTreasuryBalance()).to.equal(TREASURY_FUNDING);
      expect(await treasury.proposalCount()).to.equal(0);

      // 2. Member1 creates a proposal
      const proposalAmount = ethers.parseEther("10");
      const description = "Fund community event";
      
      await expect(
        treasury
          .connect(member1)
          .createProposal(recipient1.address, proposalAmount, description)
      )
        .to.emit(treasury, "ProposalCreated")
        .withArgs(1, member1.address, recipient1.address, proposalAmount, description);

      // 3. Verify proposal created correctly
      const proposal = await treasury.getProposal(1);
      expect(proposal.state).to.equal(1); // Active
      expect(proposal.votesFor).to.equal(0);
      expect(proposal.votesAgainst).to.equal(0);

      // 4. Members vote on the proposal
      // Member1 (25%) votes for
      await expect(treasury.connect(member1).vote(1, true))
        .to.emit(treasury, "VoteCast")
        .withArgs(1, member1.address, true, ethers.parseEther("25000"));

      // Member2 (20%) votes for
      await expect(treasury.connect(member2).vote(1, true))
        .to.emit(treasury, "VoteCast")
        .withArgs(1, member2.address, true, ethers.parseEther("20000"));

      // Member3 (10%) votes for - Total now 55% FOR
      await treasury.connect(member3).vote(1, true);

      // 5. Verify votes recorded
      const proposalAfterVoting = await treasury.getProposal(1);
      expect(proposalAfterVoting.votesFor).to.equal(ethers.parseEther("55000"));
      expect(proposalAfterVoting.votesAgainst).to.equal(0);

      // 6. Fast forward past voting period
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // 7. Execute proposal
      const recipientBalanceBefore = await ethers.provider.getBalance(
        recipient1.address
      );

      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalExecuted")
        .withArgs(1, recipient1.address, proposalAmount);

      // 8. Verify execution results
      const recipientBalanceAfter = await ethers.provider.getBalance(
        recipient1.address
      );
      expect(recipientBalanceAfter - recipientBalanceBefore).to.equal(
        proposalAmount
      );

      const treasuryBalance = await treasury.getTreasuryBalance();
      expect(treasuryBalance).to.equal(TREASURY_FUNDING - proposalAmount);

      const finalProposal = await treasury.getProposal(1);
      expect(finalProposal.state).to.equal(2); // Executed
    });
  });

  describe("Multiple Proposals Workflow", function () {
    it("Should handle multiple concurrent proposals", async function () {
      // Create three proposals
      const proposal1Amount = ethers.parseEther("5");
      const proposal2Amount = ethers.parseEther("10");
      const proposal3Amount = ethers.parseEther("15");

      await treasury
        .connect(member1)
        .createProposal(recipient1.address, proposal1Amount, "Proposal 1");
      
      await treasury
        .connect(member2)
        .createProposal(recipient2.address, proposal2Amount, "Proposal 2");
      
      await treasury
        .connect(member3)
        .createProposal(recipient1.address, proposal3Amount, "Proposal 3");

      expect(await treasury.proposalCount()).to.equal(3);

      // Vote on all proposals differently
      // Proposal 1: Pass (Member1 + Member2 + Member3 = 55%)
      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(member3).vote(1, true);

      // Proposal 2: Fail (only Member4 = 5%)
      await treasury.connect(member4).vote(2, true);

      // Proposal 3: Pass (Member1 + Member2 = 45% + Deployer 40% = 85%)
      await treasury.connect(member1).vote(3, true);
      await treasury.connect(member2).vote(3, true);
      await treasury.connect(deployer).vote(3, true);

      // Fast forward
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Execute proposal 1 - should pass
      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalExecuted");

      // Execute proposal 2 - should be rejected
      await expect(treasury.executeProposal(2))
        .to.emit(treasury, "ProposalRejected");

      // Execute proposal 3 - should pass
      await expect(treasury.executeProposal(3))
        .to.emit(treasury, "ProposalExecuted");

      // Verify final states
      const p1 = await treasury.getProposal(1);
      const p2 = await treasury.getProposal(2);
      const p3 = await treasury.getProposal(3);

      expect(p1.state).to.equal(2); // Executed
      expect(p2.state).to.equal(3); // Rejected
      expect(p3.state).to.equal(2); // Executed
    });

    it("Should handle sequential proposal execution", async function () {
      // Create proposals that will be executed one after another
      const amount = ethers.parseEther("20");
      
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "First");

      // Vote and execute first proposal
      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(member3).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(1);

      // Create second proposal after first is executed
      await treasury
        .connect(member2)
        .createProposal(recipient2.address, amount, "Second");

      // Vote on second
      await treasury.connect(member1).vote(2, true);
      await treasury.connect(member2).vote(2, true);
      await treasury.connect(deployer).vote(2, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(2);

      // Verify both executed
      expect((await treasury.getProposal(1)).state).to.equal(2);
      expect((await treasury.getProposal(2)).state).to.equal(2);
      
      // Verify treasury balance decreased correctly
      expect(await treasury.getTreasuryBalance()).to.equal(
        TREASURY_FUNDING - amount * 2n
      );
    });
  });

  describe("Governance Power Dynamics", function () {
    it("Should respect majority voting power (>50% required)", async function () {
      const amount = ethers.parseEther("5");
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "Majority test");

      // Exactly 50% should fail
      // Member1 (25%) + Member2 (20%) + Member4 (5%) = 50%
      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(member4).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalRejected");

      expect((await treasury.getProposal(1)).state).to.equal(3); // Rejected
    });

    it("Should allow minority holder to create but not pass proposals", async function () {
      const amount = ethers.parseEther("5");
      
      // Member4 (5%) creates proposal
      await treasury
        .connect(member4)
        .createProposal(recipient1.address, amount, "Minority proposal");

      // Only member4 votes
      await treasury.connect(member4).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Should be rejected (5% < 50%)
      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalRejected");
    });

    it("Should handle token transfers between proposal and vote", async function () {
      const amount = ethers.parseEther("5");
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "Transfer test");

      // Member1 transfers some tokens to member4
      await governanceToken
        .connect(member1)
        .transfer(member4.address, ethers.parseEther("10000"));

      // Member1 still votes with remaining balance
      await treasury.connect(member1).vote(1, true);

      // Verify vote weight is based on balance at vote time
      const voteWeight = await treasury.getVoterWeight(1, member1.address);
      expect(voteWeight).to.equal(ethers.parseEther("15000")); // 25000 - 10000
    });
  });

  describe("Treasury Fund Management", function () {
    it("Should allow multiple deposits and track balance correctly", async function () {
      const initialBalance = await treasury.getTreasuryBalance();

      await treasury.connect(member1).deposit({ value: ethers.parseEther("10") });
      await treasury.connect(member2).deposit({ value: ethers.parseEther("20") });
      
      const newBalance = await treasury.getTreasuryBalance();
      expect(newBalance).to.equal(
        initialBalance + ethers.parseEther("30")
      );
    });

    it("Should prevent execution if treasury funds depleted", async function () {
      // Create two proposals for most of the treasury
      const largeAmount = ethers.parseEther("60");
      
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, largeAmount, "Large 1");
      
      await treasury
        .connect(member2)
        .createProposal(recipient2.address, largeAmount, "Large 2");

      // Vote to pass both
      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(deployer).vote(1, true);

      await treasury.connect(member1).vote(2, true);
      await treasury.connect(member2).vote(2, true);
      await treasury.connect(deployer).vote(2, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Execute first - should succeed
      await treasury.executeProposal(1);

      // Execute second - should fail (insufficient funds)
      await expect(
        treasury.executeProposal(2)
      ).to.be.revertedWith("Insufficient treasury balance");
    });

    it("Should handle receiving ETH via receive function", async function () {
      const sendAmount = ethers.parseEther("25");
      const initialBalance = await treasury.getTreasuryBalance();

      await expect(
        member1.sendTransaction({
          to: await treasury.getAddress(),
          value: sendAmount,
        })
      )
        .to.emit(treasury, "FundsDeposited")
        .withArgs(member1.address, sendAmount);

      expect(await treasury.getTreasuryBalance()).to.equal(
        initialBalance + sendAmount
      );
    });
  });

  describe("Complex Voting Scenarios", function () {
    it("Should handle split voting (for and against)", async function () {
      const amount = ethers.parseEther("5");
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "Split vote");

      // 45% for, 25% against
      await treasury.connect(member1).vote(1, true); // 25% for
      await treasury.connect(member2).vote(1, true); // 20% for
      await treasury.connect(member3).vote(1, false); // 10% against
      await treasury.connect(member4).vote(1, false); // 5% against
      // Deployer doesn't vote (40% abstain)

      const proposal = await treasury.getProposal(1);
      expect(proposal.votesFor).to.equal(ethers.parseEther("45000"));
      expect(proposal.votesAgainst).to.equal(ethers.parseEther("15000"));

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // 45% for out of 100% total supply = fails (needs >50% of total)
      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalRejected");
    });

    it("Should handle all members voting", async function () {
      const amount = ethers.parseEther("5");
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "Full participation");

      // Everyone votes for (100% participation)
      await treasury.connect(deployer).vote(1, true); // 40%
      await treasury.connect(member1).vote(1, true); // 25%
      await treasury.connect(member2).vote(1, true); // 20%
      await treasury.connect(member3).vote(1, true); // 10%
      await treasury.connect(member4).vote(1, true); // 5%

      const proposal = await treasury.getProposal(1);
      expect(proposal.votesFor).to.equal(INITIAL_SUPPLY);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalExecuted");
    });

    it("Should handle minimal passing threshold (just over 50%)", async function () {
      const amount = ethers.parseEther("5");
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "Minimal pass");

      // Get just over 50%: Deployer (40%) + Member1 (25%) = 65%
      await treasury.connect(deployer).vote(1, true);
      await treasury.connect(member1).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalExecuted");
    });
  });

  describe("Token Minting Integration", function () {
    it("Should allow minting new tokens and using them for voting", async function () {
      // Mint new tokens to a new member
      const newMember = member4;
      const mintAmount = ethers.parseEther("50000");
      
      await governanceToken.mint(newMember.address, mintAmount);

      // New member creates and votes on proposal
      const amount = ethers.parseEther("5");
      await treasury
        .connect(newMember)
        .createProposal(recipient1.address, amount, "New member proposal");

      // New member now has 55,000 tokens (5,000 original + 50,000 minted)
      // Total supply now 150,000
      // 55,000 / 150,000 = 36.67% (not enough to pass alone)
      await treasury.connect(newMember).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Should be rejected (36.67% < 50%)
      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalRejected");
    });
  });

  describe("Voting Period Configuration", function () {
    it("Should work with custom voting periods", async function () {
      // Set shorter voting period
      const shortPeriod = 60 * 60; // 1 hour
      await treasury.setVotingPeriod(shortPeriod);

      const amount = ethers.parseEther("5");
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "Short period");

      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(deployer).vote(1, true);

      // Fast forward 1 hour
      await ethers.provider.send("evm_increaseTime", [shortPeriod + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(1))
        .to.emit(treasury, "ProposalExecuted");
    });

    it("Should prevent execution before custom period ends", async function () {
      const longPeriod = 7 * 24 * 60 * 60; // 7 days
      await treasury.setVotingPeriod(longPeriod);

      const amount = ethers.parseEther("5");
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, amount, "Long period");

      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(deployer).vote(1, true);

      // Try to execute after 3 days (not long enough)
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      await expect(
        treasury.executeProposal(1)
      ).to.be.revertedWith("Voting period not ended");
    });
  });

  describe("Edge Cases and Stress Tests", function () {
    it("Should handle very small proposal amounts", async function () {
      const tinyAmount = 1; // 1 wei
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, tinyAmount, "Tiny amount");

      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(deployer).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      const recipientBalanceBefore = await ethers.provider.getBalance(
        recipient1.address
      );

      await treasury.executeProposal(1);

      const recipientBalanceAfter = await ethers.provider.getBalance(
        recipient1.address
      );
      expect(recipientBalanceAfter - recipientBalanceBefore).to.equal(BigInt(tinyAmount));
    });

    it("Should handle proposals for entire treasury balance", async function () {
      const treasuryBalance = await treasury.getTreasuryBalance();
      
      await treasury
        .connect(member1)
        .createProposal(recipient1.address, treasuryBalance, "Entire balance");

      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(deployer).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(1);

      expect(await treasury.getTreasuryBalance()).to.equal(0);
    });

    it("Should maintain state consistency across many proposals", async function () {
      // Create 10 proposals
      for (let i = 0; i < 10; i++) {
        await treasury
          .connect(member1)
          .createProposal(
            recipient1.address,
            ethers.parseEther("1"),
            `Proposal ${i + 1}`
          );
      }

      expect(await treasury.proposalCount()).to.equal(10);

      // Verify all proposals are in Active state
      for (let i = 1; i <= 10; i++) {
        const proposal = await treasury.getProposal(i);
        expect(proposal.state).to.equal(1); // Active
        expect(proposal.id).to.equal(i);
      }
    });
  });

  describe("Real-world Scenario: Complete DAO Operation", function () {
    it("Should simulate a complete DAO quarterly cycle", async function () {
      console.log("Starting quarterly DAO operation simulation...");

      // Quarter 1: Initial funding and setup
      console.log("Q1: Community members fund the treasury");
      await treasury.connect(member1).deposit({ value: ethers.parseEther("50") });
      await treasury.connect(member2).deposit({ value: ethers.parseEther("30") });
      
      let treasuryBalance = await treasury.getTreasuryBalance();
      console.log(`Treasury balance: ${ethers.formatEther(treasuryBalance)} ETH`);

      // Proposal 1: Marketing budget
      console.log("\nProposal 1: Marketing budget");
      await treasury
        .connect(member1)
        .createProposal(
          recipient1.address,
          ethers.parseEther("20"),
          "Q1 Marketing campaign"
        );

      await treasury.connect(member1).vote(1, true);
      await treasury.connect(member2).vote(1, true);
      await treasury.connect(deployer).vote(1, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(1);
      console.log("Marketing proposal executed");

      // Proposal 2: Development grant
      console.log("\nProposal 2: Development grant");
      await treasury
        .connect(member2)
        .createProposal(
          recipient2.address,
          ethers.parseEther("40"),
          "Developer grant"
        );

      await treasury.connect(member1).vote(2, true);
      await treasury.connect(member2).vote(2, true);
      await treasury.connect(member3).vote(2, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(2);
      console.log("Development grant executed");

      // Proposal 3: Community event (rejected)
      console.log("\nProposal 3: Community event (expected to be rejected)");
      await treasury
        .connect(member3)
        .createProposal(
          recipient1.address,
          ethers.parseEther("30"),
          "Community event"
        );

      await treasury.connect(member4).vote(3, true); // Only 5% votes

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(3);
      console.log("Community event proposal rejected");

      // Final state
      treasuryBalance = await treasury.getTreasuryBalance();
      console.log(`\nFinal treasury balance: ${ethers.formatEther(treasuryBalance)} ETH`);
      console.log(`Total proposals: ${await treasury.proposalCount()}`);

      // Verify final state
      expect(await treasury.proposalCount()).to.equal(3);
      expect((await treasury.getProposal(1)).state).to.equal(2); // Executed
      expect((await treasury.getProposal(2)).state).to.equal(2); // Executed
      expect((await treasury.getProposal(3)).state).to.equal(3); // Rejected

      console.log("\nQuarterly cycle simulation completed successfully!");
    });
  });
});
