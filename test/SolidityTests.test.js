import { expect } from "chai";
import hre from "hardhat";
const { ethers } = hre;

/**
 * Integration test that runs the Solidity test suite
 * This demonstrates how to execute Solidity tests from JavaScript
 */
describe("Solidity Test Suite Integration", function () {
  let testRunner;
  let owner;

  before(async function () {
    [owner] = await ethers.getSigners();
  });

  describe("TestRunner Deployment", function () {
    it("Should deploy TestRunner contract", async function () {
      const TestRunner = await ethers.getContractFactory("TestRunner");
      testRunner = await TestRunner.deploy();
      await testRunner.waitForDeployment();

      expect(await testRunner.getAddress()).to.be.properAddress;
    });
  });

  describe("Running Solidity Tests", function () {
    it("Should run all Solidity test suites", async function () {
      this.timeout(120000); // Increase timeout for running all tests

      const TestRunner = await ethers.getContractFactory("TestRunner");
      testRunner = await TestRunner.deploy();
      await testRunner.waitForDeployment();

      // Run all test suites - use staticCall to get return values without sending transaction
      await testRunner.runAllTestSuites();

      console.log("\n=== Solidity Test Suite Results ===");

      // Get individual test suite results
      const suiteCount = await testRunner.getTestSuiteCount();
      console.log(`\nTotal Test Suites: ${suiteCount}`);

      for (let i = 0; i < suiteCount; i++) {
        const [name, passed, failed, total] = await testRunner.getTestSuiteResult(i);
        console.log(`\n${name}:`);
        console.log(`  Passed: ${passed}/${total}`);
        console.log(`  Failed: ${failed}/${total}`);

        // Assert that all tests in this suite passed
        expect(failed).to.equal(
          0n,
          `Test suite "${name}" should have no failures`
        );
      }

      console.log("\n=== All Solidity Tests Passed ===\n");
    });
  });

  describe("Individual Test Suite Execution", function () {
    it("Should run GovernanceToken tests", async function () {
      const GovernanceTokenTest = await ethers.getContractFactory(
        "GovernanceTokenTest"
      );
      const tokenTests = await GovernanceTokenTest.deploy();
      await tokenTests.waitForDeployment();

      const [passed, failed] = await tokenTests.runAllTests();

      console.log(`\nGovernanceToken Tests:`);
      console.log(`  Passed: ${passed}`);
      console.log(`  Failed: ${failed}`);

      expect(failed).to.equal(0n, "All GovernanceToken tests should pass");
    });

    it("Should run DecentralizedTreasury tests", async function () {
      this.timeout(60000); // Increase timeout for treasury tests

      const DecentralizedTreasuryTest = await ethers.getContractFactory(
        "DecentralizedTreasuryTest"
      );
      const treasuryTests = await DecentralizedTreasuryTest.deploy();
      await treasuryTests.waitForDeployment();

      const [passed, failed] = await treasuryTests.runAllTests();

      console.log(`\nDecentralizedTreasury Tests:`);
      console.log(`  Passed: ${passed}`);
      console.log(`  Failed: ${failed}`);

      expect(failed).to.equal(0n, "All DecentralizedTreasury tests should pass");
    });

    it("Should run System tests", async function () {
      this.timeout(60000); // Increase timeout for system tests

      const DecentralizedTreasurySystemTest = await ethers.getContractFactory(
        "DecentralizedTreasurySystemTest"
      );
      const systemTests = await DecentralizedTreasurySystemTest.deploy();
      await systemTests.waitForDeployment();

      const [passed, failed] = await systemTests.runAllTests();

      console.log(`\nSystem Tests:`);
      console.log(`  Passed: ${passed}`);
      console.log(`  Failed: ${failed}`);

      expect(failed).to.equal(0n, "All System tests should pass");
    });
  });

  describe("Individual Test Execution Examples", function () {
    it("Should run individual GovernanceToken test", async function () {
      const GovernanceTokenTest = await ethers.getContractFactory(
        "GovernanceTokenTest"
      );
      const tokenTests = await GovernanceTokenTest.deploy();
      await tokenTests.waitForDeployment();

      // Run a specific test
      const result = await tokenTests.testDeployment();
      expect(result).to.be.true;
    });

    it("Should run individual Treasury test", async function () {
      const DecentralizedTreasuryTest = await ethers.getContractFactory(
        "DecentralizedTreasuryTest"
      );
      const treasuryTests = await DecentralizedTreasuryTest.deploy();
      await treasuryTests.waitForDeployment();

      // Run a specific test
      const result = await treasuryTests.testDeployment();
      expect(result).to.be.true;
    });

    it("Should track test failures correctly", async function () {
      const GovernanceTokenTest = await ethers.getContractFactory(
        "GovernanceTokenTest"
      );
      const tokenTests = await GovernanceTokenTest.deploy();
      await tokenTests.waitForDeployment();

      // Initial counts should be zero
      expect(await tokenTests.testsPassed()).to.equal(0n);
      expect(await tokenTests.testsFailed()).to.equal(0n);

      // Run a test
      await tokenTests.testDeployment();

      // Check that passed count increased
      expect(await tokenTests.testsPassed()).to.be.greaterThan(0n);
    });
  });
});
