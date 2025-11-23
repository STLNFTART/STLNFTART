# Primal RWA Vault 🏦

**Production-grade Real World Asset (RWA) tokenization platform**

Built by **Donte Lightfoot** | **nbaybt.eth** | **314lightfoot.hbar**

---

## 🌐 **Overview**

The Primal RWA Vault is a revolutionary DeFi protocol that brings **$300+ trillion** of real-world assets on-chain. Tokenize physical gold, real estate, vehicles, collectibles, and more into tradeable, composable digital assets.

### **Key Features**

✅ **Secure Asset Tokenization** - Convert physical assets into synthetic PRIM (sPRIM)
✅ **Fractional Ownership** - Split expensive assets into affordable shares (ERC1155)
✅ **Chainlink Oracle Integration** - Real-time price feeds for accurate valuations
✅ **Multi-Signature Governance** - Decentralized role-based access control
✅ **Collateral Locking** - Assets locked until all tokens are redeemed
✅ **Emergency Controls** - Pausable for security incidents
✅ **Full Redemption** - Exchange sPRIM for physical assets anytime

---

## 📋 **Supported Asset Types**

| Category | Examples | Market Size |
|----------|----------|-------------|
| **Precious Metals** | Gold, silver, platinum bars/coins | $12T+ |
| **Real Estate** | Homes, commercial properties, land | $280T+ |
| **Vehicles** | Luxury cars, jets, yachts | $2T+ |
| **Commodities** | Oil, gas, mining rights | $20T+ |
| **Financial** | Bonds, trusts, insurance policies | $400T+ |
| **Collectibles** | Art, watches, wine, rare items | $2T+ |

---

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────┐
│           Primal RWA Vault Ecosystem                │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐    ┌──────────────┐             │
│  │  Real Assets │───▶│    Vault     │             │
│  │ (Gold, RE,   │    │  (Custodian) │             │
│  │  Cars, etc.) │    └──────┬───────┘             │
│  └──────────────┘           │                      │
│                             ▼                      │
│                    ┌────────────────┐              │
│                    │  PrimalRWAVault│              │
│                    │   (Main Logic) │              │
│                    └────────┬───────┘              │
│                             │                      │
│           ┌─────────────────┼─────────────────┐    │
│           ▼                 ▼                 ▼    │
│    ┌────────────┐   ┌────────────┐   ┌──────────┐ │
│    │ SyntheticPRIM│ │ Fractional │   │  Price   │ │
│    │   (sPRIM)   │  │   Shares   │   │  Oracle  │ │
│    │   ERC20     │  │   ERC1155  │   │Chainlink │ │
│    └────────────┘   └────────────┘   └──────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### **Smart Contracts**

1. **PrimalRWAVault.sol** - Main vault logic with role-based access
2. **SyntheticPRIM.sol** - ERC20 token backed 1:1 by RWAs
3. **FractionalShares.sol** - ERC1155 for fractional asset ownership
4. **PriceOracle.sol** - Chainlink integration for asset pricing

---

## 🚀 **Quick Start**

### **Installation**

```bash
# Clone repository
git clone https://github.com/yourusername/STLNFTART.git
cd STLNFTART

# Install dependencies
npm install

# Copy environment file
cp .env.example .env
# Edit .env with your RPC URLs and private key

# Compile contracts
npm run compile
```

### **Testing**

```bash
# Run test suite
npx hardhat test

# Run with gas reporting
REPORT_GAS=true npx hardhat test

# Run coverage
npx hardhat coverage
```

### **Deployment**

```bash
# Deploy to Sepolia testnet
npm run deploy:testnet

# Deploy to mainnet (after audit!)
npm run deploy:mainnet

# Verify on Etherscan
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

---

## 💡 **Usage Examples**

### **1. Tokenize a Gold Bar**

```javascript
// Deposit 1kg gold bar with custodian
await vault.depositAsset(
  0, // PRECIOUS_METALS
  "1kg Gold Bar",
  "LBMA certified gold bar, serial #12345",
  "Brinks Vault, New York",
  ethers.id("GOLD-12345"),
  custodianAddress,
  ethers.parseEther("60000") // $60,000 USD value
);

// Appraiser verifies
await vault.connect(appraiser).verifyAsset(
  1, // assetId
  ethers.parseEther("60000"),
  legalDocHash,
  "NY, USA"
);

// Tokenize to sPRIM (1:1 collateral)
await vault.tokenizeAsset(1, 100);
// User now has ~60,000 sPRIM tokens (minus 1% fee)
```

### **2. Fractionalize a $10M Property**

```javascript
// After depositing and verifying real estate
await vault.fractionalizeAsset(
  assetId,
  1000 // Create 1,000 shares
);
// Each share = $10,000 worth of property
// Shares are ERC1155 tokens, fully tradeable
```

### **3. Redeem Physical Asset**

```javascript
// Holder of all sPRIM can redeem
await vault.redeemAsset(assetId);
// sPRIM burned, physical asset released from custody
```

---

## 🔐 **Security**

### **Security Features**

- ✅ **OpenZeppelin Contracts** - Battle-tested libraries
- ✅ **ReentrancyGuard** - Prevents reentrancy attacks
- ✅ **Role-Based Access Control** - Multi-sig governance
- ✅ **Pausable** - Emergency stop mechanism
- ✅ **Collateral Locking** - Assets can't be withdrawn while tokenized
- ✅ **Oracle Integration** - Chainlink price validation

### **Roles**

- `DEFAULT_ADMIN_ROLE` - System administrator (multi-sig recommended)
- `GOVERNANCE_ROLE` - Fee management, liquidations
- `APPRAISER_ROLE` - Asset verification and reappraisal
- `CUSTODIAN_MANAGER_ROLE` - Approve/revoke custodians
- `EMERGENCY_ROLE` - Pause/unpause contract

### **Audits**

⚠️ **NOT YET AUDITED** - This code is for development/testing only.
**DO NOT deploy to mainnet without a professional security audit.**

Recommended auditors:
- [OpenZeppelin](https://openzeppelin.com/security-audits)
- [Trail of Bits](https://www.trailofbits.com/)
- [Certik](https://www.certik.com/)

---

## 📊 **Economics**

### **Revenue Streams**

| Fee Type | Rate | Applied To |
|----------|------|------------|
| Tokenization | 1% | Asset value at tokenization |
| Custody (Annual) | 0.5% | Asset value (paid to custodians) |
| Transaction | 0.1% | sPRIM transfers |
| Redemption | 2% | Asset value at redemption |
| Liquidation | 5% | Sale proceeds |

### **Market Opportunity**

- **Total Addressable Market:** $300+ trillion in real-world assets
- **Target Capture:** 0.1% = $300 billion TVL
- **Annual Revenue (at 0.1% capture):** $3+ billion

---

## 🛣️ **Roadmap**

### **Phase 1: Foundation** ✅
- [x] Core smart contracts
- [x] ERC20 sPRIM implementation
- [x] ERC1155 fractionalization
- [x] Chainlink oracle integration
- [x] Test suite

### **Phase 2: Security** 🔄
- [ ] Professional security audit
- [ ] Bug bounty program
- [ ] Multi-sig setup for governance
- [ ] Testnet deployment & testing

### **Phase 3: Launch** 📅
- [ ] Mainnet deployment
- [ ] First custodian partnerships
- [ ] Certified appraiser onboarding
- [ ] Gold-backed tokens launch

### **Phase 4: Expansion** 📅
- [ ] Real estate tokenization
- [ ] Insurance provider integrations
- [ ] Secondary market (DEX integration)
- [ ] Mobile app

---

## 👤 **Creator**

**Donte Lightfoot**

🔗 **ENS:** nbaybt.eth
🔗 **Hedera:** 314lightfoot.hbar
📍 **Location:** St. Louis, Missouri
💼 **Focus:** Smart Contracts & DeFi Protocols
🌐 **Expertise:** Blockchain, Web3, NFTs, RWA Tokenization

**Current Projects:**
- Multi Heart Model
- MotorHandPro
- Quantro Heart Model
- Primal Quant Ecosystem
- **RWA Vault** (This Project)

**Motto:** *"Recursive Iteration - There's Power in Posterity"*

### **Technology Stack**

- **Blockchain:** Ethereum, Solidity, Hardhat, Ethers.js
- **Languages:** JavaScript, TypeScript, Solidity, Python
- **Frameworks:** React, Node.js, Next.js
- **Tools:** Git, Docker, IPFS, The Graph, Chainlink

---

## 📄 **License**

MIT License - See [LICENSE](./LICENSE) file for details.

---

## 🤝 **Contributing**

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## ⚠️ **Disclaimer**

This software is provided "as is" without warranty. Real-world asset tokenization involves complex legal and regulatory considerations. Consult with legal professionals before deploying. The creators are not responsible for any financial losses.

---

## 📞 **Contact & Support**

- **ENS:** nbaybt.eth
- **Hedera:** 314lightfoot.hbar
- **Hedera Account:** 0.0.3943340
- **GitHub:** [github.com/STLNFTART](https://github.com/STLNFTART)
- **Issues:** [Submit an issue](https://github.com/STLNFTART/STLNFTART/issues)

---

<div align="center">

**Built with ❤️ by nbaybt.eth | 314lightfoot.hbar**

*Bridging Traditional Finance and DeFi Across All Chains*

</div>
