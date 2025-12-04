// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract BasicICO {
    address public owner;
    IERC20 public token;
    
    uint256 public tokenPrice; // Price in wei per token
    uint256 public tokensSold;
    uint256 public tokensAvailable;
    
    bool public saleActive;
    
    uint256 public minPurchase;
    uint256 public maxPurchase;
    
    mapping(address => uint256) public contributions;
    
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 totalCost);
    event SaleStarted(uint256 timestamp);
    event SaleEnded(uint256 timestamp);
    event TokensWithdrawn(address indexed owner, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier saleIsActive() {
        require(saleActive, "Sale is not active");
        _;
    }
    
    constructor(
        address _tokenAddress,
        uint256 _tokenPrice,
        uint256 _minPurchase,
        uint256 _maxPurchase
    ) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_tokenPrice > 0, "Price must be greater than 0");
        require(_minPurchase > 0, "Min purchase must be greater than 0");
        require(_maxPurchase >= _minPurchase, "Max must be >= min");
        
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        tokenPrice = _tokenPrice;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        saleActive = false;
    }
    
    // Start the ICO sale
    function startSale() external onlyOwner {
        require(!saleActive, "Sale already active");
        tokensAvailable = token.balanceOf(address(this));
        require(tokensAvailable > 0, "No tokens available for sale");
        saleActive = true;
        emit SaleStarted(block.timestamp);
    }
    
    // End the ICO sale
    function endSale() external onlyOwner {
        require(saleActive, "Sale not active");
        saleActive = false;
        emit SaleEnded(block.timestamp);
    }
    
    // Buy tokens with ETH
    function buyTokens(uint256 _tokenAmount) external payable saleIsActive {
        require(_tokenAmount >= minPurchase, "Below minimum purchase");
        require(_tokenAmount <= maxPurchase, "Above maximum purchase");
        require(_tokenAmount <= tokensAvailable, "Not enough tokens available");
        
        uint256 cost = (_tokenAmount * tokenPrice) / 1e18; // Assuming token has 18 decimals
        require(msg.value >= cost, "Insufficient ETH sent");
        
        // Transfer tokens to buyer
        require(token.transfer(msg.sender, _tokenAmount), "Token transfer failed");
        
        // Update state
        tokensSold += _tokenAmount;
        tokensAvailable -= _tokenAmount;
        contributions[msg.sender] += _tokenAmount;
        
        // Refund excess ETH
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
        
        emit TokensPurchased(msg.sender, _tokenAmount, cost);
    }
    
    // Update token price
    function setTokenPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be greater than 0");
        tokenPrice = _newPrice;
    }
    
    // Update purchase limits
    function setPurchaseLimits(uint256 _min, uint256 _max) external onlyOwner {
        require(_min > 0, "Min must be greater than 0");
        require(_max >= _min, "Max must be >= min");
        minPurchase = _min;
        maxPurchase = _max;
    }
    
    // Withdraw unsold tokens (only when sale is not active)
    function withdrawTokens() external onlyOwner {
        require(!saleActive, "Cannot withdraw during active sale");
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(token.transfer(owner, balance), "Token transfer failed");
        emit TokensWithdrawn(owner, balance);
    }
    
    // Withdraw ETH raised from sales
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
        emit FundsWithdrawn(owner, balance);
    }
    
    // Get contract ETH balance
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Get remaining tokens for sale
    function getRemainingTokens() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    // Calculate cost for specific token amount
    function calculateCost(uint256 _tokenAmount) external view returns (uint256) {
        return (_tokenAmount * tokenPrice) / 1e18;
    }
    
    // Receive ETH directly (redirects to buyTokens with all available tokens up to max)
    receive() external payable {
        revert("Use buyTokens function");
    }
}