const hre = require("hardhat");
const fs = require("fs");

/**
 * @title Multi-Chain RWA Vault Deployment
 * @author nbaybt.eth (Donte Lightfoot)
 * @notice Deploy to Ethereum, Base, Hedera, or any EVM chain
 */

// Network-specific configurations
const NETWORK_CONFIGS = {
  // Ethereum
  "mainnet": {
    name: "Ethereum Mainnet",
    explorer: "https://etherscan.io",
    nativeCurrency: "ETH"
  },
  "sepolia": {
    name: "Ethereum Sepolia Testnet",
    explorer: "https://sepolia.etherscan.io",
    nativeCurrency: "ETH"
  },

  // Base (Coinbase L2)
  "base-mainnet": {
    name: "Base Mainnet",
    explorer: "https://basescan.org",
    nativeCurrency: "ETH",
    benefits: "✅ 100x cheaper than Ethereum, Coinbase integration"
  },
  "base-sepolia": {
    name: "Base Sepolia Testnet",
    explorer: "https://sepolia.basescan.org",
    nativeCurrency: "ETH"
  },

  // Hedera
  "hedera-mainnet": {
    name: "Hedera Mainnet",
    explorer: "https://hashscan.io",
    nativeCurrency: "HBAR",
    benefits: "✅ 5000x cheaper than Ethereum, Enterprise-grade"
  },
  "hedera-testnet": {
    name: "Hedera Testnet",
    explorer: "https://hashscan.io/testnet",
    nativeCurrency: "HBAR"
  },

  // Others
  "arbitrum": {
    name: "Arbitrum One",
    explorer: "https://arbiscan.io",
    nativeCurrency: "ETH"
  },
  "optimism": {
    name: "Optimism",
    explorer: "https://optimistic.etherscan.io",
    nativeCurrency: "ETH"
  },
  "polygon": {
    name: "Polygon",
    explorer: "https://polygonscan.com",
    nativeCurrency: "MATIC"
  }
};

async function main() {
  const networkName = hre.network.name;
  const config = NETWORK_CONFIGS[networkName] || { name: networkName, explorer: "Unknown" };

  console.log("═".repeat(80));
  console.log("🚀 MULTI-CHAIN RWA VAULT DEPLOYMENT");
  console.log("═".repeat(80));
  console.log("");
  console.log(`📡 Network: ${config.name}`);
  console.log(`⛓️  Chain ID: ${(await hre.ethers.provider.getNetwork()).chainId}`);
  if (config.benefits) {
    console.log(`💡 Benefits: ${config.benefits}`);
  }
  console.log("");

  const [deployer] = await hre.ethers.getSigners();
  const balance = await deployer.provider.getBalance(deployer.address);

  console.log("👤 Deployer Information:");
  console.log(`   Address: ${deployer.address}`);
  console.log(`   Balance: ${hre.ethers.formatEther(balance)} ${config.nativeCurrency}`);
  console.log(`   ENS: nbaybt.eth`);
  console.log("");

  // Check sufficient balance
  const minBalance = hre.ethers.parseEther("0.1");
  if (balance < minBalance) {
    console.log(`⚠️  WARNING: Low balance! You have ${hre.ethers.formatEther(balance)} ${config.nativeCurrency}`);
    console.log(`   Recommended: At least 0.1 ${config.nativeCurrency}`);
    console.log("");
  }

  console.log("═".repeat(80));
  console.log("📝 DEPLOYING CONTRACTS...");
  console.log("═".repeat(80));
  console.log("");

  // ========================================================================
  // 1. Deploy Price Oracle
  // ========================================================================
  console.log("1️⃣  Deploying PriceOracle...");
  const PriceOracle = await hre.ethers.getContractFactory("PriceOracle");
  const priceOracle = await PriceOracle.deploy(deployer.address);
  await priceOracle.waitForDeployment();
  const priceOracleAddress = await priceOracle.getAddress();
  console.log(`   ✅ PriceOracle: ${priceOracleAddress}`);
  console.log("");

  // ========================================================================
  // 2. Deploy Synthetic PRIM
  // ========================================================================
  console.log("2️⃣  Deploying SyntheticPRIM (sPRIM)...");
  const SyntheticPRIM = await hre.ethers.getContractFactory("SyntheticPRIM");
  const sPRIM = await SyntheticPRIM.deploy(deployer.address);
  await sPRIM.waitForDeployment();
  const sPRIMAddress = await sPRIM.getAddress();
  console.log(`   ✅ SyntheticPRIM: ${sPRIMAddress}`);
  console.log("");

  // ========================================================================
  // 3. Deploy Fractional Shares
  // ========================================================================
  console.log("3️⃣  Deploying FractionalShares (ERC1155)...");
  const FractionalShares = await hre.ethers.getContractFactory("FractionalShares");
  const fractionalShares = await FractionalShares.deploy(
    `https://api.primalrwa.io/${networkName}/metadata/{id}.json`,
    deployer.address
  );
  await fractionalShares.waitForDeployment();
  const fractionalSharesAddress = await fractionalShares.getAddress();
  console.log(`   ✅ FractionalShares: ${fractionalSharesAddress}`);
  console.log("");

  // ========================================================================
  // 4. Deploy Main Vault
  // ========================================================================
  console.log("4️⃣  Deploying PrimalRWAVault...");
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
  console.log(`   ✅ PrimalRWAVault: ${vaultAddress}`);
  console.log("");

  // ========================================================================
  // 5. Deploy US Treasury Module
  // ========================================================================
  console.log("5️⃣  Deploying USTreasuryModule...");
  const USTreasuryModule = await hre.ethers.getContractFactory("USTreasuryModule");
  const treasuryModule = await USTreasuryModule.deploy(deployer.address);
  await treasuryModule.waitForDeployment();
  const treasuryModuleAddress = await treasuryModule.getAddress();
  console.log(`   ✅ USTreasuryModule: ${treasuryModuleAddress}`);
  console.log("");

  // ========================================================================
  // 6. Grant Roles
  // ========================================================================
  console.log("═".repeat(80));
  console.log("🔐 CONFIGURING ROLES...");
  console.log("═".repeat(80));
  console.log("");

  const MINTER_ROLE = await sPRIM.MINTER_ROLE();
  const BURNER_ROLE = await sPRIM.BURNER_ROLE();
  const FRACTIONAL_MINTER = await fractionalShares.MINTER_ROLE();
  const CUSTODIAN_MANAGER = await vault.CUSTODIAN_MANAGER_ROLE();

  await sPRIM.grantRole(MINTER_ROLE, vaultAddress);
  console.log("✅ Granted sPRIM MINTER_ROLE to vault");

  await sPRIM.grantRole(BURNER_ROLE, vaultAddress);
  console.log("✅ Granted sPRIM BURNER_ROLE to vault");

  await fractionalShares.grantRole(FRACTIONAL_MINTER, vaultAddress);
  console.log("✅ Granted FractionalShares MINTER_ROLE to vault");

  await vault.grantRole(CUSTODIAN_MANAGER, deployer.address);
  console.log("✅ Granted vault CUSTODIAN_MANAGER_ROLE to deployer");

  console.log("");

  // ========================================================================
  // 7. Save Deployment Info
  // ========================================================================
  const deploymentInfo = {
    network: networkName,
    networkName: config.name,
    chainId: (await hre.ethers.provider.getNetwork()).chainId.toString(),
    deployer: deployer.address,
    ens: "nbaybt.eth",
    timestamp: new Date().toISOString(),
    explorer: config.explorer,
    contracts: {
      PriceOracle: priceOracleAddress,
      SyntheticPRIM: sPRIMAddress,
      FractionalShares: fractionalSharesAddress,
      PrimalRWAVault: vaultAddress,
      USTreasuryModule: treasuryModuleAddress
    }
  };

  const filename = `deployment-${networkName}-${Date.now()}.json`;
  fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));

  // ========================================================================
  // 8. Summary
  // ========================================================================
  console.log("═".repeat(80));
  console.log("🎉 DEPLOYMENT COMPLETE!");
  console.log("═".repeat(80));
  console.log("");
  console.log("📋 Contract Addresses:");
  console.log(`   PriceOracle:       ${priceOracleAddress}`);
  console.log(`   SyntheticPRIM:     ${sPRIMAddress}`);
  console.log(`   FractionalShares:  ${fractionalSharesAddress}`);
  console.log(`   PrimalRWAVault:    ${vaultAddress}`);
  console.log(`   USTreasuryModule:  ${treasuryModuleAddress}`);
  console.log("");
  console.log(`🔗 Block Explorer: ${config.explorer}`);
  console.log(`👤 Built by: Donte Lightfoot (nbaybt.eth)`);
  console.log("");
  console.log("💾 Deployment saved to:", filename);
  console.log("");

  if (networkName.includes("mainnet")) {
    console.log("⚠️  PRODUCTION DEPLOYMENT CHECKLIST:");
    console.log("   [ ] Replace treasury address with multi-sig");
    console.log("   [ ] Replace admin address with multi-sig/DAO");
    console.log("   [ ] Complete professional security audit");
    console.log("   [ ] Set up monitoring and alerts");
    console.log("   [ ] Configure price oracle feeds");
    console.log("   [ ] Approve initial custodians");
    console.log("   [ ] Certify appraisers");
    console.log("");
  }

  console.log("📝 Verify contracts:");
  console.log(`   npx hardhat verify --network ${networkName} ${vaultAddress} "${sPRIMAddress}" "${fractionalSharesAddress}" "${priceOracleAddress}" "${deployer.address}" "${deployer.address}"`);
  console.log("");
  console.log("═".repeat(80));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
