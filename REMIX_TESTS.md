# Remix Test Framework Documentation

## Overview

This project includes comprehensive unit and system tests written using the **Remix test framework** for Solidity smart contracts. The Remix test framework provides a familiar and powerful way to test Solidity contracts directly in Solidity.

## Test Structure

### Test Files

The Remix tests are located in the `test/remix/` directory:

1. **Assert.sol** - Remix-compatible assertion library for Solidity 0.8.20
2. **GovernanceTokenRemixTest.sol** - Unit tests for GovernanceToken (11 tests)
3. **DecentralizedTreasuryRemixTest.sol** - Unit tests for DecentralizedTreasury (11 tests)
4. **TreasurySystemRemixTest.sol** - System integration tests (8 tests)

### Test Runner

- **RemixTests.test.js** - JavaScript wrapper to execute Remix tests via Hardhat

**Total: 30 tests using Remix test framework**

## Remix Test Framework Features

### Assertion Library

The custom `Assert.sol` library provides Remix-compatible assertions:

#### Boolean Assertions
```solidity
Assert.ok(bool condition, string message)
```

#### Equality Assertions
```solidity
Assert.equal(uint256 a, uint256 b, string message)
Assert.equal(int256 a, int256 b, string message)
Assert.equal(bool a, bool b, string message)
Assert.equal(address a, address b, string message)
Assert.equal(bytes32 a, bytes32 b, string message)
Assert.equal(string a, string b, string message)
```

#### Inequality Assertions
```solidity
Assert.notEqual(uint256 a, uint256 b, string message)
Assert.notEqual(address a, address b, string message)
// ... other types
```

#### Comparison Assertions
```solidity
Assert.greaterThan(uint256 a, uint256 b, string message)
Assert.lesserThan(uint256 a, uint256 b, string message)
```

### Test Naming Convention

Remix tests follow specific naming conventions:

1. **Setup function**: `beforeAll()` - Runs once before all tests
2. **Test functions**: Named with descriptive names starting with `check` or `test`
3. **Comments**: Use `///` for Remix annotations like `#value` and `#sender`

Example:
```solidity
/// #value: 0
/// #sender: account-0
function beforeAll() public {
    // Setup code
}

/// Test description
function checkFeature() public {
    Assert.equal(value, expected, "Should match");
}
```

## Running the Tests

### Option 1: Run All Remix Tests

```bash
npm run test:remix
```

This runs all 30 Remix framework tests across the three test suites.

### Option 2: Run All Tests (Including Hardhat Tests)

```bash
npm run test:all
```

This runs both Remix tests and traditional Hardhat tests.

### Option 3: Run Default Tests

```bash
npm test
```

This runs all test files in the test directory.

## Test Coverage

### GovernanceToken Tests (11 tests)

#### Deployment & Configuration Tests
- ✅ `checkTokenName` - Verifies token name is set correctly
- ✅ `checkTokenSymbol` - Verifies token symbol is set correctly
- ✅ `checkDecimals` - Verifies ERC20 decimals (18)
- ✅ `checkOwner` - Verifies owner is set correctly

#### Supply & Balance Tests
- ✅ `checkInitialSupply` - Verifies initial token supply
- ✅ `checkDeployerBalance` - Verifies deployer receives initial supply
- ✅ `checkMint` - Tests minting new tokens

#### Voting Power Tests
- ✅ `checkVotingPower` - Verifies voting power equals token balance
- ✅ `checkZeroVotingPower` - Verifies zero balance has zero voting power
- ✅ `checkVotingPowerUpdate` - Tests voting power updates after transfers

#### Transfer Tests
- ✅ `checkTransfer` - Tests token transfers

### DecentralizedTreasury Tests (11 tests)

#### Deployment & Configuration Tests
- ✅ `checkDeployment` - Verifies governance token is set correctly
- ✅ `checkVotingPeriod` - Verifies voting period is 3 days
- ✅ `checkSetVotingPeriod` - Tests updating voting period

#### Treasury Management Tests
- ✅ `checkDeposit` - Tests ETH deposits to treasury
- ✅ `checkGetTreasuryBalance` - Tests balance retrieval

#### Proposal Tests
- ✅ `checkCreateProposal` - Tests proposal creation
- ✅ `checkGetProposal` - Tests proposal data retrieval
- ✅ `checkProposalCount` - Tests proposal count increments

#### Voting Tests
- ✅ `checkVote` - Tests voting on proposals
- ✅ `checkHasVoted` - Tests vote tracking
- ✅ `checkGetVoterWeight` - Tests voter weight recording

### System Integration Tests (8 tests)

#### Workflow Tests
- ✅ `checkProposalWorkflow` - Complete proposal creation and voting workflow
- ✅ `checkMultipleProposals` - Concurrent proposals handling
- ✅ `checkSequentialProposals` - Sequential proposal creation and voting

#### Voting Mechanism Tests
- ✅ `checkWeightedVoting` - Token-weighted voting with different amounts
- ✅ `checkVotingPatterns` - Different voting patterns (unanimous, split)
- ✅ `checkVotingPowerSnapshot` - Voting power snapshot mechanism

#### Treasury Tests
- ✅ `checkTreasuryBalance` - Treasury balance tracking
- ✅ `checkTokenHolderProposal` - Proposal creation by token holders

## Test Architecture

### Remix Test Pattern

Each Remix test contract follows this pattern:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Assert.sol";
import "../../contracts/YourContract.sol";

contract YourContractRemixTest {
    YourContract contractInstance;
    
    /// Setup function
    function beforeAll() public {
        contractInstance = new YourContract();
    }
    
    /// Test function
    function checkFeature() public {
        Assert.equal(
            contractInstance.getValue(),
            expectedValue,
            "Should return expected value"
        );
    }
    
    // Receive ETH if needed
    receive() external payable {}
}
```

### Helper Contracts

System tests use helper contracts to simulate different actors:

```solidity
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
}
```

## Advantages of Remix Tests

1. **Native Solidity**: Tests written in Solidity, same language as contracts
2. **Type Safety**: Compile-time checking of test code
3. **Direct Access**: Direct access to contract internals and state
4. **Gas Measurement**: Can measure gas costs during testing
5. **On-Chain Validation**: Tests run in EVM environment
6. **Familiar Syntax**: Similar to other testing frameworks (JUnit, Mocha, etc.)

## Integration with Existing Tests

The project maintains both test approaches:

| Test Type | Location | Framework | Purpose |
|-----------|----------|-----------|---------|
| Remix Tests | `test/remix/*.sol` | Remix | Solidity-native unit & system tests |
| Hardhat Tests | `test/*.test.js` | Mocha/Chai | JavaScript-based tests with time manipulation |
| Original Solidity Tests | `test/*.t.sol` | Custom | Legacy Solidity tests |

All test approaches complement each other and provide comprehensive coverage.

## Best Practices

### Writing Remix Tests

1. **Use descriptive test names**: `checkFeatureName` or `testFeatureName`
2. **One assertion per test**: Keep tests focused on single functionality
3. **Clear error messages**: Provide descriptive messages in assertions
4. **Setup isolation**: Use `beforeAll()` or `beforeEach()` for clean state
5. **Test independence**: Each test should be independent

### Example Test

```solidity
/// Test that proposal creation increments the count
/// #value: 10000000000000000000
function checkProposalCountIncrement() public payable {
    // Fund treasury
    treasury.deposit{value: msg.value}();
    
    // Get initial count
    uint256 initialCount = treasury.proposalCount();
    
    // Create proposal
    treasury.createProposal(
        address(0x123),
        1 ether,
        "Test proposal"
    );
    
    // Verify count incremented
    Assert.equal(
        treasury.proposalCount(),
        initialCount + 1,
        "Proposal count should increment by 1"
    );
}
```

## Event Verification

The Assert library emits events for all assertions, allowing external tools to track test results:

```solidity
event AssertionEvent(
    bool passed,
    string message,
    string methodName
);

event AssertionEventUint(
    bool passed,
    string message,
    string methodName,
    uint256 returned,
    uint256 expected
);
```

## Debugging Failed Tests

When a Remix test fails:

1. Check the assertion message in the console output
2. Review the `returned` vs `expected` values in event logs
3. Verify test setup in `beforeAll()`
4. Check contract state before assertion
5. Run individual test in isolation

## Extending the Tests

To add new Remix tests:

1. Create new test contract in `test/remix/`
2. Import `Assert.sol` and contract to test
3. Implement `beforeAll()` setup
4. Write test functions with `check` prefix
5. Add to `RemixTests.test.js` runner
6. Run with `npm run test:remix`

Example:

```solidity
// test/remix/NewFeatureRemixTest.sol
import "./Assert.sol";
import "../../contracts/NewFeature.sol";

contract NewFeatureRemixTest {
    NewFeature feature;
    
    function beforeAll() public {
        feature = new NewFeature();
    }
    
    function checkNewFeature() public {
        Assert.ok(
            feature.isEnabled(),
            "Feature should be enabled"
        );
    }
}
```

## Continuous Integration

Remix tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run Remix Tests
  run: npm run test:remix
```

## Conclusion

The Remix test framework provides a robust, Solidity-native way to test smart contracts. With 30 comprehensive tests covering unit and system functionality, the test suite ensures the GovernanceToken and DecentralizedTreasury contracts work correctly in all scenarios.

For questions or issues, refer to:
- Individual test files in `test/remix/`
- This documentation
- [Remix IDE Documentation](https://remix-ide.readthedocs.io/)
