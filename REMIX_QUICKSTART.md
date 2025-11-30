# Remix Test Framework - Quick Start Guide

## What is the Remix Test Framework?

The Remix test framework allows you to write unit and system tests for Solidity smart contracts directly in Solidity. This provides a native testing experience with compile-time type checking and direct access to contract internals.

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

This installs:
- `remix-tests` - Remix test runner
- `@remix-project/remix-lib` - Remix library
- All other required dependencies

### 2. Run Remix Tests

```bash
npm run test:remix
```

This runs all 30 Remix framework tests:
- 11 GovernanceToken unit tests
- 11 DecentralizedTreasury unit tests
- 8 System integration tests

### 3. View Test Results

The test runner will display:
```
Remix Test Framework - Solidity Tests
  GovernanceToken Remix Tests
    ✓ Should deploy GovernanceTokenRemixTest contract
    ✓ Should run beforeAll setup
    ✓ Should check token name
    ✓ Should check token symbol
    ... (30 total tests)
```

## Test Structure

### Remix Test Files

Located in `test/remix/`:

```
test/remix/
├── Assert.sol                          # Assertion library
├── GovernanceTokenRemixTest.sol        # Token unit tests
├── DecentralizedTreasuryRemixTest.sol  # Treasury unit tests
└── TreasurySystemRemixTest.sol         # System tests
```

### Example Remix Test

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Assert.sol";
import "../../contracts/GovernanceToken.sol";

contract GovernanceTokenRemixTest {
    GovernanceToken token;
    
    /// Setup - runs once before all tests
    function beforeAll() public {
        token = new GovernanceToken("Test Token", "TST", 10000);
    }
    
    /// Test token name
    function checkTokenName() public {
        Assert.equal(
            token.name(),
            "Test Token",
            "Token name should match"
        );
    }
    
    /// Test token symbol
    function checkTokenSymbol() public {
        Assert.equal(
            token.symbol(),
            "TST",
            "Token symbol should match"
        );
    }
}
```

## Available Assertions

### Boolean Assertions

```solidity
Assert.ok(condition, "message");
```

### Equality Assertions

```solidity
Assert.equal(actual, expected, "message");
Assert.notEqual(actual, expected, "message");
```

Supported types:
- `uint256`, `int256`
- `bool`
- `address`
- `bytes32`
- `string`

### Comparison Assertions

```solidity
Assert.greaterThan(a, b, "message");
Assert.lesserThan(a, b, "message");
```

## Writing Your Own Tests

### Step 1: Create Test File

Create `test/remix/MyContractRemixTest.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Assert.sol";
import "../../contracts/MyContract.sol";

contract MyContractRemixTest {
    MyContract myContract;
    
    function beforeAll() public {
        myContract = new MyContract();
    }
    
    function checkInitialState() public {
        Assert.equal(
            myContract.value(),
            0,
            "Initial value should be 0"
        );
    }
}
```

### Step 2: Add to Test Runner

Edit `test/RemixTests.test.js` and add:

```javascript
describe("MyContract Remix Tests", function () {
  let testContract;

  it("Should deploy MyContractRemixTest", async function () {
    const TestContract = await ethers.getContractFactory(
      "MyContractRemixTest"
    );
    testContract = await TestContract.deploy();
    await testContract.waitForDeployment();
  });

  it("Should run beforeAll setup", async function () {
    await testContract.beforeAll();
  });

  it("Should check initial state", async function () {
    await testContract.checkInitialState();
  });
});
```

### Step 3: Run Tests

```bash
npm run test:remix
```

## Test Naming Conventions

### Function Names

- **Setup**: `beforeAll()` or `beforeEach()`
- **Tests**: Start with `check` or `test`
  - `checkTokenName()`
  - `testVotingPower()`
  - `checkProposalCreation()`

### Comments

Use `///` for test descriptions:

```solidity
/// Test that tokens can be minted
function checkMinting() public {
    // Test code
}
```

Use `/// #value:` to specify ETH value:

```solidity
/// Fund the treasury
/// #value: 10000000000000000000
function checkDeposit() public payable {
    treasury.deposit{value: msg.value}();
}
```

## Common Patterns

### Testing with ETH

```solidity
/// #value: 10000000000000000000
function checkEthTransfer() public payable {
    contract.deposit{value: msg.value}();
    Assert.equal(
        contract.balance(),
        msg.value,
        "Balance should match deposit"
    );
}
```

### Testing Events (via State)

Since Remix tests can't easily check events, verify state changes:

```solidity
function checkVotingUpdatesState() public {
    uint256 beforeVotes = treasury.getVotesFor(proposalId);
    treasury.vote(proposalId, true);
    uint256 afterVotes = treasury.getVotesFor(proposalId);
    
    Assert.greaterThan(
        afterVotes,
        beforeVotes,
        "Votes should increase"
    );
}
```

### Testing Reverts

Use try-catch for revert testing:

```solidity
function checkRevert() public {
    try contract.restrictedFunction() {
        Assert.ok(false, "Should have reverted");
    } catch {
        Assert.ok(true, "Correctly reverted");
    }
}
```

### Using Helper Contracts

```solidity
contract VoterHelper {
    DecentralizedTreasury treasury;
    
    constructor(DecentralizedTreasury _treasury) {
        treasury = _treasury;
    }
    
    function vote(uint256 id, bool support) external {
        treasury.vote(id, support);
    }
}

contract SystemTest {
    function checkMultipleVoters() public {
        VoterHelper voter1 = new VoterHelper(treasury);
        VoterHelper voter2 = new VoterHelper(treasury);
        
        // Use helpers to simulate different voters
    }
}
```

## Debugging Tests

### View Test Output

All tests output results to console. Look for:
- ✓ Passed tests (green checkmarks)
- ✗ Failed tests (red X marks)
- Error messages from assertions

### Common Issues

1. **Import errors**: Check file paths in import statements
2. **Compilation errors**: Verify Solidity syntax
3. **Assertion failures**: Check expected vs actual values
4. **Out of gas**: Increase gas limit in hardhat.config.js

### Running Individual Tests

To run a specific test suite, edit `RemixTests.test.js`:

```javascript
describe.only("GovernanceToken Remix Tests", function () {
    // Only this suite will run
});
```

## Best Practices

1. **Keep tests focused**: One concept per test function
2. **Use descriptive names**: `checkTokenTransferUpdatesBalances` not `test1`
3. **Clear assertions**: Provide meaningful error messages
4. **Independent tests**: Each test should work in isolation
5. **Clean state**: Use `beforeAll()` to reset state

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Remix Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'
      - run: npm install
      - run: npm run test:remix
```

## Comparison with Other Test Frameworks

| Feature | Remix Tests | Hardhat Tests | Forge Tests |
|---------|------------|---------------|-------------|
| Language | Solidity | JavaScript | Solidity |
| Type Safety | ✓ | ✗ | ✓ |
| Time Travel | ✗ | ✓ | ✓ |
| Event Testing | Limited | ✓ | ✓ |
| Gas Reports | ✓ | ✓ | ✓ |
| Setup | Simple | Medium | Medium |

## Next Steps

1. **Read Full Documentation**: See `REMIX_TESTS.md`
2. **Study Examples**: Review tests in `test/remix/`
3. **Write Tests**: Create tests for your contracts
4. **Run Tests**: Use `npm run test:remix`
5. **Iterate**: Refine based on results

## Getting Help

- **Documentation**: `REMIX_TESTS.md`
- **Examples**: `test/remix/*.sol`
- **Remix IDE Docs**: https://remix-ide.readthedocs.io/
- **Hardhat Docs**: https://hardhat.org/

## Summary

The Remix test framework provides a powerful, Solidity-native way to test smart contracts:

- ✅ **30 comprehensive tests** covering unit and system functionality
- ✅ **Type-safe** testing with compile-time checks
- ✅ **Easy to use** with familiar assertion syntax
- ✅ **Direct access** to contract internals
- ✅ **Well documented** with examples and guides

Start testing with:
```bash
npm run test:remix
```

Happy testing! 🎉
