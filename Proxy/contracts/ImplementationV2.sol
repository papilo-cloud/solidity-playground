// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ImplementationV1} from "./ImplementationV1.sol";

contract ImplementationV2 is ImplementationV1 {
    uint256 public multiplier;

    function setMultiplier(type _multiplier) external onlyOwner {
        multiplier = _multiplier;
    }

    function getValueWithMultiplier() external view returns (uint256) {
        return value * multiplier;
    }
    
}