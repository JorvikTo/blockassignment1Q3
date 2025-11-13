# Quick Start Guide

## Installation

```bash
npm install
```

## Quick Demo

Run the example usage script to see the complete workflow:

```bash
npx hardhat run scripts/example-usage.js
```

This will demonstrate:
1. Deploying the contracts
2. Distributing governance tokens
3. Funding the treasury
4. Creating a proposal
5. Voting on the proposal
6. Executing the approved proposal

## Basic Usage

### 1. Deploy Contracts

```bash
npm run deploy
```

### 2. Interact with the Treasury

```javascript
// Fund the treasury
await treasury.deposit({ value: ethers.parseEther("10") });

// Create a proposal
const proposalId = await treasury.createProposal(
  recipientAddress,
  ethers.parseEther("1"),
  "Project funding"
);

// Vote (requires governance tokens)
await treasury.vote(proposalId, true); // vote FOR
// or
await treasury.vote(proposalId, false); // vote AGAINST

// After voting period ends, execute
await treasury.executeProposal(proposalId);
```

### 3. Check Proposal Status

```javascript
const proposal = await treasury.getProposal(proposalId);
console.log("Votes FOR:", proposal.votesFor);
console.log("Votes AGAINST:", proposal.votesAgainst);
console.log("State:", proposal.state); // 0=Pending, 1=Active, 2=Executed, 3=Rejected
```

## Governance Parameters

- **Voting Period:** 3 days (259,200 seconds)
- **Quorum Required:** 50% of total token supply
- **Majority Required:** 51% of votes cast

These can be configured using:
```javascript
await treasury.setVotingPeriod(7 * 24 * 60 * 60); // 7 days
await treasury.setQuorumPercentage(60); // 60%
await treasury.setMajorityPercentage(66); // 66%
```

## Testing

Run all tests:
```bash
npm test
```

Note: Due to network restrictions, you may need to manually compile contracts first using the local solc compiler.

## Key Concepts

### Token-Weighted Voting
Your voting power equals your token balance:
- 1000 tokens = 1000 votes
- Tokens must be held at time of voting

### Proposal Lifecycle
1. **Created** → Active for 3 days
2. **Voting** → Token holders cast votes
3. **Execution** → After deadline, anyone can trigger execution
4. **Result** → Executed (if passed) or Rejected (if failed)

### Execution Requirements
For a proposal to execute:
1. ✅ Voting period must be over
2. ✅ Quorum reached (≥50% of tokens voted)
3. ✅ Majority achieved (≥51% voted FOR)
4. ✅ Treasury has sufficient funds

## Security

- ✅ No single person can withdraw funds
- ✅ All transfers require community approval
- ✅ ReentrancyGuard protects against attacks
- ✅ Complete audit trail via events
- ✅ Input validation on all functions

## Learn More

- See [README.md](README.md) for full documentation
- See [VERIFICATION.md](VERIFICATION.md) for requirements mapping
- See [SECURITY.md](SECURITY.md) for security analysis
- See [scripts/example-usage.js](scripts/example-usage.js) for workflow example

## Support

For issues or questions, refer to the comprehensive documentation in README.md.
