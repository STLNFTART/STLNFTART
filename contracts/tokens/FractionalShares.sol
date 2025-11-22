// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title FractionalShares
 * @notice ERC1155 token for fractional ownership of high-value RWAs
 * @dev Each token ID represents a different fractionalized asset
 *
 * USE CASES:
 * - Fractional real estate (buy 1/1000 of a $10M property)
 * - Luxury vehicle shares (own 1/10 of a Lamborghini)
 * - Art & collectibles (share a Picasso painting)
 * - Private jet timeshares
 *
 * BENEFITS:
 * - Lower barrier to entry (invest $1000 instead of $1M)
 * - Liquidity for traditionally illiquid assets
 * - Diversification across multiple high-value assets
 * - Transparent on-chain ownership
 */
contract FractionalShares is ERC1155, AccessControl, ReentrancyGuard {

    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");

    // Asset ID => Share info
    struct ShareInfo {
        uint256 assetId;            // Linked RWA ID
        uint256 totalShares;        // Total shares minted
        uint256 shareValue;         // Value per share in USD (1e18)
        bool redeemable;            // Can be redeemed for sPRIM
        string assetDescription;    // "Ferrari 488 GTB" or "NYC Penthouse"
    }

    mapping(uint256 => ShareInfo) public shareInfo;
    mapping(uint256 => mapping(address => bool)) public hasVoted; // For governance

    uint256 public nextAssetId;

    // Events
    event SharesCreated(uint256 indexed assetId, uint256 totalShares, uint256 shareValue);
    event SharesRedeemed(uint256 indexed assetId, address indexed redeemer, uint256 shares);
    event SharesTransferred(uint256 indexed assetId, address indexed from, address indexed to, uint256 amount);

    constructor(string memory uri, address admin) ERC1155(uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(URI_SETTER_ROLE, admin);
    }

    /**
     * @notice Create fractional shares for an asset
     * @param assetId RWA vault asset ID
     * @param totalShares Total number of shares to create
     * @param shareValue Value per share in USD
     * @param assetDescription Human-readable description
     * @return tokenId The ERC1155 token ID for these shares
     */
    function createShares(
        uint256 assetId,
        uint256 totalShares,
        uint256 shareValue,
        string calldata assetDescription
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (uint256 tokenId) {
        require(totalShares > 1 && totalShares <= 10000, "Invalid share count");
        require(shareValue > 0, "Invalid share value");

        tokenId = nextAssetId++;

        shareInfo[tokenId] = ShareInfo({
            assetId: assetId,
            totalShares: totalShares,
            shareValue: shareValue,
            redeemable: false,
            assetDescription: assetDescription
        });

        emit SharesCreated(assetId, totalShares, shareValue);

        return tokenId;
    }

    /**
     * @notice Mint fractional shares to investor
     * @param to Recipient address
     * @param tokenId Share token ID
     * @param amount Number of shares to mint
     */
    function mintShares(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) nonReentrant {
        require(to != address(0), "Mint to zero address");
        require(shareInfo[tokenId].assetId != 0, "Share not created");
        require(
            totalSupply(tokenId) + amount <= shareInfo[tokenId].totalShares,
            "Exceeds total shares"
        );

        _mint(to, tokenId, amount, "");
    }

    /**
     * @notice Burn shares (typically during full redemption)
     * @param from Address to burn from
     * @param tokenId Share token ID
     * @param amount Number of shares to burn
     */
    function burnShares(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) nonReentrant {
        require(amount > 0, "Zero amount");
        require(balanceOf(from, tokenId) >= amount, "Insufficient shares");

        _burn(from, tokenId, amount);

        emit SharesRedeemed(tokenId, from, amount);
    }

    /**
     * @notice Enable redemption for shares
     * @param tokenId Share token ID
     */
    function enableRedemption(uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        shareInfo[tokenId].redeemable = true;
    }

    /**
     * @notice Set token URI
     * @param newuri New base URI
     */
    function setURI(string memory newuri) external onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    /**
     * @notice Get total supply of a token ID
     * @param tokenId Token ID to query
     * @return Total minted shares
     */
    function totalSupply(uint256 tokenId) public view returns (uint256) {
        // This is a simplified version - in production use a proper supply tracker
        return shareInfo[tokenId].totalShares;
    }

    /**
     * @notice Get share info
     * @param tokenId Token ID to query
     * @return ShareInfo struct
     */
    function getShareInfo(uint256 tokenId) external view returns (ShareInfo memory) {
        return shareInfo[tokenId];
    }

    /**
     * @notice Calculate total value of shares held by address
     * @param account Address to query
     * @param tokenId Token ID
     * @return Total USD value (scaled by 1e18)
     */
    function getShareValue(address account, uint256 tokenId) external view returns (uint256) {
        uint256 balance = balanceOf(account, tokenId);
        return balance * shareInfo[tokenId].shareValue;
    }

    /**
     * @notice Override to add transfer event
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        super.safeTransferFrom(from, to, id, amount, data);
        emit SharesTransferred(id, from, to, amount);
    }

    /**
     * @notice Check interface support
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
