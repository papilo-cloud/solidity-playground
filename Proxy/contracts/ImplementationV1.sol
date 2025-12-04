// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ImplementationV1 {
    uint256 public value;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function initialize(address _owner) public {
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    function setValue(uint256 _value) external onlyOwner {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }
}