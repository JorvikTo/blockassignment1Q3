// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Assert.sol";
import "../../contracts/GovernanceToken.sol";

/**
 * @title GovernanceTokenRemixTest
 * @dev Unit tests for GovernanceToken using Remix test framework
 * Test naming follows Remix convention with # prefix
 */
contract GovernanceTokenRemixTest {
    GovernanceToken token;
    
    uint256 constant INITIAL_SUPPLY = 10000 * 10**18;
    
    /// #value: 0
    /// #sender: account-0
    function beforeAll() public {
        // Deploy fresh token contract
        token = new GovernanceToken("Governance Token", "GOV", INITIAL_SUPPLY);
    }
    
    /// Test deployment sets correct name
    function checkTokenName() public {
        Assert.equal(token.name(), "Governance Token", "Token name should be 'Governance Token'");
    }
    
    /// Test deployment sets correct symbol
    function checkTokenSymbol() public {
        Assert.equal(token.symbol(), "GOV", "Token symbol should be 'GOV'");
    }
    
    /// Test initial supply is minted to deployer
    function checkInitialSupply() public {
        Assert.equal(token.totalSupply(), INITIAL_SUPPLY, "Total supply should match initial supply");
    }
    
    /// Test deployer receives initial supply
    function checkDeployerBalance() public {
        Assert.equal(token.balanceOf(address(this)), INITIAL_SUPPLY, "Deployer should have initial supply");
    }
    
    /// Test token decimals
    function checkDecimals() public {
        Assert.equal(token.decimals(), 18, "Decimals should be 18");
    }
    
    /// Test owner is set correctly
    function checkOwner() public {
        Assert.equal(token.owner(), address(this), "Owner should be deployer");
    }
    
    /// Test minting new tokens
    function checkMint() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 initialSupply = token.totalSupply();
        address recipient = address(0x1);
        
        token.mint(recipient, mintAmount);
        
        Assert.equal(token.balanceOf(recipient), mintAmount, "Recipient should receive minted tokens");
        Assert.equal(token.totalSupply(), initialSupply + mintAmount, "Total supply should increase by mint amount");
    }
    
    /// Test voting power equals token balance
    function checkVotingPower() public {
        address user = address(0x2);
        uint256 amount = 500 * 10**18;
        
        token.transfer(user, amount);
        
        Assert.equal(token.getVotingPower(user), amount, "Voting power should equal token balance");
    }
    
    /// Test voting power for zero balance
    function checkZeroVotingPower() public {
        address user = address(0x3);
        Assert.equal(token.getVotingPower(user), 0, "Zero balance should have zero voting power");
    }
    
    /// Test token transfer
    function checkTransfer() public {
        address recipient = address(0x4);
        uint256 transferAmount = 1000 * 10**18;
        uint256 initialSenderBalance = token.balanceOf(address(this));
        
        bool success = token.transfer(recipient, transferAmount);
        
        Assert.ok(success, "Transfer should succeed");
        Assert.equal(token.balanceOf(recipient), transferAmount, "Recipient should receive tokens");
        Assert.equal(token.balanceOf(address(this)), initialSenderBalance - transferAmount, "Sender balance should decrease");
    }
    
    /// Test voting power updates after transfer
    function checkVotingPowerUpdate() public {
        address user = address(0x5);
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 500 * 10**18;
        
        token.transfer(user, amount1);
        Assert.equal(token.getVotingPower(user), amount1, "Initial voting power should be correct");
        
        token.transfer(user, amount2);
        Assert.equal(token.getVotingPower(user), amount1 + amount2, "Voting power should update after second transfer");
    }
}
