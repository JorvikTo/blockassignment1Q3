// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GovernanceToken.t.sol";
import "./DecentralizedTreasury.t.sol";
import "./DecentralizedTreasurySystem.t.sol";

/**
 * @title TestRunner
 * @dev Main test runner contract that executes all Solidity tests
 * Provides a comprehensive overview of test results across all test suites
 */
contract TestRunner {
    GovernanceTokenTest public tokenTests;
    DecentralizedTreasuryTest public treasuryTests;
    DecentralizedTreasurySystemTest public systemTests;
    
    struct TestSuiteResult {
        string name;
        uint256 passed;
        uint256 failed;
        uint256 total;
    }
    
    TestSuiteResult[] public results;
    
    /**
     * @dev Run all test suites and collect results
     */
    function runAllTestSuites() public returns (
        uint256 totalPassed,
        uint256 totalFailed,
        uint256 totalTests
    ) {
        // Clear previous results
        delete results;
        
        // Deploy and run GovernanceToken tests
        tokenTests = new GovernanceTokenTest();
        (uint256 tokenPassed, uint256 tokenFailed) = tokenTests.runAllTests();
        
        results.push(TestSuiteResult({
            name: "GovernanceToken Unit Tests",
            passed: tokenPassed,
            failed: tokenFailed,
            total: tokenPassed + tokenFailed
        }));
        
        // Deploy and run DecentralizedTreasury tests
        treasuryTests = new DecentralizedTreasuryTest();
        (uint256 treasuryPassed, uint256 treasuryFailed) = treasuryTests.runAllTests();
        
        results.push(TestSuiteResult({
            name: "DecentralizedTreasury Unit Tests",
            passed: treasuryPassed,
            failed: treasuryFailed,
            total: treasuryPassed + treasuryFailed
        }));
        
        // Deploy and run System tests
        systemTests = new DecentralizedTreasurySystemTest();
        (uint256 systemPassed, uint256 systemFailed) = systemTests.runAllTests();
        
        results.push(TestSuiteResult({
            name: "System Integration Tests",
            passed: systemPassed,
            failed: systemFailed,
            total: systemPassed + systemFailed
        }));
        
        // Calculate totals
        totalPassed = tokenPassed + treasuryPassed + systemPassed;
        totalFailed = tokenFailed + treasuryFailed + systemFailed;
        totalTests = totalPassed + totalFailed;
        
        return (totalPassed, totalFailed, totalTests);
    }
    
    /**
     * @dev Get results for a specific test suite
     */
    function getTestSuiteResult(uint256 index) public view returns (
        string memory name,
        uint256 passed,
        uint256 failed,
        uint256 total
    ) {
        require(index < results.length, "Invalid index");
        TestSuiteResult memory result = results[index];
        return (result.name, result.passed, result.failed, result.total);
    }
    
    /**
     * @dev Get number of test suites
     */
    function getTestSuiteCount() public view returns (uint256) {
        return results.length;
    }
}
