// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanReceiver, FlashLoanProvider} from "./FlashLoanProvider.sol";

contract FlashBorrower is IFlashLoanReceiver {
    IERC20 token;
    FlashLoanProvider provider;

    constructor(address _provider, address _token) {
        token = IERC20(_token);
        provider = FlashLoanProvider(_provider);
    }

    function requestFlashLoan(uint256 amount) external {
        provider.flashLoan(address(this), amount, "");
    }

    function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external {
        // Your arbitrage/logic here

        // Repay the loan plus fee
        uint256 amountOwed = amount + fee;
        token.approve(address(provider), amountOwed);
    }
}