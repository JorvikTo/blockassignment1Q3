// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DecentralizedTreasury
 * @dev Treasury contract with token-weighted voting governance
 * Enables decentralized fund management through proposals and voting
 */
contract DecentralizedTreasury is ReentrancyGuard {
    IERC20 public governanceToken;
    
    // Proposal states
    enum ProposalState { Pending, Active, Executed, Rejected, Cancelled }
    
    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        address recipient;
        uint256 amount;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        uint256 votingDeadline;
        ProposalState state;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterWeights;
    }
    
    // State variables
    uint256 public proposalCount;
    uint256 public votingPeriod = 3 days;
    uint256 public quorumPercentage = 50; // 50% of total supply needed for quorum
    uint256 public majorityPercentage = 51; // 51% of votes for approval
    
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
     * @dev Constructor to initialize the treasury with governance token
     * @param _governanceToken Address of the governance token contract
     */
    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
    }
    
    /**
     * @dev Allow contract to receive ETH
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Deposit funds to treasury
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
     * @dev Create a new fund transfer proposal
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
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= address(this).balance, "Insufficient treasury funds");
        require(governanceToken.balanceOf(msg.sender) > 0, "Must hold tokens to propose");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.recipient = recipient;
        newProposal.amount = amount;
        newProposal.description = description;
        newProposal.createdAt = block.timestamp;
        newProposal.votingDeadline = block.timestamp + votingPeriod;
        newProposal.state = ProposalState.Active;
        
        emit ProposalCreated(proposalId, msg.sender, recipient, amount, description);
        
        return proposalId;
    }
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId ID of the proposal to vote on
     * @param support True for voting in favor, false for voting against
     */
    function vote(uint256 proposalId, bool support) external {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp <= proposal.votingDeadline, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voterWeights[msg.sender] = votingPower;
        
        if (support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }
    
    /**
     * @dev Execute a proposal if it has passed
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp > proposal.votingDeadline, "Voting period not ended");
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 totalSupply = governanceToken.totalSupply();
        
        // Check quorum
        require(
            totalVotes * 100 >= totalSupply * quorumPercentage,
            "Quorum not reached"
        );
        
        // Check majority
        if (proposal.votesFor * 100 >= totalVotes * majorityPercentage) {
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
     * @dev Get proposal details
     * @param proposalId ID of the proposal
     * @return id Proposal ID
     * @return proposer Address of proposer
     * @return recipient Address of recipient
     * @return amount Amount to transfer
     * @return description Proposal description
     * @return votesFor Total votes in favor
     * @return votesAgainst Total votes against
     * @return createdAt Creation timestamp
     * @return votingDeadline Voting deadline timestamp
     * @return state Current proposal state
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
     * @dev Set the voting period (governance can be added later)
     * @param _votingPeriod New voting period in seconds
     */
    function setVotingPeriod(uint256 _votingPeriod) external {
        require(_votingPeriod > 0, "Voting period must be positive");
        votingPeriod = _votingPeriod;
    }
    
    /**
     * @dev Set the quorum percentage
     * @param _quorumPercentage New quorum percentage (0-100)
     */
    function setQuorumPercentage(uint256 _quorumPercentage) external {
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Invalid percentage");
        quorumPercentage = _quorumPercentage;
    }
    
    /**
     * @dev Set the majority percentage
     * @param _majorityPercentage New majority percentage (0-100)
     */
    function setMajorityPercentage(uint256 _majorityPercentage) external {
        require(_majorityPercentage > 0 && _majorityPercentage <= 100, "Invalid percentage");
        majorityPercentage = _majorityPercentage;
    }
}
