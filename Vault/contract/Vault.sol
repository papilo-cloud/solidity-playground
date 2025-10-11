// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {sToken} from "./sToken.sol";

contract Vault {

    mapping(address => IERC20) public tokens;
    mapping (address => sToken) public claimToken;

    constructor(uniAddr, linkAddr) {
        claimToken[uniAddr] = new sToken("Claim UNI", "sUni", address(this));
        claimToken[linkAddr] = new sToken("Claim LINK", "sLink", address(this));

        tokens[uniAddr] = IERC20(uniAddr);
        tokens[linkAddr] = IERC20(linkAddr);
    }

    function deposit(address _tokenAddr, uint256 _amount) external {
        require(claimToken[_tokenAddr].transferFrom(msg.sender, address(this), _amount), "transferFrom failed");
        tokens[_tokenAddr].mint(msg.sender, _amount);
    }

    function withdraw(address _tokenAddr, uint256 _amount) external {
        claimToken[_tokenAddr].burn(msg.sender, _amount);
        require(tokens[_tokenAddr].transfer(msg.sender, _amount), "transfer failed");
    }
}