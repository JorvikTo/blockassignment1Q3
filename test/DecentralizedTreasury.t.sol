// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/DecentralizedTreasury.sol";
import "../contracts/GovernanceToken.sol";

/**
 * @title DecentralizedTreasuryTest
 * @dev Comprehensive unit and system tests for the DecentralizedTreasury contract
 * Tests cover all major functionality including proposal creation, voting, and execution
 */
contract DecentralizedTreasuryTest {
    DecentralizedTreasury public treasury;
    GovernanceToken public token;
    
    address public owner;
    address public voter1;
    address public voter2;
    address public voter3;
    address public recipient;
    
    uint256 constant INITIAL_SUPPLY = 10000 * 10**18;
    uint256 constant TREASURY_FUNDING = 10 * 10**18;
    uint256 constant PROPOSAL_AMOUNT = 1 * 10**18;
    
    // Test result tracking
    uint256 public testsPassed;
    uint256 public testsFailed;
    string public lastError;
    
    // Events to verify
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed recipient,
        uint256 amount,
        string description
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed recipient,
        uint256 amount
    );
    
    event ProposalRejected(uint256 indexed proposalId);
    event FundsDeposited(address indexed sender, uint256 amount);
    
    constructor() {
        owner = address(this);
        voter1 = address(0x1);
        voter2 = address(0x2);
        voter3 = address(0x3);
        recipient = address(0x999);
    }
    
    /**
     * @dev Setup function to deploy fresh contracts before tests
     */
    function setUp() public {
        // Deploy governance token
        token = new GovernanceToken("Governance Token", "GOV", INITIAL_SUPPLY);
        
        // Deploy treasury
        treasury = new DecentralizedTreasury(address(token));
        
        // Distribute tokens
        token.transfer(voter1, 3000 * 10**18);
        token.transfer(voter2, 2000 * 10**18);
        token.transfer(voter3, 1000 * 10**18);
        
        // Fund treasury
        payable(address(treasury)).transfer(TREASURY_FUNDING);
    }
    
    /**
     * @dev Test 1: Treasury deployment should set correct governance token
     */
    function testDeployment() public returns (bool) {
        setUp();
        
        if (address(treasury.governanceToken()) != address(token)) {
            lastError = "Governance token not set correctly";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 2: Treasury should accept deposits
     */
    function testDeposit() public returns (bool) {
        setUp();
        
        uint256 initialBalance = treasury.getTreasuryBalance();
        uint256 depositAmount = 5 * 10**18;
        
        treasury.deposit{value: depositAmount}();
        
        if (treasury.getTreasuryBalance() != initialBalance + depositAmount) {
            lastError = "Treasury balance not updated";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 3: Deposit with zero value should fail
     */
    function testDepositZeroValue() public returns (bool) {
        setUp();
        
        try treasury.deposit{value: 0}() {
            lastError = "Should not allow zero deposits";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Must deposit some ETH"))) {
                lastError = "Wrong error message";
                testsFailed++;
                return false;
            }
        } catch {
            lastError = "Unexpected revert";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 4: Treasury should return correct balance
     */
    function testGetTreasuryBalance() public returns (bool) {
        setUp();
        
        if (treasury.getTreasuryBalance() != TREASURY_FUNDING) {
            lastError = "Incorrect treasury balance";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 5: Voting period should be set to 3 days
     */
    function testVotingPeriod() public returns (bool) {
        setUp();
        
        if (treasury.votingPeriod() != 3 days) {
            lastError = "Voting period not 3 days";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 6: Should be able to set new voting period
     */
    function testSetVotingPeriod() public returns (bool) {
        setUp();
        
        uint256 newPeriod = 7 days;
        treasury.setVotingPeriod(newPeriod);
        
        if (treasury.votingPeriod() != newPeriod) {
            lastError = "Voting period not updated";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 7: Setting zero voting period should fail
     */
    function testSetVotingPeriodZero() public returns (bool) {
        setUp();
        
        try treasury.setVotingPeriod(0) {
            lastError = "Should not allow zero voting period";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Voting period must be positive"))) {
                lastError = "Wrong error message";
                testsFailed++;
                return false;
            }
        } catch {
            lastError = "Unexpected revert";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 8: Create proposal with valid parameters
     */
    function testCreateProposal() public returns (bool) {
        setUp();
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            PROPOSAL_AMOUNT,
            "Test proposal"
        );
        
        if (proposalId != 1) {
            lastError = "Proposal ID should be 1";
            testsFailed++;
            return false;
        }
        
        if (treasury.proposalCount() != 1) {
            lastError = "Proposal count should be 1";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 9: Get proposal should return correct data
     */
    function testGetProposal() public returns (bool) {
        setUp();
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            PROPOSAL_AMOUNT,
            "Test proposal"
        );
        
        (
            uint256 id,
            address proposer,
            address proposalRecipient,
            uint256 amount,
            string memory description,
            uint256 votesFor,
            uint256 votesAgainst,
            ,
            ,
            DecentralizedTreasury.ProposalState state
        ) = treasury.getProposal(proposalId);
        
        if (id != proposalId) {
            lastError = "Proposal ID mismatch";
            testsFailed++;
            return false;
        }
        
        if (proposer != address(this)) {
            lastError = "Proposer mismatch";
            testsFailed++;
            return false;
        }
        
        if (proposalRecipient != recipient) {
            lastError = "Recipient mismatch";
            testsFailed++;
            return false;
        }
        
        if (amount != PROPOSAL_AMOUNT) {
            lastError = "Amount mismatch";
            testsFailed++;
            return false;
        }
        
        if (keccak256(bytes(description)) != keccak256(bytes("Test proposal"))) {
            lastError = "Description mismatch";
            testsFailed++;
            return false;
        }
        
        if (votesFor != 0) {
            lastError = "Initial votes for should be 0";
            testsFailed++;
            return false;
        }
        
        if (votesAgainst != 0) {
            lastError = "Initial votes against should be 0";
            testsFailed++;
            return false;
        }
        
        if (state != DecentralizedTreasury.ProposalState.Active) {
            lastError = "State should be Active";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 10: Creating proposal without tokens should fail
     */
    function testCreateProposalNoTokens() public returns (bool) {
        setUp();
        
        // Create helper contract with no tokens
        NoTokenHelper helper = new NoTokenHelper(treasury);
        
        try helper.tryCreateProposal(recipient, PROPOSAL_AMOUNT, "Test") {
            lastError = "Should not allow proposal without tokens";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Must hold tokens to propose"))) {
                lastError = "Wrong error message";
                testsFailed++;
                return false;
            }
        } catch {
            lastError = "Unexpected revert";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 11: Creating proposal with zero amount should fail
     */
    function testCreateProposalZeroAmount() public returns (bool) {
        setUp();
        
        try treasury.createProposal(recipient, 0, "Test") {
            lastError = "Should not allow zero amount";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Amount must be greater than 0"))) {
                lastError = "Wrong error message";
                testsFailed++;
                return false;
            }
        } catch {
            lastError = "Unexpected revert";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 12: Creating proposal with zero address should fail
     */
    function testCreateProposalZeroAddress() public returns (bool) {
        setUp();
        
        try treasury.createProposal(address(0), PROPOSAL_AMOUNT, "Test") {
            lastError = "Should not allow zero address";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Invalid recipient"))) {
                lastError = "Wrong error message";
                testsFailed++;
                return false;
            }
        } catch {
            lastError = "Unexpected revert";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 13: Creating proposal with amount exceeding treasury should fail
     */
    function testCreateProposalExceedingBalance() public returns (bool) {
        setUp();
        
        uint256 tooMuch = 100 * 10**18;
        
        try treasury.createProposal(recipient, tooMuch, "Test") {
            lastError = "Should not allow amount exceeding balance";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Insufficient treasury funds"))) {
                lastError = "Wrong error message";
                testsFailed++;
                return false;
            }
        } catch {
            lastError = "Unexpected revert";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 14: Voting with tokens should work
     */
    function testVote() public returns (bool) {
        setUp();
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            PROPOSAL_AMOUNT,
            "Test proposal"
        );
        
        // Create helper to vote from voter1 address
        VoterHelper helper1 = new VoterHelper(treasury, token);
        token.transfer(address(helper1), 3000 * 10**18);
        helper1.vote(proposalId, true);
        
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
        
        if (votesFor != 3000 * 10**18) {
            lastError = "Votes for incorrect";
            testsFailed++;
            return false;
        }
        
        if (votesAgainst != 0) {
            lastError = "Votes against should be 0";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 15: Voting against should work
     */
    function testVoteAgainst() public returns (bool) {
        setUp();
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            PROPOSAL_AMOUNT,
            "Test proposal"
        );
        
        // Create helper to vote from different address
        VoterHelper helper = new VoterHelper(treasury, token);
        token.transfer(address(helper), 2000 * 10**18);
        helper.vote(proposalId, false);
        
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
        
        if (votesFor != 0) {
            lastError = "Votes for should be 0";
            testsFailed++;
            return false;
        }
        
        if (votesAgainst != 2000 * 10**18) {
            lastError = "Votes against incorrect";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 16: Voting without tokens should fail
     */
    function testVoteNoTokens() public returns (bool) {
        setUp();
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            PROPOSAL_AMOUNT,
            "Test proposal"
        );
        
        NoTokenHelper helper = new NoTokenHelper(treasury);
        
        try helper.tryVote(proposalId, true) {
            lastError = "Should not allow voting without tokens";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("No voting power"))) {
                lastError = "Wrong error message";
                testsFailed++;
                return false;
            }
        } catch {
            lastError = "Unexpected revert";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 17: Has voted should track voting status
     */
    function testHasVoted() public returns (bool) {
        setUp();
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            PROPOSAL_AMOUNT,
            "Test proposal"
        );
        
        VoterHelper helper = new VoterHelper(treasury, token);
        token.transfer(address(helper), 1000 * 10**18);
        
        if (treasury.hasVoted(proposalId, address(helper))) {
            lastError = "Should not have voted yet";
            testsFailed++;
            return false;
        }
        
        helper.vote(proposalId, true);
        
        if (!treasury.hasVoted(proposalId, address(helper))) {
            lastError = "Should have voted";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 18: Get voter weight should return correct weight
     */
    function testGetVoterWeight() public returns (bool) {
        setUp();
        
        uint256 proposalId = treasury.createProposal(
            recipient,
            PROPOSAL_AMOUNT,
            "Test proposal"
        );
        
        VoterHelper helper = new VoterHelper(treasury, token);
        uint256 voterTokens = 1500 * 10**18;
        token.transfer(address(helper), voterTokens);
        
        helper.vote(proposalId, true);
        
        if (treasury.getVoterWeight(proposalId, address(helper)) != voterTokens) {
            lastError = "Voter weight incorrect";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Run all tests and return summary
     */
    function runAllTests() public returns (uint256 passed, uint256 failed) {
        testsPassed = 0;
        testsFailed = 0;
        
        testDeployment();
        testDeposit();
        testDepositZeroValue();
        testGetTreasuryBalance();
        testVotingPeriod();
        testSetVotingPeriod();
        testSetVotingPeriodZero();
        testCreateProposal();
        testGetProposal();
        testCreateProposalNoTokens();
        testCreateProposalZeroAmount();
        testCreateProposalZeroAddress();
        testCreateProposalExceedingBalance();
        testVote();
        testVoteAgainst();
        testVoteNoTokens();
        testHasVoted();
        testGetVoterWeight();
        
        return (testsPassed, testsFailed);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}

/**
 * @dev Helper contract for testing scenarios where caller has no tokens
 */
contract NoTokenHelper {
    DecentralizedTreasury public treasury;
    
    constructor(DecentralizedTreasury _treasury) {
        treasury = _treasury;
    }
    
    function tryCreateProposal(
        address recipient,
        uint256 amount,
        string memory description
    ) external returns (uint256) {
        return treasury.createProposal(recipient, amount, description);
    }
    
    function tryVote(uint256 proposalId, bool support) external {
        treasury.vote(proposalId, support);
    }
}

/**
 * @dev Helper contract for testing voting from different addresses
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
    
    // Allow receiving tokens
    receive() external payable {}
}
