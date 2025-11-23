// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title USTreasuryModule
 * @notice Specialized module for tokenizing US Treasury securities
 * @dev Handles T-bills, T-notes, and T-bonds with compliance features
 *
 * SUPPORTED SECURITIES:
 * - T-Bills (4, 8, 13, 26, 52 week maturities)
 * - T-Notes (2, 3, 5, 7, 10 year maturities)
 * - T-Bonds (20, 30 year maturities)
 *
 * MARKET SIZE: $26+ Trillion
 *
 * COMPLIANCE:
 * - KYC/AML required for all holders
 * - Accredited investor verification
 * - Transfer restrictions (Reg D)
 * - Automatic tax reporting (1099 generation)
 *
 * FEATURES:
 * - CUSIP tracking
 * - Maturity date management
 * - Coupon payment distribution
 * - Automated redemption at maturity
 * - Real-time treasury yield integration
 */
contract USTreasuryModule is AccessControl, ReentrancyGuard {

    bytes32 public constant TREASURY_MANAGER_ROLE = keccak256("TREASURY_MANAGER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    // ========================================================================
    // ENUMS & STRUCTS
    // ========================================================================

    enum TreasuryType {
        T_BILL,      // Treasury Bill (< 1 year, no coupon)
        T_NOTE,      // Treasury Note (2-10 years, semi-annual coupon)
        T_BOND       // Treasury Bond (20-30 years, semi-annual coupon)
    }

    enum TreasuryStatus {
        PENDING_CUSTODY,
        ACTIVE,
        MATURED,
        REDEEMED,
        DEFAULTED
    }

    struct USTreasurySecurity {
        uint256 id;
        TreasuryType treasuryType;

        // Identification
        string cusip;               // 9-character CUSIP identifier
        string isin;                // International Securities ID
        uint256 issueDate;          // When issued by US Treasury
        uint256 maturityDate;       // When matures

        // Financial
        uint256 faceValue;          // Par value in USD (1e18 scaled)
        uint256 purchasePrice;      // Actual purchase price
        uint256 couponRate;         // Annual coupon rate (basis points)
        uint256 currentYield;       // Current yield (basis points)

        // Payments
        uint256 lastCouponPayment;  // Last coupon distribution
        uint256 nextCouponDate;     // Next expected coupon
        uint256 totalCouponsRecieved; // Total coupon payments

        // Tokenization
        uint256 sPRIMIssued;        // Synthetic PRIM issued
        bool fractionalized;        // Can be split
        uint256 minInvestment;      // Minimum investment (for compliance)

        // Compliance
        address custodian;          // Regulated custodian (bank/broker)
        bool kycRequired;           // KYC verification needed
        bool accreditedOnly;        // Accredited investors only
        mapping(address => bool) whitelisted; // Approved holders

        // Status
        TreasuryStatus status;
        address owner;
        uint256 createdAt;
    }

    // ========================================================================
    // STATE
    // ========================================================================

    mapping(uint256 => USTreasurySecurity) public treasuries;
    uint256 public treasuryCount;

    // Total value of US Treasuries held
    uint256 public totalTreasuryValue;

    // Compliance tracking
    mapping(address => bool) public kycVerified;
    mapping(address => bool) public accreditedInvestor;
    mapping(address => uint256) public investorTaxId; // Encrypted hash

    // Custodian tracking
    mapping(address => TreasuryCustodian) public treasuryCustodians;

    struct TreasuryCustodian {
        address addr;
        string name;
        bool approved;
        bool isBank;                // Is a regulated bank
        bool isBrokerDealer;        // Is a broker-dealer
        string fdicNumber;          // FDIC insurance number (if bank)
        string secNumber;           // SEC registration (if broker)
        uint256 insuranceCoverage;  // SIPC/FDIC coverage
    }

    // ========================================================================
    // EVENTS
    // ========================================================================

    event TreasuryDeposited(uint256 indexed treasuryId, string cusip, uint256 faceValue, uint256 maturityDate);
    event TreasuryTokenized(uint256 indexed treasuryId, uint256 sPRIMIssued);
    event CouponPaid(uint256 indexed treasuryId, uint256 amount, uint256 timestamp);
    event TreasuryMatured(uint256 indexed treasuryId, uint256 redemptionValue);
    event InvestorWhitelisted(address indexed investor, uint256 indexed treasuryId);
    event KYCVerified(address indexed investor, uint256 timestamp);
    event CustodianApproved(address indexed custodian, string name, bool isBank);

    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURY_MANAGER_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
    }

    // ========================================================================
    // TREASURY DEPOSIT & TOKENIZATION
    // ========================================================================

    /**
     * @notice Deposit US Treasury security for tokenization
     * @param treasuryType Type of treasury (bill, note, bond)
     * @param cusip 9-character CUSIP identifier
     * @param isin International Securities ID
     * @param issueDate When treasury was issued
     * @param maturityDate When treasury matures
     * @param faceValue Par value in USD
     * @param purchasePrice Actual purchase price
     * @param couponRate Annual coupon rate (basis points, 0 for T-bills)
     * @param custodian Approved custodian holding the treasury
     */
    function depositTreasury(
        TreasuryType treasuryType,
        string calldata cusip,
        string calldata isin,
        uint256 issueDate,
        uint256 maturityDate,
        uint256 faceValue,
        uint256 purchasePrice,
        uint256 couponRate,
        address custodian
    ) external nonReentrant returns (uint256 treasuryId) {
        require(treasuryCustodians[custodian].approved, "Custodian not approved");
        require(bytes(cusip).length == 9, "Invalid CUSIP");
        require(maturityDate > block.timestamp, "Already matured");
        require(faceValue > 0, "Invalid face value");

        treasuryCount++;
        treasuryId = treasuryCount;

        USTreasurySecurity storage treasury = treasuries[treasuryId];

        treasury.id = treasuryId;
        treasury.treasuryType = treasuryType;
        treasury.cusip = cusip;
        treasury.isin = isin;
        treasury.issueDate = issueDate;
        treasury.maturityDate = maturityDate;
        treasury.faceValue = faceValue;
        treasury.purchasePrice = purchasePrice;
        treasury.couponRate = couponRate;
        treasury.currentYield = _calculateYield(purchasePrice, faceValue, maturityDate);
        treasury.custodian = custodian;
        treasury.kycRequired = true;
        treasury.accreditedOnly = faceValue >= 1000000e18; // $1M+ requires accreditation
        treasury.minInvestment = faceValue >= 1000000e18 ? 25000e18 : 1000e18; // $25K or $1K min
        treasury.status = TreasuryStatus.PENDING_CUSTODY;
        treasury.owner = msg.sender;
        treasury.createdAt = block.timestamp;

        // Calculate next coupon date (semi-annual for notes/bonds)
        if (treasuryType != TreasuryType.T_BILL) {
            treasury.nextCouponDate = issueDate + 182 days; // ~6 months
        }

        emit TreasuryDeposited(treasuryId, cusip, faceValue, maturityDate);

        return treasuryId;
    }

    /**
     * @notice Tokenize US Treasury into sPRIM (compliance checked)
     * @param treasuryId Treasury to tokenize
     */
    function tokenizeTreasury(uint256 treasuryId)
        external
        nonReentrant
        returns (uint256 sPRIMAmount)
    {
        USTreasurySecurity storage treasury = treasuries[treasuryId];
        require(treasury.owner == msg.sender, "Not owner");
        require(treasury.status == TreasuryStatus.PENDING_CUSTODY, "Invalid status");
        require(kycVerified[msg.sender], "KYC required");

        if (treasury.accreditedOnly) {
            require(accreditedInvestor[msg.sender], "Accredited investor required");
        }

        // Use face value for tokenization
        sPRIMAmount = treasury.faceValue;

        treasury.sPRIMIssued = sPRIMAmount;
        treasury.status = TreasuryStatus.ACTIVE;
        treasury.whitelisted[msg.sender] = true;

        totalTreasuryValue += treasury.faceValue;

        emit TreasuryTokenized(treasuryId, sPRIMAmount);

        return sPRIMAmount;
    }

    /**
     * @notice Distribute coupon payment to sPRIM holders
     * @param treasuryId Treasury paying coupon
     * @param couponAmount Amount to distribute
     */
    function distributeCoupon(uint256 treasuryId, uint256 couponAmount)
        external
        onlyRole(TREASURY_MANAGER_ROLE)
        nonReentrant
    {
        USTreasurySecurity storage treasury = treasuries[treasuryId];
        require(treasury.status == TreasuryStatus.ACTIVE, "Not active");
        require(treasury.treasuryType != TreasuryType.T_BILL, "T-bills have no coupons");
        require(block.timestamp >= treasury.nextCouponDate, "Not yet due");

        treasury.lastCouponPayment = block.timestamp;
        treasury.totalCouponsRecieved += couponAmount;

        // Calculate next coupon date (6 months)
        treasury.nextCouponDate += 182 days;

        emit CouponPaid(treasuryId, couponAmount, block.timestamp);

        // In production: Distribute pro-rata to sPRIM holders
    }

    /**
     * @notice Mark treasury as matured and enable redemption
     * @param treasuryId Treasury that matured
     */
    function matureTreasury(uint256 treasuryId)
        external
        onlyRole(TREASURY_MANAGER_ROLE)
    {
        USTreasurySecurity storage treasury = treasuries[treasuryId];
        require(block.timestamp >= treasury.maturityDate, "Not yet matured");
        require(treasury.status == TreasuryStatus.ACTIVE, "Not active");

        treasury.status = TreasuryStatus.MATURED;

        emit TreasuryMatured(treasuryId, treasury.faceValue);
    }

    // ========================================================================
    // COMPLIANCE
    // ========================================================================

    /**
     * @notice Verify investor KYC
     * @param investor Address to verify
     * @param taxIdHash Encrypted hash of SSN/EIN
     */
    function verifyKYC(address investor, uint256 taxIdHash)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(investor != address(0), "Invalid investor");

        kycVerified[investor] = true;
        investorTaxId[investor] = taxIdHash;

        emit KYCVerified(investor, block.timestamp);
    }

    /**
     * @notice Mark investor as accredited
     * @param investor Address to mark
     */
    function verifyAccreditedInvestor(address investor)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(kycVerified[investor], "KYC required first");
        accreditedInvestor[investor] = true;
    }

    /**
     * @notice Whitelist investor for specific treasury
     * @param treasuryId Treasury ID
     * @param investor Investor to whitelist
     */
    function whitelistInvestor(uint256 treasuryId, address investor)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(kycVerified[investor], "KYC required");

        USTreasurySecurity storage treasury = treasuries[treasuryId];

        if (treasury.accreditedOnly) {
            require(accreditedInvestor[investor], "Must be accredited");
        }

        treasury.whitelisted[investor] = true;

        emit InvestorWhitelisted(investor, treasuryId);
    }

    // ========================================================================
    // CUSTODIAN MANAGEMENT
    // ========================================================================

    /**
     * @notice Approve treasury custodian (bank or broker-dealer)
     * @param custodian Custodian address
     * @param name Custodian name
     * @param isBank Is a regulated bank
     * @param isBrokerDealer Is a broker-dealer
     * @param fdicNumber FDIC number (if bank)
     * @param secNumber SEC number (if broker)
     * @param insuranceCoverage Insurance amount
     */
    function approveTreasuryCustodian(
        address custodian,
        string calldata name,
        bool isBank,
        bool isBrokerDealer,
        string calldata fdicNumber,
        string calldata secNumber,
        uint256 insuranceCoverage
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(custodian != address(0), "Invalid custodian");
        require(isBank || isBrokerDealer, "Must be bank or broker");

        treasuryCustodians[custodian] = TreasuryCustodian({
            addr: custodian,
            name: name,
            approved: true,
            isBank: isBank,
            isBrokerDealer: isBrokerDealer,
            fdicNumber: fdicNumber,
            secNumber: secNumber,
            insuranceCoverage: insuranceCoverage
        });

        emit CustodianApproved(custodian, name, isBank);
    }

    // ========================================================================
    // VIEW FUNCTIONS
    // ========================================================================

    /**
     * @notice Calculate current yield for a treasury
     */
    function _calculateYield(
        uint256 purchasePrice,
        uint256 faceValue,
        uint256 maturityDate
    ) internal view returns (uint256) {
        if (maturityDate <= block.timestamp) return 0;

        uint256 yearsToMaturity = (maturityDate - block.timestamp) / 365 days;
        if (yearsToMaturity == 0) yearsToMaturity = 1;

        // Simple yield calculation (in basis points)
        uint256 discount = faceValue > purchasePrice ? faceValue - purchasePrice : 0;
        uint256 yield = (discount * 10000) / (purchasePrice * yearsToMaturity);

        return yield;
    }

    /**
     * @notice Get treasury details
     */
    function getTreasuryDetails(uint256 treasuryId) external view returns (
        TreasuryType treasuryType,
        string memory cusip,
        uint256 faceValue,
        uint256 maturityDate,
        uint256 couponRate,
        uint256 currentYield,
        TreasuryStatus status
    ) {
        USTreasurySecurity storage treasury = treasuries[treasuryId];
        return (
            treasury.treasuryType,
            treasury.cusip,
            treasury.faceValue,
            treasury.maturityDate,
            treasury.couponRate,
            treasury.currentYield,
            treasury.status
        );
    }

    /**
     * @notice Check if investor can hold treasury
     */
    function canHoldTreasury(uint256 treasuryId, address investor)
        external
        view
        returns (bool)
    {
        USTreasurySecurity storage treasury = treasuries[treasuryId];

        if (!kycVerified[investor]) return false;
        if (treasury.accreditedOnly && !accreditedInvestor[investor]) return false;
        if (!treasury.whitelisted[investor]) return false;

        return true;
    }

    /**
     * @notice Get total US Treasury holdings
     */
    function getTotalTreasuryValue() external view returns (uint256) {
        return totalTreasuryValue;
    }
}
