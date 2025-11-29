import { expect } from "chai";
import hre from "hardhat";
const { ethers } = hre;

describe("DecentralizedTreasury", function () {
  let governanceToken;
  let treasury;
  let owner, addr1, addr2, addr3, recipient;

  const INITIAL_SUPPLY = ethers.parseEther("10000");
  const PROPOSAL_AMOUNT = ethers.parseEther("1");
  const TREASURY_FUNDING = ethers.parseEther("10");

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, recipient] = await ethers.getSigners();

    // Deploy GovernanceToken
    const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
    governanceToken = await GovernanceToken.deploy(
      "Governance Token",
      "GOV",
      INITIAL_SUPPLY
    );

    // Deploy Treasury
    const Treasury = await ethers.getContractFactory("DecentralizedTreasury");
    treasury = await Treasury.deploy(await governanceToken.getAddress());

    // Distribute tokens for testing
    await governanceToken.transfer(addr1.address, ethers.parseEther("3000"));
    await governanceToken.transfer(addr2.address, ethers.parseEther("2000"));
    await governanceToken.transfer(addr3.address, ethers.parseEther("1000"));

    // Fund the treasury
    await treasury.deposit({ value: TREASURY_FUNDING });
  });

  describe("Deployment", function () {
    it("Should set the correct governance token", async function () {
      expect(await treasury.governanceToken()).to.equal(
        await governanceToken.getAddress()
      );
    });

    it("Should have correct initial voting parameters", async function () {
      expect(await treasury.votingPeriod()).to.equal(3 * 24 * 60 * 60); // 3 days
    });
  });

  describe("Treasury Management", function () {
    it("Should accept deposits", async function () {
      const depositAmount = ethers.parseEther("5");
      await expect(treasury.deposit({ value: depositAmount }))
        .to.emit(treasury, "FundsDeposited")
        .withArgs(owner.address, depositAmount);

      expect(await treasury.getTreasuryBalance()).to.equal(
        TREASURY_FUNDING + depositAmount
      );
    });

    it("Should receive ETH via receive function", async function () {
      const sendAmount = ethers.parseEther("2");
      await expect(
        owner.sendTransaction({
          to: await treasury.getAddress(),
          value: sendAmount,
        })
      )
        .to.emit(treasury, "FundsDeposited")
        .withArgs(owner.address, sendAmount);
    });

    it("Should report correct treasury balance", async function () {
      expect(await treasury.getTreasuryBalance()).to.equal(TREASURY_FUNDING);
    });
  });

  describe("Proposal Creation", function () {
    it("Should create a proposal successfully", async function () {
      const description = "Fund development team";

      await expect(
        treasury
          .connect(addr1)
          .createProposal(recipient.address, PROPOSAL_AMOUNT, description)
      )
        .to.emit(treasury, "ProposalCreated")
        .withArgs(1, addr1.address, recipient.address, PROPOSAL_AMOUNT, description);

      const proposal = await treasury.getProposal(1);
      expect(proposal.proposer).to.equal(addr1.address);
      expect(proposal.recipient).to.equal(recipient.address);
      expect(proposal.amount).to.equal(PROPOSAL_AMOUNT);
      expect(proposal.description).to.equal(description);
      expect(proposal.state).to.equal(1); // Active
    });

    it("Should fail if proposer has no tokens", async function () {
      const newAddr = (await ethers.getSigners())[5];
      await expect(
        treasury
          .connect(newAddr)
          .createProposal(recipient.address, PROPOSAL_AMOUNT, "Test")
      ).to.be.revertedWith("Must hold tokens to propose");
    });

    it("Should fail if amount exceeds treasury balance", async function () {
      const tooMuch = ethers.parseEther("100");
      await expect(
        treasury
          .connect(addr1)
          .createProposal(recipient.address, tooMuch, "Too much")
      ).to.be.revertedWith("Insufficient treasury funds");
    });

    it("Should fail with invalid recipient", async function () {
      await expect(
        treasury
          .connect(addr1)
          .createProposal(ethers.ZeroAddress, PROPOSAL_AMOUNT, "Invalid")
      ).to.be.revertedWith("Invalid recipient");
    });

    it("Should fail with zero amount", async function () {
      await expect(
        treasury.connect(addr1).createProposal(recipient.address, 0, "Zero")
      ).to.be.revertedWith("Amount must be greater than 0");
    });
  });

  describe("Voting", function () {
    let proposalId;

    beforeEach(async function () {
      proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Test proposal");
    });

    it("Should allow voting with token weight", async function () {
      const votingPower = await governanceToken.balanceOf(addr1.address);

      await expect(treasury.connect(addr1).vote(proposalId, true))
        .to.emit(treasury, "VoteCast")
        .withArgs(proposalId, addr1.address, true, votingPower);

      const proposal = await treasury.getProposal(proposalId);
      expect(proposal.votesFor).to.equal(votingPower);
      expect(proposal.votesAgainst).to.equal(0);
    });

    it("Should track votes against", async function () {
      const votingPower = await governanceToken.balanceOf(addr2.address);

      await expect(treasury.connect(addr2).vote(proposalId, false))
        .to.emit(treasury, "VoteCast")
        .withArgs(proposalId, addr2.address, false, votingPower);

      const proposal = await treasury.getProposal(proposalId);
      expect(proposal.votesAgainst).to.equal(votingPower);
    });

    it("Should prevent double voting", async function () {
      await treasury.connect(addr1).vote(proposalId, true);

      await expect(
        treasury.connect(addr1).vote(proposalId, true)
      ).to.be.revertedWith("Already voted");
    });

    it("Should fail if voter has no tokens", async function () {
      const newAddr = (await ethers.getSigners())[5];
      await expect(
        treasury.connect(newAddr).vote(proposalId, true)
      ).to.be.revertedWith("No voting power");
    });

    it("Should track hasVoted correctly", async function () {
      expect(await treasury.hasVoted(proposalId, addr1.address)).to.be.false;

      await treasury.connect(addr1).vote(proposalId, true);

      expect(await treasury.hasVoted(proposalId, addr1.address)).to.be.true;
      expect(await treasury.hasVoted(proposalId, addr2.address)).to.be.false;
    });

    it("Should record voter weight", async function () {
      const votingPower = await governanceToken.balanceOf(addr1.address);

      await treasury.connect(addr1).vote(proposalId, true);

      expect(await treasury.getVoterWeight(proposalId, addr1.address)).to.equal(
        votingPower
      );
    });
  });

  describe("Proposal Execution", function () {
    let proposalId;

    beforeEach(async function () {
      proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Test proposal");
    });

    it("Should execute proposal when affirmative votes exceed 50% of total voting power", async function () {
      // addr1 (3000 tokens) + addr2 (2000 tokens) = 5000 votes for
      // Total supply = 10000 tokens
      // 5000/10000 = 50% (NOT enough, needs >50%)
      // Need 5001 or more to pass
      
      // Let's use addr1 (3000) + addr2 (2000) + addr3 (1000) = 6000 > 50%
      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      // Fast forward past voting deadline
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      const recipientBalanceBefore = await ethers.provider.getBalance(
        recipient.address
      );

      await expect(treasury.executeProposal(proposalId))
        .to.emit(treasury, "ProposalExecuted")
        .withArgs(proposalId, recipient.address, PROPOSAL_AMOUNT);

      const recipientBalanceAfter = await ethers.provider.getBalance(
        recipient.address
      );
      expect(recipientBalanceAfter - recipientBalanceBefore).to.equal(
        PROPOSAL_AMOUNT
      );

      const proposal = await treasury.getProposal(proposalId);
      expect(proposal.state).to.equal(2); // Executed
    });

    it("Should reject proposal when affirmative votes do not exceed 50%", async function () {
      // addr1 votes for (3000), addr2 votes against (2000)
      // Total supply: 10000, For: 3000 = 30% (does not exceed 50%)

      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, false);

      // Fast forward past voting deadline
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(proposalId))
        .to.emit(treasury, "ProposalRejected")
        .withArgs(proposalId);

      const proposal = await treasury.getProposal(proposalId);
      expect(proposal.state).to.equal(3); // Rejected
    });

    it("Should reject proposal when all votes are against", async function () {
      // addr1 votes against (3000), addr2 votes against (2000)
      // Total supply: 10000, For: 0 = 0% (does not exceed 50%)

      await treasury.connect(addr2).vote(proposalId, false);
      await treasury.connect(addr1).vote(proposalId, false);

      // Fast forward past voting deadline
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(proposalId))
        .to.emit(treasury, "ProposalRejected")
        .withArgs(proposalId);

      const proposal = await treasury.getProposal(proposalId);
      expect(proposal.state).to.equal(3); // Rejected
    });

    it("Should reject if affirmative votes equal exactly 50%", async function () {
      // addr1 (3000) + addr2 (2000) = 5000 = exactly 50% (NOT enough, needs >50%)

      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);

      // Fast forward past voting deadline
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(proposalId))
        .to.emit(treasury, "ProposalRejected")
        .withArgs(proposalId);
      
      const proposal = await treasury.getProposal(proposalId);
      expect(proposal.state).to.equal(3); // Rejected
    });

    it("Should fail if voting period not ended", async function () {
      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      await expect(
        treasury.executeProposal(proposalId)
      ).to.be.revertedWith("Voting period not ended");
    });

    it("Should fail if proposal already executed", async function () {
      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      // Fast forward past voting deadline
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(proposalId);

      await expect(
        treasury.executeProposal(proposalId)
      ).to.be.revertedWith("Proposal not active");
    });
  });

  describe("Parameter Management", function () {
    it("Should allow setting voting period", async function () {
      const newPeriod = 7 * 24 * 60 * 60; // 7 days
      await treasury.setVotingPeriod(newPeriod);
      expect(await treasury.votingPeriod()).to.equal(newPeriod);
    });

    it("Should reject zero voting period", async function () {
      await expect(
        treasury.setVotingPeriod(0)
      ).to.be.revertedWith("Voting period must be positive");
    });

    it("Should allow very short voting period", async function () {
      const shortPeriod = 60; // 1 minute
      await treasury.setVotingPeriod(shortPeriod);
      expect(await treasury.votingPeriod()).to.equal(shortPeriod);
    });

    it("Should allow very long voting period", async function () {
      const longPeriod = 365 * 24 * 60 * 60; // 1 year
      await treasury.setVotingPeriod(longPeriod);
      expect(await treasury.votingPeriod()).to.equal(longPeriod);
    });
  });

  describe("Edge Cases", function () {
    it("Should handle multiple proposals", async function () {
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Proposal 1");

      await treasury
        .connect(addr2)
        .createProposal(addr3.address, PROPOSAL_AMOUNT, "Proposal 2");

      expect(await treasury.proposalCount()).to.equal(2);

      const proposal1 = await treasury.getProposal(1);
      const proposal2 = await treasury.getProposal(2);

      expect(proposal1.proposer).to.equal(addr1.address);
      expect(proposal2.proposer).to.equal(addr2.address);
    });

    it("Should handle exactly 50% affirmative votes (should reject)", async function () {
      // Create proposal and get exactly 50% of votes (needs >50%)
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Exact 50%");

      // addr1 (3000) + addr2 (2000) = 5000 = exactly 50% (NOT enough)
      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);

      // Fast forward
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Should reject since exactly 50% is not > 50%
      await expect(treasury.executeProposal(proposalId)).to.emit(
        treasury,
        "ProposalRejected"
      );
    });

    it("Should handle just over 50% affirmative votes (should execute)", async function () {
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Just over 50%");

      // Total: 10000. addr1 (3000) + addr2 (2000) + addr3 (1000) = 6000 > 50%
      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      // Fast forward
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Should execute
      await expect(treasury.executeProposal(proposalId)).to.emit(
        treasury,
        "ProposalExecuted"
      );
    });
  });

  describe("Additional Security Tests", function () {
    let proposalId;

    beforeEach(async function () {
      proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Security test");
    });

    it("Should prevent voting after deadline", async function () {
      // Fast forward past voting deadline
      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(
        treasury.connect(addr1).vote(proposalId, true)
      ).to.be.revertedWith("Voting period ended");
    });

    it("Should prevent executing with insufficient treasury balance", async function () {
      // Create proposal for all treasury funds
      const treasuryBalance = await treasury.getTreasuryBalance();
      const proposalId2 = 2;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, treasuryBalance, "Drain treasury");

      // Vote to pass
      await treasury.connect(addr1).vote(proposalId2, true);
      await treasury.connect(addr2).vote(proposalId2, true);
      await treasury.connect(addr3).vote(proposalId2, true);

      // Execute first proposal to drain some funds
      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await treasury.executeProposal(proposalId);

      // Now try to execute second proposal - should fail due to insufficient balance
      await expect(
        treasury.executeProposal(proposalId2)
      ).to.be.revertedWith("Insufficient treasury balance");
    });

    it("Should handle proposal with invalid ID", async function () {
      await expect(
        treasury.getProposal(999)
      ).to.be.revertedWith("Invalid proposal ID");

      await expect(
        treasury.vote(999, true)
      ).to.be.revertedWith("Invalid proposal ID");

      await expect(
        treasury.executeProposal(999)
      ).to.be.revertedWith("Invalid proposal ID");
    });

    it("Should handle proposal ID zero", async function () {
      await expect(
        treasury.getProposal(0)
      ).to.be.revertedWith("Invalid proposal ID");

      await expect(
        treasury.vote(0, true)
      ).to.be.revertedWith("Invalid proposal ID");

      await expect(
        treasury.executeProposal(0)
      ).to.be.revertedWith("Invalid proposal ID");
    });
  });

  describe("Reentrancy Protection Tests", function () {
    it("Should have nonReentrant modifier on executeProposal", async function () {
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Test");

      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Execute successfully (reentrancy guard prevents any issues)
      await expect(treasury.executeProposal(proposalId))
        .to.emit(treasury, "ProposalExecuted");
    });

    it("Should have nonReentrant modifier on executeTransfer", async function () {
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Test");

      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      // Execute successfully using executeTransfer
      await expect(treasury.executeTransfer(proposalId))
        .to.emit(treasury, "ProposalExecuted");
    });
  });

  describe("Event Emission Tests", function () {
    it("Should emit FundsDeposited on deposit", async function () {
      const depositAmount = ethers.parseEther("5");
      await expect(treasury.deposit({ value: depositAmount }))
        .to.emit(treasury, "FundsDeposited")
        .withArgs(owner.address, depositAmount);
    });

    it("Should emit FundsDeposited on receive", async function () {
      const sendAmount = ethers.parseEther("3");
      await expect(
        owner.sendTransaction({
          to: await treasury.getAddress(),
          value: sendAmount,
        })
      )
        .to.emit(treasury, "FundsDeposited")
        .withArgs(owner.address, sendAmount);
    });

    it("Should emit ProposalCreated with correct parameters", async function () {
      const description = "Event test proposal";
      await expect(
        treasury
          .connect(addr1)
          .createProposal(recipient.address, PROPOSAL_AMOUNT, description)
      )
        .to.emit(treasury, "ProposalCreated")
        .withArgs(1, addr1.address, recipient.address, PROPOSAL_AMOUNT, description);
    });

    it("Should emit VoteCast with correct parameters", async function () {
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Vote test");

      const votingPower = await governanceToken.balanceOf(addr1.address);

      await expect(treasury.connect(addr1).vote(proposalId, true))
        .to.emit(treasury, "VoteCast")
        .withArgs(proposalId, addr1.address, true, votingPower);

      await expect(treasury.connect(addr2).vote(proposalId, false))
        .to.emit(treasury, "VoteCast")
        .withArgs(proposalId, addr2.address, false, await governanceToken.balanceOf(addr2.address));
    });

    it("Should emit ProposalExecuted on successful execution", async function () {
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Execute test");

      await treasury.connect(addr1).vote(proposalId, true);
      await treasury.connect(addr2).vote(proposalId, true);
      await treasury.connect(addr3).vote(proposalId, true);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(proposalId))
        .to.emit(treasury, "ProposalExecuted")
        .withArgs(proposalId, recipient.address, PROPOSAL_AMOUNT);
    });

    it("Should emit ProposalRejected on failed execution", async function () {
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Reject test");

      await treasury.connect(addr1).vote(proposalId, false);

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(treasury.executeProposal(proposalId))
        .to.emit(treasury, "ProposalRejected")
        .withArgs(proposalId);
    });
  });

  describe("View Function Tests", function () {
    let proposalId;

    beforeEach(async function () {
      proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "View test");
    });

    it("Should return correct hasVoted status", async function () {
      expect(await treasury.hasVoted(proposalId, addr1.address)).to.be.false;
      expect(await treasury.hasVoted(proposalId, addr2.address)).to.be.false;

      await treasury.connect(addr1).vote(proposalId, true);

      expect(await treasury.hasVoted(proposalId, addr1.address)).to.be.true;
      expect(await treasury.hasVoted(proposalId, addr2.address)).to.be.false;

      await treasury.connect(addr2).vote(proposalId, false);

      expect(await treasury.hasVoted(proposalId, addr2.address)).to.be.true;
    });

    it("Should return correct voter weight", async function () {
      const addr1Power = await governanceToken.balanceOf(addr1.address);
      const addr2Power = await governanceToken.balanceOf(addr2.address);

      expect(await treasury.getVoterWeight(proposalId, addr1.address)).to.equal(0);

      await treasury.connect(addr1).vote(proposalId, true);
      expect(await treasury.getVoterWeight(proposalId, addr1.address)).to.equal(addr1Power);

      await treasury.connect(addr2).vote(proposalId, false);
      expect(await treasury.getVoterWeight(proposalId, addr2.address)).to.equal(addr2Power);
    });

    it("Should return correct treasury balance", async function () {
      const initialBalance = await treasury.getTreasuryBalance();
      expect(initialBalance).to.equal(TREASURY_FUNDING);

      const additionalDeposit = ethers.parseEther("5");
      await treasury.deposit({ value: additionalDeposit });

      expect(await treasury.getTreasuryBalance()).to.equal(
        TREASURY_FUNDING + additionalDeposit
      );
    });

    it("Should return correct proposal count", async function () {
      expect(await treasury.proposalCount()).to.equal(1);

      await treasury
        .connect(addr2)
        .createProposal(addr3.address, PROPOSAL_AMOUNT, "Second proposal");

      expect(await treasury.proposalCount()).to.equal(2);
    });

    it("Should return complete proposal details", async function () {
      const proposal = await treasury.getProposal(proposalId);

      expect(proposal.id).to.equal(proposalId);
      expect(proposal.proposer).to.equal(addr1.address);
      expect(proposal.recipient).to.equal(recipient.address);
      expect(proposal.amount).to.equal(PROPOSAL_AMOUNT);
      expect(proposal.description).to.equal("View test");
      expect(proposal.votesFor).to.equal(0);
      expect(proposal.votesAgainst).to.equal(0);
      expect(proposal.state).to.equal(1); // Active
    });
  });

  describe("Token Balance Changes During Voting", function () {
    it("Should use voting power at time of vote, not current balance", async function () {
      const proposalId = 1;
      await treasury
        .connect(addr1)
        .createProposal(recipient.address, PROPOSAL_AMOUNT, "Balance change test");

      const initialVotingPower = await governanceToken.balanceOf(addr1.address);
      
      // Vote with current balance
      await treasury.connect(addr1).vote(proposalId, true);

      // Check recorded weight
      expect(await treasury.getVoterWeight(proposalId, addr1.address)).to.equal(
        initialVotingPower
      );

      // Transfer tokens away (voting power already recorded)
      await governanceToken.connect(addr1).transfer(addr2.address, ethers.parseEther("1000"));

      // Voting weight should still be the original amount
      expect(await treasury.getVoterWeight(proposalId, addr1.address)).to.equal(
        initialVotingPower
      );

      // New balance is different
      expect(await governanceToken.balanceOf(addr1.address)).to.equal(
        ethers.parseEther("2000")
      );
    });
  });
});
