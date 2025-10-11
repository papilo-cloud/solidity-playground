// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract sToken is ERC20, Ownable, ERC20Burnable {

    constructor(string memory _name, string memory _symbol, address initialOwner) 
        ERC20(_name, _symbol)
        Ownable(initialOwner) 
        {}

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external onlyOwner {
        _burn(_to, _amount);
    }
    
}