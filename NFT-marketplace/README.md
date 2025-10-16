
## **NFT Marketplace**
**Difficulty:** 🟡 Intermediate

### Task:
Build a marketplace where users can list, buy, and cancel NFT listings. Use ERC721 standard.

### Requirements:
- ✅ List an NFT for sale at a specific price
- ✅ Buy a listed NFT by sending exact ETH amount
- ✅ Cancel a listing (only by seller)
- ✅ Marketplace takes 2.5% fee on each sale
- ✅ Seller receives 97.5% of sale price
- ✅ Owner can withdraw accumulated fees
- ✅ Get all active listings

### Example Usage:
```solidity
// Seller lists NFT
nft.approve(marketplace, tokenId);
marketplace.listNFT(nftAddress, tokenId, 1 ether);

// Buyer purchases
marketplace.buyNFT{value: 1 ether}(listingId);

// Seller cancels
marketplace.cancelListing(listingId);

// Owner withdraws fees
marketplace.withdrawFees();
```

### Learning Objectives:
- ERC721 interactions
- Percentage calculations
- Marketplace mechanics

---