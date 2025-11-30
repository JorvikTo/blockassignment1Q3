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

This project includes three comprehensive test suites:

### JavaScript Tests (Hardhat)

Run the JavaScript test suite:

```bash
npm test
```

The JavaScript test suite includes:
- Treasury deposit and balance management
- Proposal creation with validation
- Token-weighted voting mechanics
- Quorum and majority threshold validation
- Proposal execution and rejection flows
- Edge cases and parameter management

### Remix Test Framework (NEW)

The project includes **Remix-compatible test framework** tests written in Solidity:

```bash
npm run test:remix
```

**Remix Test Suite** (30 tests):
- **GovernanceToken unit tests** (11 tests) - `test/remix/GovernanceTokenRemixTest.sol`
- **DecentralizedTreasury unit tests** (11 tests) - `test/remix/DecentralizedTreasuryRemixTest.sol`
- **System integration tests** (8 tests) - `test/remix/TreasurySystemRemixTest.sol`
- **Assert library** - `test/remix/Assert.sol` - Remix-compatible assertions for Solidity 0.8.20

See `REMIX_TESTS.md` for detailed documentation on the Remix test framework.

### Solidity Tests (Native)

The project also includes a comprehensive **Solidity-based test suite** that runs on-chain tests written in Solidity. These tests provide:

- **36 comprehensive tests** across 3 test files
- **Unit tests** for GovernanceToken (10 tests)
- **Unit tests** for DecentralizedTreasury (18 tests)
- **System integration tests** (8 tests)

**Test Files**:
- `test/GovernanceToken.t.sol` - GovernanceToken unit tests
- `test/DecentralizedTreasury.t.sol` - DecentralizedTreasury unit tests
- `test/DecentralizedTreasurySystem.t.sol` - System integration tests
- `test/TestRunner.sol` - Test orchestration and reporting
- `test/SolidityTests.test.js` - JavaScript wrapper to run Solidity tests

The Solidity tests can be executed via the TestRunner contract or through the JavaScript test wrapper. See `SOLIDITY_TESTS.md` for detailed documentation on the Solidity test suite.

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

