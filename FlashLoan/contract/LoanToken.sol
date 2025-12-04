// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LoanToken is IERC20 {
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;

    constructor() {
        balances[msg.sender] = 100000 * 10 ** 18;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
