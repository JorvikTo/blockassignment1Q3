// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DecentralizedTreasury
 * @dev Treasury contract with token-weighted voting governance
 * Enables decentralized fund management through proposals and voting
 * 
 * Key Features:
 * - Any token holder can propose fund transfers
 * - Voting power is proportional to token holdings (1 token = 1 vote)
 * - Proposals auto-execute when affirmative votes exceed 50% of total voting power
 * - All key actions emit events for external indexing
 */
contract DecentralizedTreasury is ReentrancyGuard {
    // Governance token used for voting power
    IERC20 public governanceToken;
    
    // Proposal states for lifecycle tracking
    enum ProposalState { Pending, Active, Executed, Rejected, Cancelled }
    
    // Proposal data structure
    struct Proposal {
        uint256 id;                          // Unique proposal identifier
        address proposer;                    // Address that created the proposal
        address recipient;                   // Recipient of funds (to address)
        uint256 amount;                      // Amount of ETH to transfer
        string description;                  // Purpose/description of the proposal
        uint256 votesFor;                    // Total affirmative votes (yesVotes)
        uint256 votesAgainst;                // Total negative votes (noVotes)
        uint256 createdAt;                   // Timestamp of proposal creation
        uint256 votingDeadline;              // Timestamp when voting ends
        ProposalState state;                 // Current state of the proposal
        mapping(address => bool) hasVoted;   // Track if address has voted
        mapping(address => uint256) voterWeights; // Record voting power used
    }
    
    // State variables
    uint256 public proposalCount;            // Total number of proposals created
    uint256 public votingPeriod = 3 days;    // Duration for voting on proposals
    
    // Mapping from proposal ID to proposal data
    mapping(uint256 => Proposal) public proposals;
    
    // Events
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
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    
    /**
     * @dev Constructor - Initializes the DAO treasury and assigns governance token
     * Sets up the voting power mechanism tied to token holdings
     * @param _governanceToken Address of the governance token contract for voting power
     */
    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }
    
    /**
     * @dev Allow contract to receive ETH from DAO contributions
     * Emits FundsDeposited event for tracking
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Deposit funds to treasury
     * Allows DAO members to contribute funds
     */
    function deposit() external payable {
        require(msg.value > 0, "Must deposit some ETH");
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Get treasury balance
     * @return Current ETH balance of the treasury
     */
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev proposeTransfer - Creates a proposal specifying recipient, amount, and purpose
     * Any member with tokens can propose a payment or funding allocation
     * @param to Address to receive funds (recipient)
     * @param amount Amount of ETH to transfer
     * @param description Purpose and details of the proposal
     * @return proposalId ID of the created proposal for tracking
     */
    function proposeTransfer(
        address to,
        uint256 amount,
        string memory description
    ) public returns (uint256) {
        // Validate inputs
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= address(this).balance, "Insufficient treasury funds");
        require(governanceToken.balanceOf(msg.sender) > 0, "Must hold tokens to propose");
        
        // Increment proposal counter
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        // Initialize proposal data
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.recipient = to;
        newProposal.amount = amount;
        newProposal.description = description;
        newProposal.createdAt = block.timestamp;
        newProposal.votingDeadline = block.timestamp + votingPeriod;
        newProposal.state = ProposalState.Active;
        
        // Emit event for external indexing
        emit ProposalCreated(proposalId, msg.sender, to, amount, description);
        
        return proposalId;
    }
    
    /**
     * @dev createProposal - Alias for proposeTransfer for backward compatibility
     * @param recipient Address to receive funds
     * @param amount Amount of ETH to transfer
     * @param description Description of the proposal
     * @return proposalId ID of the created proposal
     */
    function createProposal(
        address recipient,
        uint256 amount,
        string calldata description
    ) external returns (uint256) {
        return proposeTransfer(recipient, amount, description);
    }
    
    /**
     * @dev vote - Records a vote on a proposal
     * Adds voting power to yesVotes if support=true, else to noVotes
     * Voting power is proportional to token holdings at time of vote
     * @param proposalId ID of the proposal to vote on
     * @param support True for affirmative vote (yes), false for negative vote (no)
     */
    function vote(uint256 proposalId, bool support) external {
        // Validate proposal exists
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        
        // Check proposal is active and within voting period
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp <= proposal.votingDeadline, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        // Get voting power from token balance (1 token = 1 vote)
        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "No voting power");
        
        // Record vote
        proposal.hasVoted[msg.sender] = true;
        proposal.voterWeights[msg.sender] = votingPower;
        
        // Add to yesVotes or noVotes based on support
        if (support) {
            proposal.votesFor += votingPower;  // yesVotes
        } else {
            proposal.votesAgainst += votingPower;  // noVotes
        }
        
        // Emit event for external indexing
        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }
    
    /**
     * @dev executeTransfer - Transfers requested funds to the proposal's to address if it passes thresholds
     * Auto-executes once affirmative votes exceed 50% of total voting power
     * @param proposalId ID of the proposal to execute
     */
    function executeTransfer(uint256 proposalId) public nonReentrant {
        // Validate proposal exists
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        
        // Check proposal state and timing
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp > proposal.votingDeadline, "Voting period not ended");
        
        // Get total voting power (total supply of governance tokens)
        uint256 totalVotingPower = governanceToken.totalSupply();
        
        // Execution Rule: Transfer auto-executes if affirmative votes > 50% of total voting power
        // Using votesFor * 2 > totalVotingPower to avoid floating point (equivalent to votesFor > 50%)
        if (proposal.votesFor * 2 > totalVotingPower) {
            // Proposal passed - affirmative votes exceed 50% of total voting power
            require(
                proposal.amount <= address(this).balance,
                "Insufficient treasury balance"
            );
            
            // Update state before transfer (checks-effects-interactions pattern)
            proposal.state = ProposalState.Executed;
            
            // Transfer funds to recipient (to address)
            (bool success, ) = proposal.recipient.call{value: proposal.amount}("");
            require(success, "Transfer failed");
            
            // Emit event for external indexing
            emit ProposalExecuted(proposalId, proposal.recipient, proposal.amount);
        } else {
            // Proposal rejected - did not meet 50% threshold
            proposal.state = ProposalState.Rejected;
            emit ProposalRejected(proposalId);
        }
    }
    
    /**
     * @dev executeProposal - Alias for executeTransfer for backward compatibility
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        // Call the main implementation (remove nonReentrant from this to avoid double guard)
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        
        // Check proposal state and timing
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp > proposal.votingDeadline, "Voting period not ended");
        
        // Get total voting power (total supply of governance tokens)
        uint256 totalVotingPower = governanceToken.totalSupply();
        
        // Execution Rule: Transfer auto-executes if affirmative votes > 50% of total voting power
        if (proposal.votesFor * 2 > totalVotingPower) {
            // Proposal passed
            require(
                proposal.amount <= address(this).balance,
                "Insufficient treasury balance"
            );
            
            proposal.state = ProposalState.Executed;
            
            // Transfer funds
            (bool success, ) = proposal.recipient.call{value: proposal.amount}("");
            require(success, "Transfer failed");
            
            emit ProposalExecuted(proposalId, proposal.recipient, proposal.amount);
        } else {
            // Proposal rejected
            proposal.state = ProposalState.Rejected;
            emit ProposalRejected(proposalId);
        }
    }
    
    /**
     * @dev getProposal - Returns stored proposal details for display and monitoring
     * Provides complete information about a proposal's current state
     * @param proposalId ID of the proposal to retrieve
     * @return id Proposal ID
     * @return proposer Address that created the proposal
     * @return recipient Recipient of funds (to address)
     * @return amount Amount of ETH to transfer
     * @return description Purpose/description of the proposal
     * @return votesFor Total affirmative votes (yesVotes)
     * @return votesAgainst Total negative votes (noVotes)
     * @return createdAt Timestamp when proposal was created
     * @return votingDeadline Timestamp when voting period ends
     * @return state Current state (Pending/Active/Executed/Rejected)
     */
    function getProposal(uint256 proposalId)
        external
        view
        returns (
            uint256 id,
            address proposer,
            address recipient,
            uint256 amount,
            string memory description,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 createdAt,
            uint256 votingDeadline,
            ProposalState state
        )
    {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        return (
            proposal.id,
            proposal.proposer,
            proposal.recipient,
            proposal.amount,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.createdAt,
            proposal.votingDeadline,
            proposal.state
        );
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return True if the address has voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[proposalId].hasVoted[voter];
    }
    
    /**
     * @dev Get the voting weight of an address for a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return Voting weight used
     */
    function getVoterWeight(uint256 proposalId, address voter) external view returns (uint256) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[proposalId].voterWeights[voter];
    }
    
    /**
     * @dev Set the voting period
     * @param _votingPeriod New voting period in seconds
     */
    function setVotingPeriod(uint256 _votingPeriod) external {
        require(_votingPeriod > 0, "Voting period must be positive");
        votingPeriod = _votingPeriod;
    }
}
