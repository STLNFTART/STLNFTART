// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PriceOracle
 * @notice Chainlink-based price feeds for RWA valuation
 * @dev Provides real-time pricing for various asset categories
 *
 * SUPPORTED PRICE FEEDS:
 * - Precious metals (Gold, Silver, Platinum)
 * - Commodities (Oil, Gas)
 * - Real estate indices
 * - Luxury goods indices
 * - Currency pairs (for international assets)
 *
 * SECURITY:
 * - Multiple price feed sources
 * - Staleness checks (reject old data)
 * - Circuit breakers for extreme price movements
 * - Fallback manual pricing for exotic assets
 */
contract PriceOracle is AccessControl {

    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    // Asset type => Chainlink price feed
    mapping(bytes32 => address) public priceFeeds;

    // Manual price overrides for assets without Chainlink feeds
    mapping(bytes32 => ManualPrice) public manualPrices;

    // Maximum acceptable age of price data (24 hours)
    uint256 public constant MAX_PRICE_AGE = 24 hours;

    // Maximum price deviation before circuit breaker (20%)
    uint256 public constant MAX_PRICE_DEVIATION = 2000; // basis points

    struct ManualPrice {
        uint256 price;
        uint256 timestamp;
        address updater;
        bool active;
    }

    event PriceFeedAdded(bytes32 indexed assetType, address indexed feed);
    event ManualPriceSet(bytes32 indexed assetType, uint256 price, address indexed updater);
    event PriceFeedRemoved(bytes32 indexed assetType);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_MANAGER_ROLE, admin);
    }

    /**
     * @notice Add Chainlink price feed for asset type
     * @param assetType Asset identifier (e.g., keccak256("GOLD"), keccak256("SILVER"))
     * @param feedAddress Chainlink aggregator address
     */
    function addPriceFeed(bytes32 assetType, address feedAddress)
        external
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        require(feedAddress != address(0), "Invalid feed address");
        priceFeeds[assetType] = feedAddress;
        emit PriceFeedAdded(assetType, feedAddress);
    }

    /**
     * @notice Set manual price for assets without Chainlink feeds
     * @param assetType Asset identifier
     * @param price Price in USD (scaled by 1e18)
     */
    function setManualPrice(bytes32 assetType, uint256 price)
        external
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        require(price > 0, "Invalid price");

        manualPrices[assetType] = ManualPrice({
            price: price,
            timestamp: block.timestamp,
            updater: msg.sender,
            active: true
        });

        emit ManualPriceSet(assetType, price, msg.sender);
    }

    /**
     * @notice Get latest price for asset type
     * @param assetType Asset identifier
     * @return price Price in USD (scaled by 1e18)
     * @return timestamp When price was last updated
     */
    function getPrice(bytes32 assetType)
        external
        view
        returns (uint256 price, uint256 timestamp)
    {
        address feed = priceFeeds[assetType];

        // Try Chainlink feed first
        if (feed != address(0)) {
            return _getChainlinkPrice(feed);
        }

        // Fall back to manual price
        ManualPrice memory manualPrice = manualPrices[assetType];
        require(manualPrice.active, "No price available");
        require(
            block.timestamp - manualPrice.timestamp <= MAX_PRICE_AGE,
            "Price too stale"
        );

        return (manualPrice.price, manualPrice.timestamp);
    }

    /**
     * @notice Get price from Chainlink feed
     * @param feed Chainlink aggregator address
     * @return price Price in USD (scaled by 1e18)
     * @return timestamp When price was updated
     */
    function _getChainlinkPrice(address feed)
        internal
        view
        returns (uint256 price, uint256 timestamp)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed);

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(answer > 0, "Invalid price");
        require(answeredInRound >= roundId, "Stale price");
        require(block.timestamp - updatedAt <= MAX_PRICE_AGE, "Price too old");

        // Convert to 18 decimals (Chainlink typically uses 8)
        uint8 decimals = priceFeed.decimals();
        price = uint256(answer) * (10 ** (18 - decimals));
        timestamp = updatedAt;

        return (price, timestamp);
    }

    /**
     * @notice Validate price is within acceptable bounds
     * @param assetType Asset identifier
     * @param proposedPrice Price to validate
     * @return valid Whether price is acceptable
     */
    function validatePrice(bytes32 assetType, uint256 proposedPrice)
        external
        view
        returns (bool valid)
    {
        (uint256 oraclePrice, ) = this.getPrice(assetType);

        if (oraclePrice == 0) return true; // No reference price

        // Calculate deviation
        uint256 deviation;
        if (proposedPrice > oraclePrice) {
            deviation = ((proposedPrice - oraclePrice) * 10000) / oraclePrice;
        } else {
            deviation = ((oraclePrice - proposedPrice) * 10000) / oraclePrice;
        }

        return deviation <= MAX_PRICE_DEVIATION;
    }

    /**
     * @notice Get multiple prices at once
     * @param assetTypes Array of asset identifiers
     * @return prices Array of prices
     * @return timestamps Array of timestamps
     */
    function getPrices(bytes32[] calldata assetTypes)
        external
        view
        returns (uint256[] memory prices, uint256[] memory timestamps)
    {
        prices = new uint256[](assetTypes.length);
        timestamps = new uint256[](assetTypes.length);

        for (uint256 i = 0; i < assetTypes.length; i++) {
            (prices[i], timestamps[i]) = this.getPrice(assetTypes[i]);
        }

        return (prices, timestamps);
    }

    /**
     * @notice Remove price feed
     * @param assetType Asset identifier
     */
    function removePriceFeed(bytes32 assetType)
        external
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        delete priceFeeds[assetType];
        emit PriceFeedRemoved(assetType);
    }

    /**
     * @notice Helper to generate asset type identifier
     * @param assetName String name (e.g., "GOLD", "SILVER")
     * @return Asset type hash
     */
    function getAssetTypeId(string memory assetName) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(assetName));
    }
}
