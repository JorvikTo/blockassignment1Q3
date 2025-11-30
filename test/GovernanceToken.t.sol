// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/GovernanceToken.sol";

/**
 * @title GovernanceTokenTest
 * @dev Comprehensive unit tests for the GovernanceToken contract
 * This contract contains tests that can be executed to validate GovernanceToken functionality
 */
contract GovernanceTokenTest {
    GovernanceToken public token;
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant INITIAL_SUPPLY = 10000 * 10**18;
    
    // Events to verify
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    // Test result tracking
    uint256 public testsPassed;
    uint256 public testsFailed;
    string public lastError;
    
    constructor() {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
    }
    
    /**
     * @dev Setup function to deploy a fresh token contract before each test batch
     */
    function setUp() public {
        token = new GovernanceToken("Test Governance Token", "TGT", INITIAL_SUPPLY);
    }
    
    /**
     * @dev Test 1: Deployment should set correct name and symbol
     */
    function testDeployment() public returns (bool) {
        setUp();
        
        if (keccak256(bytes(token.name())) != keccak256(bytes("Test Governance Token"))) {
            lastError = "Name incorrect";
            testsFailed++;
            return false;
        }
        
        if (keccak256(bytes(token.symbol())) != keccak256(bytes("TGT"))) {
            lastError = "Symbol incorrect";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 2: Initial supply should be minted to deployer
     */
    function testInitialSupply() public returns (bool) {
        setUp();
        
        if (token.totalSupply() != INITIAL_SUPPLY) {
            lastError = "Total supply incorrect";
            testsFailed++;
            return false;
        }
        
        if (token.balanceOf(address(this)) != INITIAL_SUPPLY) {
            lastError = "Deployer balance incorrect";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 3: Owner should be able to mint new tokens
     */
    function testMint() public returns (bool) {
        setUp();
        
        uint256 mintAmount = 1000 * 10**18;
        uint256 initialSupply = token.totalSupply();
        
        token.mint(user1, mintAmount);
        
        if (token.balanceOf(user1) != mintAmount) {
            lastError = "Mint amount incorrect";
            testsFailed++;
            return false;
        }
        
        if (token.totalSupply() != initialSupply + mintAmount) {
            lastError = "Total supply not updated correctly";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 4: Minting to zero address should fail
     */
    function testMintToZeroAddress() public returns (bool) {
        setUp();
        
        try token.mint(address(0), 1000 * 10**18) {
            lastError = "Should not allow minting to zero address";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Cannot mint to zero address"))) {
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
     * @dev Test 5: Minting zero amount should fail
     */
    function testMintZeroAmount() public returns (bool) {
        setUp();
        
        try token.mint(user1, 0) {
            lastError = "Should not allow minting zero amount";
            testsFailed++;
            return false;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) != keccak256(bytes("Amount must be positive"))) {
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
     * @dev Test 6: Token transfer should work correctly
     */
    function testTransfer() public returns (bool) {
        setUp();
        
        uint256 transferAmount = 1000 * 10**18;
        uint256 initialBalance = token.balanceOf(address(this));
        
        bool success = token.transfer(user1, transferAmount);
        
        if (!success) {
            lastError = "Transfer failed";
            testsFailed++;
            return false;
        }
        
        if (token.balanceOf(user1) != transferAmount) {
            lastError = "Recipient balance incorrect";
            testsFailed++;
            return false;
        }
        
        if (token.balanceOf(address(this)) != initialBalance - transferAmount) {
            lastError = "Sender balance incorrect";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 7: Get voting power should return token balance
     */
    function testGetVotingPower() public returns (bool) {
        setUp();
        
        uint256 transferAmount = 500 * 10**18;
        token.transfer(user1, transferAmount);
        
        if (token.getVotingPower(user1) != transferAmount) {
            lastError = "Voting power should equal balance";
            testsFailed++;
            return false;
        }
        
        if (token.getVotingPower(user2) != 0) {
            lastError = "Zero balance should have zero voting power";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 8: Voting power should update after transfers
     */
    function testVotingPowerUpdates() public returns (bool) {
        setUp();
        
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 500 * 10**18;
        
        token.transfer(user1, amount1);
        
        if (token.getVotingPower(user1) != amount1) {
            lastError = "Initial voting power incorrect";
            testsFailed++;
            return false;
        }
        
        token.transfer(user1, amount2);
        
        if (token.getVotingPower(user1) != amount1 + amount2) {
            lastError = "Voting power not updated after second transfer";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 9: Owner address should be set correctly
     */
    function testOwner() public returns (bool) {
        setUp();
        
        if (token.owner() != address(this)) {
            lastError = "Owner not set correctly";
            testsFailed++;
            return false;
        }
        
        testsPassed++;
        return true;
    }
    
    /**
     * @dev Test 10: ERC20 decimals should be 18
     */
    function testDecimals() public returns (bool) {
        setUp();
        
        if (token.decimals() != 18) {
            lastError = "Decimals should be 18";
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
        testInitialSupply();
        testMint();
        testMintToZeroAddress();
        testMintZeroAmount();
        testTransfer();
        testGetVotingPower();
        testVotingPowerUpdates();
        testOwner();
        testDecimals();
        
        return (testsPassed, testsFailed);
    }
}
