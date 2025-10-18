// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    uint256 public nextTokenId;

    constructor () ERC721("Mock NFT", "MNFT") {}

    function mint(address _to) external {
        _mint(_to, nextTokenId);
        nextTokenId++;
    }
}