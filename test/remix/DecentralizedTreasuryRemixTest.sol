// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Assert.sol";
import "../../contracts/DecentralizedTreasury.sol";
import "../../contracts/GovernanceToken.sol";

/**
 * @title DecentralizedTreasuryRemixTest
 * @dev Unit tests for DecentralizedTreasury using Remix test framework
 * Test naming follows Remix convention with # prefix
 */
contract DecentralizedTreasuryRemixTest {
    DecentralizedTreasury treasury;
    GovernanceToken token;
    
    uint256 constant INITIAL_SUPPLY = 10000 * 10**18;
    uint256 constant TREASURY_FUNDING = 10 ether;
    
    /// #value: 0
    /// #sender: account-0
    function beforeAll() public {
        // Deploy governance token
        token = new GovernanceToken("Governance Token", "GOV", INITIAL_SUPPLY);
        
        // Deploy treasury
        treasury = new DecentralizedTreasury(address(token));
    }
    
    /// Test treasury deployment sets correct governance token
    function checkDeployment() public {
        Assert.equal(address(treasury.governanceToken()), address(token), "Governance token should be set correctly");
    }
    
    /// Test voting period is set to 3 days
    function checkVotingPeriod() public {
        Assert.equal(treasury.votingPeriod(), 3 days, "Voting period should be 3 days");
    }
    
    /// Test treasury can receive deposits
    /// #value: 10000000000000000000
    function checkDeposit() public payable {
        uint256 initialBalance = treasury.getTreasuryBalance();
        treasury.deposit{value: msg.value}();
        Assert.equal(treasury.getTreasuryBalance(), initialBalance + msg.value, "Treasury balance should increase");
    }
    
    /// Test get treasury balance
    function checkGetTreasuryBalance() public {
        uint256 balance = treasury.getTreasuryBalance();
        Assert.ok(balance >= 0, "Balance should be non-negative");
    }
    
    /// Test set voting period
    function checkSetVotingPeriod() public {
        uint256 newPeriod = 7 days;
        treasury.setVotingPeriod(newPeriod);
        Assert.equal(treasury.votingPeriod(), newPeriod, "Voting period should be updated");
        
        // Reset to 3 days
        treasury.setVotingPeriod(3 days);
    }
    
    /// Test creating a proposal
    /// #value: 10000000000000000000
    function checkCreateProposal() public payable {
        // Fund treasury first
        treasury.deposit{value: msg.value}();
        
        address recipient = address(0x999);
        uint256 proposalAmount = 1 ether;
        string memory description = "Test proposal";
        
        uint256 proposalId = treasury.createProposal(recipient, proposalAmount, description);
        
        Assert.equal(proposalId, treasury.proposalCount(), "Proposal ID should match count");
        Assert.greaterThan(proposalId, 0, "Proposal ID should be greater than 0");
    }
    
    /// Test get proposal returns correct data
    /// #value: 10000000000000000000
    function checkGetProposal() public payable {
        // Fund treasury first
        treasury.deposit{value: msg.value}();
        
        address recipient = address(0x888);
        uint256 proposalAmount = 1 ether;
        string memory description = "Get proposal test";
        
        uint256 proposalId = treasury.createProposal(recipient, proposalAmount, description);
        
        (
            uint256 id,
            address proposer,
            address proposalRecipient,
            uint256 amount,
            string memory desc,
            uint256 votesFor,
            uint256 votesAgainst,
            ,
            ,
            DecentralizedTreasury.ProposalState state
        ) = treasury.getProposal(proposalId);
        
        Assert.equal(id, proposalId, "Proposal ID should match");
        Assert.equal(proposer, address(this), "Proposer should be this contract");
        Assert.equal(proposalRecipient, recipient, "Recipient should match");
        Assert.equal(amount, proposalAmount, "Amount should match");
        Assert.equal(desc, description, "Description should match");
        Assert.equal(votesFor, 0, "Initial votes for should be 0");
        Assert.equal(votesAgainst, 0, "Initial votes against should be 0");
        Assert.ok(state == DecentralizedTreasury.ProposalState.Active, "Proposal should be Active");
    }
    
    /// Test voting on a proposal
    /// #value: 10000000000000000000
    function checkVote() public payable {
        // Fund treasury first
        treasury.deposit{value: msg.value}();
        
        address recipient = address(0x777);
        uint256 proposalAmount = 1 ether;
        
        uint256 proposalId = treasury.createProposal(recipient, proposalAmount, "Vote test");
        
        // Vote with our tokens
        treasury.vote(proposalId, true);
        
        (
            ,
            ,
            ,
            ,
            ,
            uint256 votesFor,
            ,
            ,
            ,
        ) = treasury.getProposal(proposalId);
        
        Assert.greaterThan(votesFor, 0, "Votes for should be greater than 0 after voting");
    }
    
    /// Test has voted tracking
    /// #value: 10000000000000000000
    function checkHasVoted() public payable {
        // Fund treasury first
        treasury.deposit{value: msg.value}();
        
        address recipient = address(0x666);
        uint256 proposalAmount = 1 ether;
        
        uint256 proposalId = treasury.createProposal(recipient, proposalAmount, "Has voted test");
        
        Assert.equal(treasury.hasVoted(proposalId, address(this)), false, "Should not have voted initially");
        
        treasury.vote(proposalId, true);
        
        Assert.equal(treasury.hasVoted(proposalId, address(this)), true, "Should have voted after voting");
    }
    
    /// Test get voter weight
    /// #value: 10000000000000000000
    function checkGetVoterWeight() public payable {
        // Fund treasury first
        treasury.deposit{value: msg.value}();
        
        address recipient = address(0x555);
        uint256 proposalAmount = 1 ether;
        
        uint256 proposalId = treasury.createProposal(recipient, proposalAmount, "Voter weight test");
        
        uint256 votingPower = token.balanceOf(address(this));
        treasury.vote(proposalId, true);
        
        uint256 voterWeight = treasury.getVoterWeight(proposalId, address(this));
        Assert.equal(voterWeight, votingPower, "Voter weight should equal voting power used");
    }
    
    /// Test proposal count increments
    /// #value: 10000000000000000000
    function checkProposalCount() public payable {
        // Fund treasury first
        treasury.deposit{value: msg.value}();
        
        uint256 initialCount = treasury.proposalCount();
        
        treasury.createProposal(address(0x444), 1 ether, "Count test");
        
        Assert.equal(treasury.proposalCount(), initialCount + 1, "Proposal count should increment");
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}
