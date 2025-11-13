// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovernanceToken
 * @dev ERC20 token with voting power capabilities for treasury governance
 * Token balance determines voting power in the DAO (1 token = 1 vote)
 * Uses ERC20 standard for enhanced security and compatibility
 */
contract GovernanceToken is ERC20, Ownable {
    /**
     * @dev Constructor - Initializes the governance token
     * Mints initial supply to deployer who can distribute to DAO members
     * @param name Token name (e.g., "Treasury Governance Token")
     * @param symbol Token symbol (e.g., "TGT")
     * @param initialSupply Initial token supply to mint to deployer
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        // Mint initial supply to deployer for distribution
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Mint new tokens (only owner can mint)
     * Allows controlled expansion of voting power distribution
     * @param to Address to receive newly minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be positive");
        _mint(to, amount);
    }

    /**
     * @dev Get voting power of an account
     * Voting power equals token balance (1 token = 1 vote)
     * @param account Address to check voting power for
     * @return Voting power (equal to token balance)
     */
    function getVotingPower(address account) external view returns (uint256) {
        return balanceOf(account);
    }
}
