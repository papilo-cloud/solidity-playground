// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketplace {
    struct Listing {
        uint256 id;
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    uint256 public listingCount;
    uint256 public marketplaceFeePercentage = 250; //2.5%
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public totalFees;
    address public owner;

    mapping(uint256 => Listing) public listedItems;
    mapping(address => uint256) public proceeds;

    event ItemListed(
        address indexed seller,
        uint256 indexed listingId,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemSold(
        address indexed seller,
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price
    );
    event ItemCancelled(
        address indexed seller,
        uint256 indexed listingId,
        uint256 indexed tokenId
    );
    event ItemUpdated(
        address indexed seller,
        uint256 indexed listingId,
        uint256 indexed tokenId,
        uint256 newPrice
    );
    event FeeWithdrawn(
        address indexed owner,
        uint256 amount
    );
    event ProceedsWithdrawn(
        address indexed seller,
        uint256 amount
    );

    constructor () {
        owner = msg.sender;
    }

    modifier isOwner(address nftAddress, address spender, uint256 tokenId) {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == spender, "Not the owner");
        _;
    }

    modifier isListed(uint256 listingId) {
        Listing storage listing = listedItems[listingId];
        require(listingId < listing.id, "NFT not listed");
        _;
    }

    function listNft(address _nftAddress, uint256 _tokenId, uint256 _price)
        external
        isOwner(_nftAddress, msg.sender, _tokenId)
    {
        uint256 count = listingCount;
        listedItems[count] = Listing(
            count,
            msg.sender,
            _nftAddress,
            _tokenId,
            _price,
            true
        );

        emit ItemListed( msg.sender, count, _tokenId, _price);
        listingCount++;
    }

    function buyNft(uint256 _listingId)
        external
        payable
        isListed(_listingId)
    {
        Listing storage listing = listedItems[_listingId];
        require(listing.isActive, "Item not active");
        require(msg.value >= listing.price, "Not enough ETH sent");

        uint256 fees = (listing.price * marketplaceFeePercentage) / BASIS_POINTS;
        uint256 sellerAmount = listing.price - fees;

        listing.isActive = false;
        proceeds[listing.seller] += sellerAmount;
        totalFees += fees;

        delete listedItems[_listingId];

        IERC721(listing.nftAddress).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        if (msg.value > listing.price) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - listing.price}("");
            require(success, "Balance not sent");
        }

        emit ItemSold(listing.seller, _listingId, msg.sender, listing.price);
    }

    function cancelListing(uint256 _listingId) external isListed(_listingId) {
        Listing storage listing = listedItems[_listingId];
        require(listing.seller == msg.sender, "NOt the seller");
        require(listing.isActive, "Not active");

        delete listedItems[_listingId];
        emit ItemCancelled(msg.sender, _listingId, listing.tokenId);
    }

    function updateListing(uint256 _listingId, uint256 _newPrice) external isListed(_listingId) {
        Listing storage listing = listedItems[_listingId];
        require(listing.seller == msg.sender, "Not the seller");
        require(listing.isActive, "Not active");

        listing.price = _newPrice;

        emit ItemUpdated(msg.sender, _listingId, listing.tokenId, _newPrice);
    }

    function withdrawFees() external {
        require(msg.sender == owner, "Not the owner");
        require(totalFees > 0, "No fees");

        uint256 amount = totalFees;
        totalFees = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Fail to withdraw fees");

        emit FeeWithdrawn(owner, amount);
    }

    function withdrawProceeds() external {
        uint256 amount = proceeds[msg.sender];
        require(amount > 0, "No proceeds");
        proceeds[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Fail to withdraw proceeds");

        emit ProceedsWithdrawn(msg.sender, amount);
    }

    function setMarketPlaceFee(uint256 _newFeeBps) external {
        require(msg.sender == owner, "Not the owner");
        require(_newFeeBps <= 1000, "Fee too high");

        marketplaceFeePercentage = _newFeeBps;
    }

    function getListing(uint256 _listingId) external view isListed(_listingId) returns (Listing memory) {
        return listedItems[_listingId];
    }
}