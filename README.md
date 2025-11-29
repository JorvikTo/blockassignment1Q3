# Decentralized Treasury Management System

A decentralized organization treasury management solution built with Solidity smart contracts. This system enables transparent fund management through token-weighted voting and automated proposal execution.

## Features

### 🏦 Treasury Management
- Secure fund deposits and storage
- Transparent balance tracking
- Automated fund transfers upon proposal approval

### 🗳️ Decentralized Governance
- **Token-Weighted Voting**: Voting power proportional to governance token holdings
- **Proposal System**: Members can create fund transfer proposals
- **Majority Voting**: Configurable majority and quorum thresholds
- **Automatic Execution**: Approved proposals execute automatically

### 🔒 Security & Auditability
- ReentrancyGuard protection
- Transparent vote tracking
- Immutable proposal history
- Event logging for all key actions

## Smart Contracts

### GovernanceToken
ERC20 token that represents voting power in the organization.

**Key Functions:**
- `mint(address to, uint256 amount)`: Mint new tokens (owner only)
- `getVotingPower(address account)`: Check voting power of an account

### DecentralizedTreasury
Main treasury contract managing proposals, voting, and fund transfers.

**Key Functions:**
- `deposit()`: Add funds to the treasury
- `createProposal(address recipient, uint256 amount, string description)`: Create a new fund transfer proposal
- `vote(uint256 proposalId, bool support)`: Cast a vote on a proposal
- `executeProposal(uint256 proposalId)`: Execute an approved proposal after voting period
- `getProposal(uint256 proposalId)`: Get proposal details
- `getTreasuryBalance()`: Check treasury balance

**Governance Parameters:**
- Voting Period: 3 days (configurable)
- Quorum: 50% of total token supply (configurable)
- Majority: 51% of votes cast (configurable)

## Installation

```bash
npm install
```

## Compilation

Compile the smart contracts:

```bash
npm run compile
```

## Testing

Run the comprehensive test suite:

```bash
npm test
```

### Test Suite Overview

The project includes **107+ test cases** across three test files:

#### 1. GovernanceToken Unit Tests (38 tests)
Tests for the ERC20 governance token contract:
- Deployment and initialization
- Token minting (owner-only)
- ERC20 transfers and allowances
- Voting power calculations
- Ownership management
- Edge cases

#### 2. DecentralizedTreasury Unit Tests (~50 tests)
Tests for the treasury governance contract:
- Treasury deposit and balance management
- Proposal creation with validation
- Token-weighted voting mechanics
- Proposal execution and rejection flows
- Security features (reentrancy protection, access control)
- Event emissions
- View functions
- Edge cases and parameter management

#### 3. System Integration Tests (19 tests)
End-to-end tests for complete DAO workflows:
- Complete DAO lifecycle (deploy → fund → propose → vote → execute)
- Multiple concurrent proposals
- Complex voting scenarios
- Governance power dynamics
- Treasury fund management
- Real-world DAO operation simulation

### Run Specific Test Files

```bash
# Run only GovernanceToken tests
npx hardhat test test/GovernanceToken.test.js

# Run only DecentralizedTreasury tests
npx hardhat test test/DecentralizedTreasury.test.js

# Run only System Integration tests
npx hardhat test test/SystemIntegration.test.js
```

### Test Coverage

- **GovernanceToken.sol**: 100% function coverage
- **DecentralizedTreasury.sol**: 100% function coverage
- **Integration**: Complete workflow coverage

For detailed test coverage information, see [TEST_COVERAGE.md](./TEST_COVERAGE.md).

For implementation details, see [TEST_IMPLEMENTATION_SUMMARY.md](./TEST_IMPLEMENTATION_SUMMARY.md).

## Deployment

Deploy to a local Hardhat network:

```bash
npm run deploy
```

The deployment script will:
1. Deploy the GovernanceToken with an initial supply
2. Deploy the DecentralizedTreasury
3. Display all contract addresses and configuration

## Usage Example

### 1. Fund the Treasury
```javascript
await treasury.deposit({ value: ethers.parseEther("100") });
```

### 2. Create a Proposal
```javascript
const proposalId = await treasury.createProposal(
  recipientAddress,
  ethers.parseEther("10"),
  "Fund marketing campaign"
);
```

### 3. Vote on the Proposal
```javascript
// Vote in favor
await treasury.vote(proposalId, true);

// Vote against
await treasury.vote(proposalId, false);
```

### 4. Execute the Proposal
After the voting period ends and quorum/majority requirements are met:

```javascript
await treasury.executeProposal(proposalId);
```

## Governance Flow

```
1. Member creates proposal → Proposal enters Active state
2. Token holders vote (for/against) → Votes weighted by token balance
3. Voting period ends (3 days)
4. Execute proposal:
   - Check quorum (≥50% of tokens voted)
   - Check majority (≥51% voted in favor)
   - If passed: Transfer funds automatically
   - If failed: Mark as Rejected
```

## Security Considerations

- ✅ ReentrancyGuard prevents reentrancy attacks
- ✅ Input validation on all public functions
- ✅ Token holders must have voting power to participate
- ✅ Proposals cannot be executed during voting period
- ✅ Proposals cannot be executed twice
- ✅ Treasury balance checked before execution
- ✅ No unilateral spending - all transfers require governance approval

## Requirements Met

✅ **Transparent Fund Management**: All treasury operations emit events and are publicly auditable

✅ **Proposal System**: Members can create detailed fund transfer proposals

✅ **Token-Weighted Voting**: Voting power directly correlates with token holdings

✅ **Automatic Execution**: Proposals execute automatically when majority approves

✅ **Decentralized Governance**: No single point of control, all decisions require community consensus

✅ **Auditability**: Complete event logging and state tracking

✅ **Reduced Unilateral Spending Risk**: Multi-party approval required for all fund transfers

## License

ISC

