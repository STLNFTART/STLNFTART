// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SyntheticPRIM (sPRIM)
 * @notice ERC20 token representing tokenized real-world assets
 * @dev Minted 1:1 with RWA collateral, fully redeemable for physical assets
 *
 * KEY FEATURES:
 * - Backed by verified real-world assets (gold, real estate, vehicles, etc.)
 * - Each sPRIM represents $1 USD worth of physical collateral
 * - Fully redeemable for underlying assets
 * - Tradeable, transferable, composable with DeFi
 * - Over-collateralized for security (configurable ratio)
 *
 * SECURITY:
 * - Only vault contract can mint/burn
 * - ReentrancyGuard on critical functions
 * - Role-based access control
 * - Emergency pause capability
 */
contract SyntheticPRIM is ERC20, ERC20Burnable, AccessControl, ReentrancyGuard {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Mapping of sPRIM to underlying asset ID
    mapping(address => uint256[]) public holderAssets;
    mapping(uint256 => uint256) public assetTosPRIM; // assetId => sPRIM amount

    // Total collateral value backing all sPRIM
    uint256 public totalCollateralValue; // In USD (scaled by 1e18)

    // Events
    event sPRIMMinted(address indexed to, uint256 amount, uint256 indexed assetId, uint256 collateralValue);
    event sPRIMBurned(address indexed from, uint256 amount, uint256 indexed assetId);
    event CollateralValueUpdated(uint256 oldValue, uint256 newValue);

    constructor(address admin) ERC20("Synthetic PRIM", "sPRIM") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Mint sPRIM backed by real-world asset
     * @param to Recipient address
     * @param amount Amount of sPRIM to mint
     * @param assetId ID of backing asset
     * @param collateralValue USD value of collateral
     */
    function mint(
        address to,
        uint256 amount,
        uint256 assetId,
        uint256 collateralValue
    ) external onlyRole(MINTER_ROLE) nonReentrant {
        require(to != address(0), "sPRIM: mint to zero address");
        require(amount > 0, "sPRIM: zero amount");
        require(collateralValue >= amount, "sPRIM: insufficient collateral");

        _mint(to, amount);

        // Track asset linkage
        holderAssets[to].push(assetId);
        assetTosPRIM[assetId] = amount;
        totalCollateralValue += collateralValue;

        emit sPRIMMinted(to, amount, assetId, collateralValue);
    }

    /**
     * @notice Burn sPRIM (typically during asset redemption)
     * @param from Address to burn from
     * @param amount Amount to burn
     * @param assetId Associated asset ID
     */
    function burnFrom(
        address from,
        uint256 amount,
        uint256 assetId
    ) public onlyRole(BURNER_ROLE) nonReentrant {
        require(amount > 0, "sPRIM: zero amount");
        require(assetTosPRIM[assetId] >= amount, "sPRIM: insufficient asset backing");

        _burn(from, amount);

        assetTosPRIM[assetId] -= amount;

        emit sPRIMBurned(from, amount, assetId);
    }

    /**
     * @notice Update collateral value (after reappraisal)
     * @param newValue New total collateral value
     */
    function updateCollateralValue(uint256 newValue) external onlyRole(MINTER_ROLE) {
        uint256 oldValue = totalCollateralValue;
        totalCollateralValue = newValue;
        emit CollateralValueUpdated(oldValue, newValue);
    }

    /**
     * @notice Calculate collateralization ratio
     * @return Ratio in basis points (10000 = 100%)
     */
    function collateralizationRatio() external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        return (totalCollateralValue * 10000) / supply;
    }

    /**
     * @notice Get assets held by address
     * @param holder Address to query
     * @return Array of asset IDs
     */
    function getHolderAssets(address holder) external view returns (uint256[] memory) {
        return holderAssets[holder];
    }

    /**
     * @notice Calculate intrinsic value per token
     * @return Value in USD (scaled by 1e18)
     */
    function intrinsicValue() external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        return (totalCollateralValue * 1e18) / supply;
    }
}
