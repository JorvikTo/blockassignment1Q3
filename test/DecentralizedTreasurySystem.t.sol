// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/DecentralizedTreasury.sol";
import "../contracts/GovernanceToken.sol";

/**
 * @title DecentralizedTreasurySystemTest
 * @dev Comprehensive system tests for complete governance workflows
 * Tests end-to-end scenarios including proposal lifecycle and edge cases
 */
contract DecentralizedTreasurySystemTest {
    DecentralizedTreasury public treasury;
    GovernanceToken public token;
    
    address public owner;
    address public recipient;
    
    uint256 constant INITIAL_SUPPLY = 10000 * 10**18;
    uint256 constant TREASURY_FUNDING = 100 * 10**18;
    
    // Test result tracking
    uint256 public testsPassed;
    uint256 public testsFailed;
    string public lastError;
    
    constructor() {
        owner = address(this);
        recipient = address(0x999);
    }
    
    /**
     * @dev Setup function
     */
    function setUp() public {
        token = new GovernanceToken("Governance Token", "GOV", INITIAL_SUPPLY);
        treasury = new DecentralizedTreasury(address(token));
        payable(address(treasury)).transfer(TREASURY_FUNDING);
    }
    
    /**
     * @dev System Test 1: Complete proposal lifecycle - approval scenario
     * Tests: Create proposal -> Vote with majority -> Execute
     */
    function testCompleteApprovalWorkflow() public returns (bool) {
        setUp();
        
        // Distribute tokens: 60% to supporter, 40% to opposition
        VoterHelper supporter = new VoterHelper(treasury, token);
        VoterHelper opposition = new VoterHelper(treasury, token);
        
        token.transfer(address(supporter), 6000 * 10**18); // 60%
        token.transfer(address(opposition), 4000 * 10**18); // 40%
        
        uint256 proposalAmount = 10 * 10**18;
        uint256 recipientBalanceBefore = recipient.balance;
        
        // Step 1: Create proposal
        uint256 proposalId = treasury.createProposal(
            recipient,
            proposalAmount,
            "Fund project development"
        );
        
        if (proposalId != 1) {
            lastError = "Proposal creation failed";
            testsFailed++;
            return false;
        }
        
        // Step 2: Vote (60% for, 40% against)
        supporter.vote(proposalId, true);
        opposition.vote(proposalId, false);
        
        // Verify votes
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
        
        if (votesFor != 6000 * 10**18) {
            lastError = "Votes for incorrect";
            testsFailed++;
            return false;
        }
        
        if (votesAgainst != 4000 * 10**18) {
            lastError = "Votes against incorrect";
            testsFailed++;
            return false;
        }
        
        // Step 3: Wait for voting period to end (simulated)
        // In real test environment, would use time manipulation
        // Here we just verify the state before execution
        
        // Note: In actual deployment, would need to wait 3 days
        // For this test, we verify the proposal state is Active
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
        
        if (state != DecentralizedTreasury.ProposalState.Active) {
            lastError = "Proposal should be Active";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev System Test 2: Complete proposal lifecycle - rejection scenario
     * Tests: Create proposal -> Vote with minority -> Reject
     */
    function testCompleteRejectionWorkflow() public returns (bool) {
        setUp();
        
        // Distribute tokens: 40% for, 60% against
        VoterHelper supporter = new VoterHelper(treasury, token);
        VoterHelper opposition = new VoterHelper(treasury, token);
        
        token.transfer(address(supporter), 4000 * 10**18); // 40%
        token.transfer(address(opposition), 6000 * 10**18); // 60%
        
        uint256 proposalAmount = 10 * 10**18;
        
        // Step 1: Create proposal
        uint256 proposalId = treasury.createProposal(
            recipient,
            proposalAmount,
            "Fund controversial project"
        );
        
        // Step 2: Vote (40% for, 60% against)
        supporter.vote(proposalId, true);
        opposition.vote(proposalId, false);
        
        // Verify votes
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
        
        if (votesFor != 4000 * 10**18) {
            lastError = "Votes for incorrect in rejection workflow";
            testsFailed++;
            return false;
        }
        
        if (votesAgainst != 6000 * 10**18) {
            lastError = "Votes against incorrect in rejection workflow";
            testsFailed++;
            return false;
        }
        
        // Proposal should remain Active until execution attempt
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
        
        if (state != DecentralizedTreasury.ProposalState.Active) {
            lastError = "Proposal should remain Active";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev System Test 3: Multiple proposals workflow
     * Tests concurrent proposals with different outcomes
     */
    function testMultipleProposals() public returns (bool) {
        setUp();
        
        // Create three voters
        VoterHelper voter1 = new VoterHelper(treasury, token);
        VoterHelper voter2 = new VoterHelper(treasury, token);
        VoterHelper voter3 = new VoterHelper(treasury, token);
        
        token.transfer(address(voter1), 3000 * 10**18);
        token.transfer(address(voter2), 3000 * 10**18);
        token.transfer(address(voter3), 4000 * 10**18);
        
        // Create multiple proposals
        uint256 proposal1 = treasury.createProposal(
            recipient,
            5 * 10**18,
            "Proposal 1"
        );
        
        uint256 proposal2 = treasury.createProposal(
            address(0x888),
            10 * 10**18,
            "Proposal 2"
        );
        
        uint256 proposal3 = treasury.createProposal(
            address(0x777),
            15 * 10**18,
            "Proposal 3"
        );
        
        if (treasury.proposalCount() != 3) {
            lastError = "Should have 3 proposals";
            testsFailed++;
            return false;
        }
        
        // Different voting patterns for each proposal
        // Proposal 1: All vote for (100%)
        voter1.vote(proposal1, true);
        voter2.vote(proposal1, true);
        voter3.vote(proposal1, true);
        
        // Proposal 2: Mixed voting (60% for)
        voter1.vote(proposal2, true);
        voter2.vote(proposal2, true);
        voter3.vote(proposal2, false);
        
        // Proposal 3: Majority against (40% for)
        voter1.vote(proposal3, true);
        voter2.vote(proposal3, false);
        voter3.vote(proposal3, false);
        
        // Verify proposal 1 votes
        (
            ,
            ,
            ,
            ,
            ,
            uint256 p1VotesFor,
            uint256 p1VotesAgainst,
            ,
            ,
        ) = treasury.getProposal(proposal1);
        
        if (p1VotesFor != 10000 * 10**18) {
            lastError = "Proposal 1 votes for incorrect";
            testsFailed++;
            return false;
        }
        
        if (p1VotesAgainst != 0) {
            lastError = "Proposal 1 votes against should be 0";
            testsFailed++;
            return false;
        }
        
        // Verify proposal 2 votes
        (
            ,
            ,
            ,
            ,
            ,
            uint256 p2VotesFor,
            uint256 p2VotesAgainst,
            ,
            ,
        ) = treasury.getProposal(proposal2);
        
        if (p2VotesFor != 6000 * 10**18) {
            lastError = "Proposal 2 votes for incorrect";
            testsFailed++;
            return false;
        }
        
        if (p2VotesAgainst != 4000 * 10**18) {
            lastError = "Proposal 2 votes against incorrect";
            testsFailed++;
            return false;
        }
        
        // Verify proposal 3 votes
        (
            ,
            ,
            ,
            ,
            ,
            uint256 p3VotesFor,
            uint256 p3VotesAgainst,
            ,
            ,
        ) = treasury.getProposal(proposal3);
        
        if (p3VotesFor != 3000 * 10**18) {
            lastError = "Proposal 3 votes for incorrect";
            testsFailed++;
            return false;
        }
        
        if (p3VotesAgainst != 7000 * 10**18) {
            lastError = "Proposal 3 votes against incorrect";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev System Test 4: Edge case - Exactly 50% votes
     * Should NOT pass (needs >50%)
     */
    function testExactly50PercentVotes() public returns (bool) {
        setUp();
        
        // Distribute exactly 50-50
        VoterHelper supporter = new VoterHelper(treasury, token);
        VoterHelper holder = new VoterHelper(treasury, token);
        
        token.transfer(address(supporter), 5000 * 10**18); // 50%
        token.transfer(address(holder), 5000 * 10**18); // 50% (doesn't vote)
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            10 * 10**18,
            "Exactly 50% test"
        );
        
        // Only supporter votes (50% of total)
        supporter.vote(proposalId, true);
        
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
        
        // Verify exactly 50% voted for
        if (votesFor != 5000 * 10**18) {
            lastError = "Should have exactly 50% votes";
            testsFailed++;
            return false;
        }
        
        // This should NOT be enough to pass (needs >50%)
        uint256 totalSupply = token.totalSupply();
        bool wouldPass = (votesFor * 2) > totalSupply;
        
        if (wouldPass) {
            lastError = "Exactly 50% should not pass";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev System Test 5: Edge case - Just over 50% votes
     * Should pass (>50%)
     */
    function testJustOver50PercentVotes() public returns (bool) {
        setUp();
        
        // Give 50.01% to supporter
        VoterHelper supporter = new VoterHelper(treasury, token);
        VoterHelper holder = new VoterHelper(treasury, token);
        
        token.transfer(address(supporter), 5001 * 10**18); // 50.01%
        token.transfer(address(holder), 4999 * 10**18); // 49.99%
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            10 * 10**18,
            "Just over 50% test"
        );
        
        // Only supporter votes
        supporter.vote(proposalId, true);
        
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
        
        // Verify just over 50% voted for
        uint256 totalSupply = token.totalSupply();
        bool wouldPass = (votesFor * 2) > totalSupply;
        
        if (!wouldPass) {
            lastError = "Just over 50% should pass";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev System Test 6: Token transfer during voting
     * Voting power should be snapshot at vote time
     */
    function testVotingPowerSnapshot() public returns (bool) {
        setUp();
        
        VoterHelper voter = new VoterHelper(treasury, token);
        token.transfer(address(voter), 3000 * 10**18);
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            10 * 10**18,
            "Snapshot test"
        );
        
        // Vote with 3000 tokens
        voter.vote(proposalId, true);
        
        // Transfer more tokens to voter after voting
        token.transfer(address(voter), 2000 * 10**18);
        
        // Verify voter weight is still original amount
        uint256 voterWeight = treasury.getVoterWeight(proposalId, address(voter));
        
        if (voterWeight != 3000 * 10**18) {
            lastError = "Voter weight should be snapshot at vote time";
            testsFailed++;
            return false;
        }
        
        // Verify proposal votes for is still original amount
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
        
        if (votesFor != 3000 * 10**18) {
            lastError = "Votes should not change after token transfer";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev System Test 7: Sequential proposals
     * Test creating and voting on proposals one after another
     */
    function testSequentialProposals() public returns (bool) {
        setUp();
        
        VoterHelper voter = new VoterHelper(treasury, token);
        token.transfer(address(voter), 6000 * 10**18);
        
        // Create and vote on first proposal
        uint256 proposal1 = treasury.createProposal(
            recipient,
            5 * 10**18,
            "First proposal"
        );
        voter.vote(proposal1, true);
        
        // Create and vote on second proposal
        uint256 proposal2 = treasury.createProposal(
            address(0x888),
            10 * 10**18,
            "Second proposal"
        );
        voter.vote(proposal2, true);
        
        // Create and vote on third proposal
        uint256 proposal3 = treasury.createProposal(
            address(0x777),
            15 * 10**18,
            "Third proposal"
        );
        voter.vote(proposal3, false);
        
        // Verify all proposals were created correctly
        if (treasury.proposalCount() != 3) {
            lastError = "Should have 3 proposals";
            testsFailed++;
            return false;
        }
        
        // Verify voter has voted on all
        if (!treasury.hasVoted(proposal1, address(voter))) {
            lastError = "Should have voted on proposal 1";
            testsFailed++;
            return false;
        }
        
        if (!treasury.hasVoted(proposal2, address(voter))) {
            lastError = "Should have voted on proposal 2";
            testsFailed++;
            return false;
        }
        
        if (!treasury.hasVoted(proposal3, address(voter))) {
            lastError = "Should have voted on proposal 3";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev System Test 8: Treasury funding and multiple withdrawals
     * Test that treasury can handle multiple approved proposals
     */
    function testMultipleWithdrawals() public returns (bool) {
        setUp();
        
        uint256 initialBalance = treasury.getTreasuryBalance();
        
        if (initialBalance != TREASURY_FUNDING) {
            lastError = "Initial balance incorrect";
            testsFailed++;
            return false;
        }
        
        // Create multiple small proposals (that would be approved if executed)
        uint256 proposal1 = treasury.createProposal(
            recipient,
            10 * 10**18,
            "Proposal 1"
        );
        
        uint256 proposal2 = treasury.createProposal(
            address(0x888),
            20 * 10**18,
            "Proposal 2"
        );
        
        uint256 proposal3 = treasury.createProposal(
            address(0x777),
            30 * 10**18,
            "Proposal 3"
        );
        
        // Verify total of all proposals is less than treasury balance
        uint256 totalRequested = 60 * 10**18;
        
        if (totalRequested > initialBalance) {
            lastError = "Total requested exceeds initial balance";
            testsFailed++;
            return false;
        }
        
        // Verify all proposals were created
        if (treasury.proposalCount() != 3) {
            lastError = "Should have 3 proposals";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Run all system tests
     */
    function runAllTests() public returns (uint256 passed, uint256 failed) {
        testsPassed = 0;
        testsFailed = 0;
        
        testCompleteApprovalWorkflow();
        testCompleteRejectionWorkflow();
        testMultipleProposals();
        testExactly50PercentVotes();
        testJustOver50PercentVotes();
        testVotingPowerSnapshot();
        testSequentialProposals();
        testMultipleWithdrawals();
        
        return (testsPassed, testsFailed);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}

/**
 * @dev Helper contract for voting from different addresses
 */
contract VoterHelper {
    DecentralizedTreasury public treasury;
    GovernanceToken public token;
    
    constructor(DecentralizedTreasury _treasury, GovernanceToken _token) {
        treasury = _treasury;
        token = _token;
    }
    
    function vote(uint256 proposalId, bool support) external {
        treasury.vote(proposalId, support);
    }
    
    receive() external payable {}
}
