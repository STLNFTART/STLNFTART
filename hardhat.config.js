require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/**
 * @title Multi-Chain Hardhat Configuration
 * @notice Supports Ethereum, Base (Coinbase L2), Hedera, and more
 * @dev Built by nbaybt.eth | 314lightfoot.hbar
 */

// Helper to validate private key
function getAccounts() {
  const pk = process.env.PRIVATE_KEY || process.env.HEDERA_PRIVATE_KEY;
  // Only use if it's a valid length (64 chars for 32 bytes)
  if (pk && pk.length === 64) {
    return [pk];
  }
  // Also accept with 0x prefix
  if (pk && pk.startsWith('0x') && pk.length === 66) {
    return [pk];
  }
  return []; // Return empty array for compilation without deployment
}

const accounts = getAccounts();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    // Local development
    hardhat: {
      chainId: 31337,
    },

    // ========================================================================
    // ETHEREUM NETWORKS
    // ========================================================================
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      accounts: accounts,
      chainId: 11155111,
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "https://eth.llamarpc.com",
      accounts: accounts,
      chainId: 1,
    },

    // ========================================================================
    // BASE (COINBASE L2) - RECOMMENDED FOR LOW FEES
    // ========================================================================
    "base-sepolia": {
      url: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
      accounts: accounts,
      chainId: 84532,
      gasPrice: 1000000000, // 1 gwei
    },
    "base-mainnet": {
      url: process.env.BASE_MAINNET_RPC_URL || "https://mainnet.base.org",
      accounts: accounts,
      chainId: 8453,
      gasPrice: 1000000000, // 1 gwei
    },

    // ========================================================================
    // HEDERA HASHGRAPH - ENTERPRISE-GRADE, ULTRA LOW FEES
    // ========================================================================
    "hedera-testnet": {
      url: process.env.HEDERA_TESTNET_RPC_URL || "https://testnet.hashio.io/api",
      accounts: accounts,
      chainId: 296, // Hedera testnet
    },
    "hedera-mainnet": {
      url: process.env.HEDERA_MAINNET_RPC_URL || "https://mainnet.hashio.io/api",
      accounts: accounts,
      chainId: 295, // Hedera mainnet - 314lightfoot.hbar
    },

    // ========================================================================
    // OTHER L2s (Optional)
    // ========================================================================
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL || "https://arb1.arbitrum.io/rpc",
      accounts: accounts,
      chainId: 42161,
    },
    optimism: {
      url: process.env.OPTIMISM_RPC_URL || "https://mainnet.optimism.io",
      accounts: accounts,
      chainId: 10,
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon-rpc.com",
      accounts: accounts,
      chainId: 137,
    },
  },

  // ========================================================================
  // BLOCK EXPLORERS
  // ========================================================================
  etherscan: {
    apiKey: {
      // Ethereum
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",

      // Base
      "base-sepolia": process.env.BASESCAN_API_KEY || "",
      "base-mainnet": process.env.BASESCAN_API_KEY || "",

      // Others
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      optimisticEthereum: process.env.OPTIMISTIC_ETHERSCAN_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "base-sepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      },
      {
        network: "base-mainnet",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      }
    ]
  },

  // ========================================================================
  // GAS REPORTING
  // ========================================================================
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    showTimeSpent: true,
    showMethodSig: true,
  },
};
