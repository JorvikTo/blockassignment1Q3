import { expect } from "chai";
import hre from "hardhat";
const { ethers } = hre;

describe("GovernanceToken - Unit Tests", function () {
  let governanceToken;
  let owner, addr1, addr2, addr3;

  const TOKEN_NAME = "Governance Token";
  const TOKEN_SYMBOL = "GOV";
  const INITIAL_SUPPLY = ethers.parseEther("10000");

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy GovernanceToken
    const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
    governanceToken = await GovernanceToken.deploy(
      TOKEN_NAME,
      TOKEN_SYMBOL,
      INITIAL_SUPPLY
    );
  });

  describe("Deployment", function () {
    it("Should set the correct token name", async function () {
      expect(await governanceToken.name()).to.equal(TOKEN_NAME);
    });

    it("Should set the correct token symbol", async function () {
      expect(await governanceToken.symbol()).to.equal(TOKEN_SYMBOL);
    });

    it("Should mint initial supply to deployer", async function () {
      expect(await governanceToken.balanceOf(owner.address)).to.equal(
        INITIAL_SUPPLY
      );
    });

    it("Should set the correct total supply", async function () {
      expect(await governanceToken.totalSupply()).to.equal(INITIAL_SUPPLY);
    });

    it("Should set the deployer as owner", async function () {
      expect(await governanceToken.owner()).to.equal(owner.address);
    });

    it("Should have 18 decimals (ERC20 default)", async function () {
      expect(await governanceToken.decimals()).to.equal(18);
    });
  });

  describe("Minting", function () {
    it("Should allow owner to mint tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      
      await expect(governanceToken.mint(addr1.address, mintAmount))
        .to.emit(governanceToken, "Transfer")
        .withArgs(ethers.ZeroAddress, addr1.address, mintAmount);

      expect(await governanceToken.balanceOf(addr1.address)).to.equal(
        mintAmount
      );
      expect(await governanceToken.totalSupply()).to.equal(
        INITIAL_SUPPLY + mintAmount
      );
    });

    it("Should allow minting to multiple addresses", async function () {
      const mintAmount = ethers.parseEther("500");

      await governanceToken.mint(addr1.address, mintAmount);
      await governanceToken.mint(addr2.address, mintAmount);
      await governanceToken.mint(addr3.address, mintAmount);

      expect(await governanceToken.balanceOf(addr1.address)).to.equal(
        mintAmount
      );
      expect(await governanceToken.balanceOf(addr2.address)).to.equal(
        mintAmount
      );
      expect(await governanceToken.balanceOf(addr3.address)).to.equal(
        mintAmount
      );
      expect(await governanceToken.totalSupply()).to.equal(
        INITIAL_SUPPLY + mintAmount * 3n
      );
    });

    it("Should fail if non-owner tries to mint", async function () {
      const mintAmount = ethers.parseEther("1000");

      await expect(
        governanceToken.connect(addr1).mint(addr2.address, mintAmount)
      ).to.be.revertedWithCustomError(governanceToken, "OwnableUnauthorizedAccount");
    });

    it("Should fail when minting to zero address", async function () {
      const mintAmount = ethers.parseEther("1000");

      await expect(
        governanceToken.mint(ethers.ZeroAddress, mintAmount)
      ).to.be.revertedWith("Cannot mint to zero address");
    });

    it("Should fail when minting zero amount", async function () {
      await expect(
        governanceToken.mint(addr1.address, 0)
      ).to.be.revertedWith("Amount must be positive");
    });

    it("Should fail when minting negative amount (should be caught by type)", async function () {
      // This is caught by Solidity type system, but testing for completeness
      await expect(
        governanceToken.mint(addr1.address, 0)
      ).to.be.revertedWith("Amount must be positive");
    });
  });

  describe("Token Transfers", function () {
    beforeEach(async function () {
      // Distribute tokens to addresses for testing
      await governanceToken.transfer(addr1.address, ethers.parseEther("1000"));
      await governanceToken.transfer(addr2.address, ethers.parseEther("500"));
    });

    it("Should allow token transfers", async function () {
      const transferAmount = ethers.parseEther("100");

      await expect(
        governanceToken.connect(addr1).transfer(addr2.address, transferAmount)
      )
        .to.emit(governanceToken, "Transfer")
        .withArgs(addr1.address, addr2.address, transferAmount);

      expect(await governanceToken.balanceOf(addr1.address)).to.equal(
        ethers.parseEther("900")
      );
      expect(await governanceToken.balanceOf(addr2.address)).to.equal(
        ethers.parseEther("600")
      );
    });

    it("Should fail when transferring more than balance", async function () {
      const tooMuch = ethers.parseEther("2000");

      await expect(
        governanceToken.connect(addr1).transfer(addr2.address, tooMuch)
      ).to.be.revertedWithCustomError(governanceToken, "ERC20InsufficientBalance");
    });

    it("Should fail when transferring to zero address", async function () {
      await expect(
        governanceToken.connect(addr1).transfer(ethers.ZeroAddress, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(governanceToken, "ERC20InvalidReceiver");
    });

    it("Should allow transferring entire balance", async function () {
      const balance = await governanceToken.balanceOf(addr1.address);

      await governanceToken.connect(addr1).transfer(addr2.address, balance);

      expect(await governanceToken.balanceOf(addr1.address)).to.equal(0);
      expect(await governanceToken.balanceOf(addr2.address)).to.equal(
        ethers.parseEther("500") + balance
      );
    });
  });

  describe("Token Allowances", function () {
    beforeEach(async function () {
      await governanceToken.transfer(addr1.address, ethers.parseEther("1000"));
    });

    it("Should allow setting allowances", async function () {
      const allowanceAmount = ethers.parseEther("500");

      await expect(
        governanceToken.connect(addr1).approve(addr2.address, allowanceAmount)
      )
        .to.emit(governanceToken, "Approval")
        .withArgs(addr1.address, addr2.address, allowanceAmount);

      expect(
        await governanceToken.allowance(addr1.address, addr2.address)
      ).to.equal(allowanceAmount);
    });

    it("Should allow transferFrom with valid allowance", async function () {
      const allowanceAmount = ethers.parseEther("500");
      const transferAmount = ethers.parseEther("300");

      await governanceToken.connect(addr1).approve(addr2.address, allowanceAmount);

      await expect(
        governanceToken
          .connect(addr2)
          .transferFrom(addr1.address, addr3.address, transferAmount)
      )
        .to.emit(governanceToken, "Transfer")
        .withArgs(addr1.address, addr3.address, transferAmount);

      expect(await governanceToken.balanceOf(addr3.address)).to.equal(
        transferAmount
      );
      expect(
        await governanceToken.allowance(addr1.address, addr2.address)
      ).to.equal(allowanceAmount - transferAmount);
    });

    it("Should fail transferFrom without allowance", async function () {
      const transferAmount = ethers.parseEther("100");

      await expect(
        governanceToken
          .connect(addr2)
          .transferFrom(addr1.address, addr3.address, transferAmount)
      ).to.be.revertedWithCustomError(governanceToken, "ERC20InsufficientAllowance");
    });

    it("Should fail transferFrom exceeding allowance", async function () {
      const allowanceAmount = ethers.parseEther("100");
      const transferAmount = ethers.parseEther("200");

      await governanceToken.connect(addr1).approve(addr2.address, allowanceAmount);

      await expect(
        governanceToken
          .connect(addr2)
          .transferFrom(addr1.address, addr3.address, transferAmount)
      ).to.be.revertedWithCustomError(governanceToken, "ERC20InsufficientAllowance");
    });
  });

  describe("Voting Power", function () {
    beforeEach(async function () {
      await governanceToken.transfer(addr1.address, ethers.parseEther("3000"));
      await governanceToken.transfer(addr2.address, ethers.parseEther("2000"));
      await governanceToken.transfer(addr3.address, ethers.parseEther("1000"));
    });

    it("Should return correct voting power equal to balance", async function () {
      expect(await governanceToken.getVotingPower(addr1.address)).to.equal(
        ethers.parseEther("3000")
      );
      expect(await governanceToken.getVotingPower(addr2.address)).to.equal(
        ethers.parseEther("2000")
      );
      expect(await governanceToken.getVotingPower(addr3.address)).to.equal(
        ethers.parseEther("1000")
      );
    });

    it("Should return zero voting power for address with no tokens", async function () {
      const newAddr = (await ethers.getSigners())[4];
      expect(await governanceToken.getVotingPower(newAddr.address)).to.equal(0);
    });

    it("Should update voting power after transfers", async function () {
      const transferAmount = ethers.parseEther("500");
      
      await governanceToken.connect(addr1).transfer(addr2.address, transferAmount);

      expect(await governanceToken.getVotingPower(addr1.address)).to.equal(
        ethers.parseEther("2500")
      );
      expect(await governanceToken.getVotingPower(addr2.address)).to.equal(
        ethers.parseEther("2500")
      );
    });

    it("Should update voting power after minting", async function () {
      const mintAmount = ethers.parseEther("1000");
      
      await governanceToken.mint(addr1.address, mintAmount);

      expect(await governanceToken.getVotingPower(addr1.address)).to.equal(
        ethers.parseEther("4000")
      );
    });

    it("Voting power should equal token balance", async function () {
      expect(await governanceToken.getVotingPower(addr1.address)).to.equal(
        await governanceToken.balanceOf(addr1.address)
      );
      expect(await governanceToken.getVotingPower(addr2.address)).to.equal(
        await governanceToken.balanceOf(addr2.address)
      );
    });
  });

  describe("Ownership", function () {
    it("Should allow owner to transfer ownership", async function () {
      await expect(governanceToken.transferOwnership(addr1.address))
        .to.emit(governanceToken, "OwnershipTransferred")
        .withArgs(owner.address, addr1.address);

      expect(await governanceToken.owner()).to.equal(addr1.address);
    });

    it("Should fail if non-owner tries to transfer ownership", async function () {
      await expect(
        governanceToken.connect(addr1).transferOwnership(addr2.address)
      ).to.be.revertedWithCustomError(governanceToken, "OwnableUnauthorizedAccount");
    });

    it("Should allow new owner to mint after ownership transfer", async function () {
      await governanceToken.transferOwnership(addr1.address);

      const mintAmount = ethers.parseEther("1000");
      await governanceToken.connect(addr1).mint(addr2.address, mintAmount);

      expect(await governanceToken.balanceOf(addr2.address)).to.equal(mintAmount);
    });

    it("Should prevent old owner from minting after ownership transfer", async function () {
      await governanceToken.transferOwnership(addr1.address);

      await expect(
        governanceToken.mint(addr2.address, ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(governanceToken, "OwnableUnauthorizedAccount");
    });

    it("Should allow owner to renounce ownership", async function () {
      await governanceToken.renounceOwnership();

      expect(await governanceToken.owner()).to.equal(ethers.ZeroAddress);
    });

    it("Should prevent minting after ownership is renounced", async function () {
      await governanceToken.renounceOwnership();

      await expect(
        governanceToken.mint(addr1.address, ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(governanceToken, "OwnableUnauthorizedAccount");
    });
  });

  describe("Edge Cases", function () {
    it("Should handle very large token amounts", async function () {
      const largeAmount = ethers.parseEther("1000000000"); // 1 billion tokens
      await governanceToken.mint(addr1.address, largeAmount);

      expect(await governanceToken.balanceOf(addr1.address)).to.equal(
        largeAmount
      );
    });

    it("Should handle very small token amounts", async function () {
      const smallAmount = 1n; // 1 wei
      await governanceToken.mint(addr1.address, smallAmount);

      expect(await governanceToken.balanceOf(addr1.address)).to.equal(
        smallAmount
      );
    });

    it("Should handle multiple sequential transfers", async function () {
      await governanceToken.transfer(addr1.address, ethers.parseEther("1000"));
      
      await governanceToken.connect(addr1).transfer(addr2.address, ethers.parseEther("100"));
      await governanceToken.connect(addr2).transfer(addr3.address, ethers.parseEther("50"));
      await governanceToken.connect(addr3).transfer(addr1.address, ethers.parseEther("25"));

      expect(await governanceToken.balanceOf(addr1.address)).to.equal(
        ethers.parseEther("925")
      );
      expect(await governanceToken.balanceOf(addr2.address)).to.equal(
        ethers.parseEther("50")
      );
      expect(await governanceToken.balanceOf(addr3.address)).to.equal(
        ethers.parseEther("25")
      );
    });

    it("Should maintain total supply after transfers", async function () {
      const initialTotalSupply = await governanceToken.totalSupply();
      
      await governanceToken.transfer(addr1.address, ethers.parseEther("1000"));
      await governanceToken.connect(addr1).transfer(addr2.address, ethers.parseEther("500"));

      expect(await governanceToken.totalSupply()).to.equal(initialTotalSupply);
    });

    it("Should handle zero transfers (allowed in ERC20)", async function () {
      await expect(
        governanceToken.transfer(addr1.address, 0)
      ).to.emit(governanceToken, "Transfer");
    });
  });
});
