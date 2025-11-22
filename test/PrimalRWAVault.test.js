const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * @title Primal RWA Vault Test Suite
 * @author nbaybt.eth (Donte Lightfoot)
 * @notice Comprehensive tests for the RWA tokenization system
 */
describe("Primal RWA Vault System", function () {
  let vault, sPRIM, fractionalShares, priceOracle;
  let owner, custodian, appraiser, investor1, investor2, treasury;

  beforeEach(async function () {
    [owner, custodian, appraiser, investor1, investor2, treasury] = await ethers.getSigners();

    // Deploy PriceOracle
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    priceOracle = await PriceOracle.deploy(owner.address);

    // Deploy SyntheticPRIM
    const SyntheticPRIM = await ethers.getContractFactory("SyntheticPRIM");
    sPRIM = await SyntheticPRIM.deploy(owner.address);

    // Deploy FractionalShares
    const FractionalShares = await ethers.getContractFactory("FractionalShares");
    fractionalShares = await FractionalShares.deploy(
      "https://api.primalrwa.io/metadata/{id}.json",
      owner.address
    );

    // Deploy Vault
    const PrimalRWAVault = await ethers.getContractFactory("PrimalRWAVault");
    vault = await PrimalRWAVault.deploy(
      await sPRIM.getAddress(),
      await fractionalShares.getAddress(),
      await priceOracle.getAddress(),
      treasury.address,
      owner.address
    );

    const vaultAddress = await vault.getAddress();

    // Grant roles
    const MINTER_ROLE = await sPRIM.MINTER_ROLE();
    const BURNER_ROLE = await sPRIM.BURNER_ROLE();
    await sPRIM.grantRole(MINTER_ROLE, vaultAddress);
    await sPRIM.grantRole(BURNER_ROLE, vaultAddress);

    const FRACTIONAL_MINTER = await fractionalShares.MINTER_ROLE();
    await fractionalShares.grantRole(FRACTIONAL_MINTER, vaultAddress);

    // Setup vault roles
    const CUSTODIAN_MANAGER_ROLE = await vault.CUSTODIAN_MANAGER_ROLE();
    await vault.grantRole(CUSTODIAN_MANAGER_ROLE, owner.address);

    // Approve custodian
    await vault.approveCustodian(
      custodian.address,
      "Brinks Vault Services",
      ethers.id("CERT123")
    );

    // Certify appraiser
    await vault.certifyAppraiser(appraiser.address);
  });

  describe("Asset Deposit & Verification", function () {
    it("Should deposit asset successfully", async function () {
      const tx = await vault.connect(investor1).depositAsset(
        0, // PRECIOUS_METALS
        "1kg Gold Bar",
        "LBMA certified gold bar",
        "Brinks Vault, NYC",
        ethers.id("GOLD123"),
        custodian.address,
        ethers.parseEther("60000") // $60,000 USD
      );

      await expect(tx).to.emit(vault, "AssetDeposited");

      const asset = await vault.assets(1);
      expect(asset.owner).to.equal(investor1.address);
      expect(asset.assetType).to.equal("1kg Gold Bar");
    });

    it("Should verify asset by certified appraiser", async function () {
      await vault.connect(investor1).depositAsset(
        0, "1kg Gold Bar", "LBMA gold", "NYC", ethers.id("GOLD123"),
        custodian.address, ethers.parseEther("60000")
      );

      const tx = await vault.connect(appraiser).verifyAsset(
        1,
        ethers.parseEther("60000"),
        ethers.id("LEGAL_DOC"),
        "NY, USA"
      );

      await expect(tx).to.emit(vault, "AssetVerified");

      const asset = await vault.assets(1);
      expect(asset.status).to.equal(1); // VERIFIED
    });
  });

  describe("Asset Tokenization", function () {
    beforeEach(async function () {
      await vault.connect(investor1).depositAsset(
        0, "1kg Gold Bar", "LBMA gold", "NYC", ethers.id("GOLD123"),
        custodian.address, ethers.parseEther("60000")
      );

      await vault.connect(appraiser).verifyAsset(
        1, ethers.parseEther("60000"), ethers.id("LEGAL"), "NY"
      );
    });

    it("Should tokenize asset and mint sPRIM", async function () {
      const tx = await vault.connect(investor1).tokenizeAsset(1, 100); // 1:1 ratio

      await expect(tx).to.emit(vault, "AssetTokenized");

      const asset = await vault.assets(1);
      expect(asset.status).to.equal(2); // TOKENIZED
      expect(asset.locked).to.be.true; // ✅ COLLATERAL LOCKED

      // Check sPRIM was minted
      const balance = await sPRIM.balanceOf(investor1.address);
      expect(balance).to.be.gt(0);
    });

    it("Should prevent redemption without full sPRIM balance", async function () {
      await vault.connect(investor1).tokenizeAsset(1, 100);

      // Transfer some sPRIM away
      const balance = await sPRIM.balanceOf(investor1.address);
      await sPRIM.connect(investor1).transfer(investor2.address, balance / 2n);

      // Try to redeem (should fail)
      await expect(
        vault.connect(investor1).redeemAsset(1)
      ).to.be.revertedWith("Insufficient sPRIM");
    });
  });

  describe("Fractionalization", function () {
    beforeEach(async function () {
      await vault.connect(investor1).depositAsset(
        1, "Luxury Penthouse", "3BR NYC penthouse", "Manhattan", ethers.id("RE123"),
        custodian.address, ethers.parseEther("10000000") // $10M
      );

      await vault.connect(appraiser).verifyAsset(
        1, ethers.parseEther("10000000"), ethers.id("DEED"), "NY"
      );

      await vault.connect(investor1).tokenizeAsset(1, 100);
    });

    it("Should fractionalize expensive asset", async function () {
      const tx = await vault.connect(investor1).fractionalizeAsset(1, 1000); // 1000 shares

      await expect(tx).to.emit(vault, "AssetFractionalized");

      const asset = await vault.assets(1);
      expect(asset.fractionalized).to.be.true;
      expect(asset.totalShares).to.equal(1000);

      // Check ERC1155 shares were minted
      const fractionalTokenId = asset.fractionalTokenId;
      const balance = await fractionalShares.balanceOf(investor1.address, fractionalTokenId);
      expect(balance).to.equal(1000);
    });
  });

  describe("Fee Management", function () {
    beforeEach(async function () {
      await vault.connect(investor1).depositAsset(
        0, "Gold Bar", "1kg", "NYC", ethers.id("G1"),
        custodian.address, ethers.parseEther("60000")
      );

      await vault.connect(appraiser).verifyAsset(
        1, ethers.parseEther("60000"), ethers.id("L1"), "NY"
      );

      await vault.connect(investor1).tokenizeAsset(1, 100);
    });

    it("Should collect tokenization fees", async function () {
      const fees = await vault.collectedFees();
      expect(fees).to.be.gt(0); // Fee was collected
    });

    it("Should allow governance to withdraw fees", async function () {
      const fees = await vault.collectedFees();
      expect(fees).to.be.gt(0);

      await vault.withdrawFees();

      const newFees = await vault.collectedFees();
      expect(newFees).to.equal(0);
    });
  });

  describe("Security Features", function () {
    it("Should prevent unauthorized appraiser actions", async function () {
      await vault.connect(investor1).depositAsset(
        0, "Gold", "1kg", "NYC", ethers.id("G1"),
        custodian.address, ethers.parseEther("60000")
      );

      // Investor tries to verify (should fail)
      await expect(
        vault.connect(investor1).verifyAsset(
          1, ethers.parseEther("60000"), ethers.id("L"), "NY"
        )
      ).to.be.reverted;
    });

    it("Should pause in emergency", async function () {
      const EMERGENCY_ROLE = await vault.EMERGENCY_ROLE();
      await vault.grantRole(EMERGENCY_ROLE, owner.address);

      await vault.pause();

      // Try to deposit (should fail)
      await expect(
        vault.connect(investor1).depositAsset(
          0, "Gold", "1kg", "NYC", ethers.id("G1"),
          custodian.address, ethers.parseEther("60000")
        )
      ).to.be.reverted;
    });
  });

  describe("Vault Statistics", function () {
    it("Should track total value locked", async function () {
      await vault.connect(investor1).depositAsset(
        0, "Gold", "1kg", "NYC", ethers.id("G1"),
        custodian.address, ethers.parseEther("60000")
      );

      await vault.connect(appraiser).verifyAsset(
        1, ethers.parseEther("60000"), ethers.id("L"), "NY"
      );

      await vault.connect(investor1).tokenizeAsset(1, 100);

      const stats = await vault.getVaultStats();
      expect(stats.totalValue).to.equal(ethers.parseEther("60000"));
      expect(stats.totalAssets).to.equal(1);
    });
  });
});
