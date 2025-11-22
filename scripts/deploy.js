const hre = require("hardhat");

/**
 * @title Primal RWA Vault Deployment Script
 * @author nbaybt.eth (Donte Lightfoot)
 * @notice Deploys the complete RWA tokenization system
 */
async function main() {
  console.log("🚀 Deploying Primal RWA Vault System...");
  console.log("=" .repeat(60));

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deploying from:", deployer.address);
  console.log("💰 Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());
  console.log("");

  // ========================================================================
  // 1. Deploy Price Oracle
  // ========================================================================
  console.log("📊 Deploying PriceOracle...");
  const PriceOracle = await hre.ethers.getContractFactory("PriceOracle");
  const priceOracle = await PriceOracle.deploy(deployer.address);
  await priceOracle.waitForDeployment();
  const priceOracleAddress = await priceOracle.getAddress();
  console.log("✅ PriceOracle deployed to:", priceOracleAddress);
  console.log("");

  // ========================================================================
  // 2. Deploy Synthetic PRIM Token
  // ========================================================================
  console.log("💎 Deploying SyntheticPRIM (sPRIM)...");
  const SyntheticPRIM = await hre.ethers.getContractFactory("SyntheticPRIM");
  const sPRIM = await SyntheticPRIM.deploy(deployer.address);
  await sPRIM.waitForDeployment();
  const sPRIMAddress = await sPRIM.getAddress();
  console.log("✅ SyntheticPRIM deployed to:", sPRIMAddress);
  console.log("");

  // ========================================================================
  // 3. Deploy Fractional Shares
  // ========================================================================
  console.log("🧩 Deploying FractionalShares...");
  const FractionalShares = await hre.ethers.getContractFactory("FractionalShares");
  const fractionalShares = await FractionalShares.deploy(
    "https://api.primalrwa.io/metadata/{id}.json", // Metadata URI
    deployer.address
  );
  await fractionalShares.waitForDeployment();
  const fractionalSharesAddress = await fractionalShares.getAddress();
  console.log("✅ FractionalShares deployed to:", fractionalSharesAddress);
  console.log("");

  // ========================================================================
  // 4. Deploy Main Vault
  // ========================================================================
  console.log("🏦 Deploying PrimalRWAVault...");
  const PrimalRWAVault = await hre.ethers.getContractFactory("PrimalRWAVault");
  const vault = await PrimalRWAVault.deploy(
    sPRIMAddress,
    fractionalSharesAddress,
    priceOracleAddress,
    deployer.address, // Treasury (use multi-sig in production)
    deployer.address  // Admin (use multi-sig in production)
  );
  await vault.waitForDeployment();
  const vaultAddress = await vault.getAddress();
  console.log("✅ PrimalRWAVault deployed to:", vaultAddress);
  console.log("");

  // ========================================================================
  // 5. Grant Roles
  // ========================================================================
  console.log("🔐 Granting roles...");

  // Grant MINTER_ROLE to vault for sPRIM
  const MINTER_ROLE = await sPRIM.MINTER_ROLE();
  const BURNER_ROLE = await sPRIM.BURNER_ROLE();
  await sPRIM.grantRole(MINTER_ROLE, vaultAddress);
  await sPRIM.grantRole(BURNER_ROLE, vaultAddress);
  console.log("✅ Granted sPRIM roles to vault");

  // Grant MINTER_ROLE to vault for fractional shares
  const FRACTIONAL_MINTER_ROLE = await fractionalShares.MINTER_ROLE();
  await fractionalShares.grantRole(FRACTIONAL_MINTER_ROLE, vaultAddress);
  console.log("✅ Granted FractionalShares roles to vault");

  // Grant CUSTODIAN_MANAGER_ROLE to deployer (temporary)
  const CUSTODIAN_MANAGER_ROLE = await vault.CUSTODIAN_MANAGER_ROLE();
  await vault.grantRole(CUSTODIAN_MANAGER_ROLE, deployer.address);
  console.log("✅ Granted vault management roles");
  console.log("");

  // ========================================================================
  // 6. Setup Example Price Feeds (if on testnet)
  // ========================================================================
  const chainId = (await hre.ethers.provider.getNetwork()).chainId;

  if (chainId === 11155111n) { // Sepolia
    console.log("🌐 Setting up Chainlink price feeds (Sepolia testnet)...");

    // Sepolia Chainlink feeds
    const GOLD_FEED = "0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea"; // Gold example
    const ETH_USD_FEED = "0x694AA1769357215DE4FAC081bf1f309aDC325306";

    const ORACLE_MANAGER_ROLE = await priceOracle.ORACLE_MANAGER_ROLE();
    await priceOracle.grantRole(ORACLE_MANAGER_ROLE, deployer.address);

    // Add gold price feed
    const goldAssetType = await priceOracle.getAssetTypeId("GOLD");
    await priceOracle.addPriceFeed(goldAssetType, GOLD_FEED);
    console.log("✅ Added GOLD price feed");
    console.log("");
  }

  // ========================================================================
  // 7. Summary
  // ========================================================================
  console.log("=" .repeat(60));
  console.log("🎉 DEPLOYMENT COMPLETE!");
  console.log("=" .repeat(60));
  console.log("");
  console.log("📋 Contract Addresses:");
  console.log("  PriceOracle:       ", priceOracleAddress);
  console.log("  SyntheticPRIM:     ", sPRIMAddress);
  console.log("  FractionalShares:  ", fractionalSharesAddress);
  console.log("  PrimalRWAVault:    ", vaultAddress);
  console.log("");
  console.log("🔗 ENS Domain: nbaybt.eth");
  console.log("👤 Built by: Donte Lightfoot");
  console.log("");
  console.log("⚠️  IMPORTANT:");
  console.log("  1. Replace treasury address with multi-sig");
  console.log("  2. Replace admin address with multi-sig or DAO");
  console.log("  3. Get professional security audit before mainnet");
  console.log("  4. Set up proper monitoring and alerts");
  console.log("");
  console.log("📝 Next steps:");
  console.log("  1. Approve custodians");
  console.log("  2. Certify appraisers");
  console.log("  3. Configure insurance providers");
  console.log("  4. Start depositing assets");
  console.log("");
  console.log("💡 Verify contracts on Etherscan:");
  console.log(`  npx hardhat verify --network ${hre.network.name} ${vaultAddress} "${sPRIMAddress}" "${fractionalSharesAddress}" "${priceOracleAddress}" "${deployer.address}" "${deployer.address}"`);
  console.log("");

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    chainId: chainId.toString(),
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      PriceOracle: priceOracleAddress,
      SyntheticPRIM: sPRIMAddress,
      FractionalShares: fractionalSharesAddress,
      PrimalRWAVault: vaultAddress
    }
  };

  const fs = require("fs");
  fs.writeFileSync(
    `deployment-${hre.network.name}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log(`💾 Deployment info saved to deployment-${hre.network.name}.json`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
