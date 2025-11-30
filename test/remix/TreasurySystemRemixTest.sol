// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Assert.sol";
import "../../contracts/DecentralizedTreasury.sol";
import "../../contracts/GovernanceToken.sol";

/**
 * @title TreasurySystemRemixTest
 * @dev System integration tests using Remix test framework
 * Tests complete governance workflows end-to-end
 */
contract TreasurySystemRemixTest {
    DecentralizedTreasury treasury;
    GovernanceToken token;
    
    uint256 constant INITIAL_SUPPLY = 10000 * 10**18;
    uint256 constant TREASURY_FUNDING = 100 ether;
    
    address voter1;
    address voter2;
    address voter3;
    address recipient;
    
    /// #value: 0
    /// #sender: account-0
    function beforeAll() public {
        // Setup test accounts
        voter1 = address(0x1);
        voter2 = address(0x2);
        voter3 = address(0x3);
        recipient = address(0x999);
        
        // Deploy governance token
        token = new GovernanceToken("Governance Token", "GOV", INITIAL_SUPPLY);
        
        // Deploy treasury
        treasury = new DecentralizedTreasury(address(token));
    }
    
    /// Test complete proposal workflow - creation and voting
    /// #value: 100000000000000000000
    function checkProposalWorkflow() public payable {
        // Fund treasury
        treasury.deposit{value: msg.value}();
        
        // Distribute tokens to voters
        token.transfer(voter1, 6000 * 10**18); // 60%
        token.transfer(voter2, 2000 * 10**18); // 20%
        token.transfer(voter3, 2000 * 10**18); // 20%
        
        // Create proposal
        uint256 proposalId = treasury.createProposal(
            recipient,
            10 ether,
            "Fund development project"
        );
        
        Assert.greaterThan(proposalId, 0, "Proposal should be created");
        
        // Verify proposal is active
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            DecentralizedTreasury.ProposalState state
        ) = treasury.getProposal(proposalId);
        
        Assert.ok(state == DecentralizedTreasury.ProposalState.Active, "Proposal should be active");
    }
    
    /// Test multiple concurrent proposals
    /// #value: 100000000000000000000
    function checkMultipleProposals() public payable {
        // Fund treasury
        treasury.deposit{value: msg.value}();
        
        uint256 initialCount = treasury.proposalCount();
        
        // Create multiple proposals
        uint256 proposal1 = treasury.createProposal(recipient, 5 ether, "Proposal 1");
        uint256 proposal2 = treasury.createProposal(address(0x888), 10 ether, "Proposal 2");
        uint256 proposal3 = treasury.createProposal(address(0x777), 15 ether, "Proposal 3");
        
        Assert.equal(treasury.proposalCount(), initialCount + 3, "Should have 3 new proposals");
        Assert.equal(proposal1, initialCount + 1, "First proposal ID should be count + 1");
        Assert.equal(proposal2, initialCount + 2, "Second proposal ID should be count + 2");
        Assert.equal(proposal3, initialCount + 3, "Third proposal ID should be count + 3");
    }
    
    /// Test voting with different token amounts
    /// #value: 100000000000000000000
    function checkWeightedVoting() public payable {
        // Fund treasury
        treasury.deposit{value: msg.value}();
        
        // Create voter helper contracts with different token amounts
        VoterHelper voter1Helper = new VoterHelper(treasury);
        VoterHelper voter2Helper = new VoterHelper(treasury);
        
        uint256 voter1Tokens = 3000 * 10**18;
        uint256 voter2Tokens = 1000 * 10**18;
        
        token.transfer(address(voter1Helper), voter1Tokens);
        token.transfer(address(voter2Helper), voter2Tokens);
        
        uint256 proposalId = treasury.createProposal(recipient, 5 ether, "Weighted voting test");
        
        // Vote with different weights
        voter1Helper.voteFor(proposalId);
        voter2Helper.voteAgainst(proposalId);
        
        (
            ,
            ,
            ,
            ,
            ,
            uint256 votesFor,
            uint256 votesAgainst,
            ,
            ,
        ) = treasury.getProposal(proposalId);
        
        Assert.equal(votesFor, voter1Tokens, "Votes for should equal voter1 tokens");
        Assert.equal(votesAgainst, voter2Tokens, "Votes against should equal voter2 tokens");
    }
    
    /// Test sequential proposals
    /// #value: 100000000000000000000
    function checkSequentialProposals() public payable {
        // Fund treasury
        treasury.deposit{value: msg.value}();
        
        VoterHelper voterHelper = new VoterHelper(treasury);
        token.transfer(address(voterHelper), 5000 * 10**18);
        
        // Create first proposal and vote
        uint256 proposal1 = treasury.createProposal(recipient, 2 ether, "First sequential");
        voterHelper.voteFor(proposal1);
        Assert.ok(treasury.hasVoted(proposal1, address(voterHelper)), "Should have voted on proposal 1");
        
        // Create second proposal and vote
        uint256 proposal2 = treasury.createProposal(address(0x888), 3 ether, "Second sequential");
        voterHelper.voteFor(proposal2);
        Assert.ok(treasury.hasVoted(proposal2, address(voterHelper)), "Should have voted on proposal 2");
        
        // Create third proposal and vote against
        uint256 proposal3 = treasury.createProposal(address(0x777), 4 ether, "Third sequential");
        voterHelper.voteAgainst(proposal3);
        Assert.ok(treasury.hasVoted(proposal3, address(voterHelper)), "Should have voted on proposal 3");
    }
    
    /// Test voting power snapshot
    /// #value: 100000000000000000000
    function checkVotingPowerSnapshot() public payable {
        // Fund treasury
        treasury.deposit{value: msg.value}();
        
        VoterHelper voterHelper = new VoterHelper(treasury);
        uint256 initialTokens = 3000 * 10**18;
        
        token.transfer(address(voterHelper), initialTokens);
        
        uint256 proposalId = treasury.createProposal(recipient, 5 ether, "Snapshot test");
        
        // Vote with initial tokens
        voterHelper.voteFor(proposalId);
        
        // Transfer more tokens after voting
        token.transfer(address(voterHelper), 2000 * 10**18);
        
        // Verify voter weight is snapshot at vote time
        uint256 voterWeight = treasury.getVoterWeight(proposalId, address(voterHelper));
        Assert.equal(voterWeight, initialTokens, "Voter weight should be snapshot at vote time");
    }
    
    /// Test treasury balance tracking
    /// #value: 50000000000000000000
    function checkTreasuryBalance() public payable {
        uint256 initialBalance = treasury.getTreasuryBalance();
        
        treasury.deposit{value: msg.value}();
        
        uint256 newBalance = treasury.getTreasuryBalance();
        Assert.equal(newBalance, initialBalance + msg.value, "Treasury balance should increase by deposit amount");
    }
    
    /// Test proposal creation by token holders only
    /// #value: 10000000000000000000
    function checkTokenHolderProposal() public payable {
        // Fund treasury
        treasury.deposit{value: msg.value}();
        
        // This contract has tokens, so should be able to create proposal
        uint256 proposalId = treasury.createProposal(recipient, 1 ether, "Token holder test");
        Assert.greaterThan(proposalId, 0, "Token holder should create proposal successfully");
    }
    
    /// Test different voting patterns
    /// #value: 100000000000000000000
    function checkVotingPatterns() public payable {
        // Fund treasury
        treasury.deposit{value: msg.value}();
        
        VoterHelper voter1Helper = new VoterHelper(treasury);
        VoterHelper voter2Helper = new VoterHelper(treasury);
        VoterHelper voter3Helper = new VoterHelper(treasury);
        
        token.transfer(address(voter1Helper), 3000 * 10**18);
        token.transfer(address(voter2Helper), 3000 * 10**18);
        token.transfer(address(voter3Helper), 4000 * 10**18);
        
        // Create proposal
        uint256 proposalId = treasury.createProposal(recipient, 10 ether, "Voting patterns test");
        
        // All vote for (unanimous)
        voter1Helper.voteFor(proposalId);
        voter2Helper.voteFor(proposalId);
        voter3Helper.voteFor(proposalId);
        
        (
            ,
            ,
            ,
            ,
            ,
            uint256 votesFor,
            uint256 votesAgainst,
            ,
            ,
        ) = treasury.getProposal(proposalId);
        
        Assert.equal(votesFor, 10000 * 10**18, "All votes should be for");
        Assert.equal(votesAgainst, 0, "No votes against");
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}

/**
 * @dev Helper contract for voting from different addresses
 */
contract VoterHelper {
    DecentralizedTreasury public treasury;
    
    constructor(DecentralizedTreasury _treasury) {
        treasury = _treasury;
    }
    
    function voteFor(uint256 proposalId) external {
        treasury.vote(proposalId, true);
    }
    
    function voteAgainst(uint256 proposalId) external {
        treasury.vote(proposalId, false);
    }
    
    receive() external payable {}
}
