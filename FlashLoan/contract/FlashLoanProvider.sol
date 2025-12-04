// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashLoanReceiver {
    function onFlashLoan(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

contract FlashLoanProvider {
    error FlashLoanProvider__NotTheOwner();
    error FlashLoanProvider__InvalidToken();
    error FlashLoanProvider__AmountMustBeGreaterThanZero();
    error FlashLoanProvider__InsufficientBalance();
    error FlashLoanProvider__TransferFailed();
    error FlashLoanProvider__InsufficientLiquidity();
    error FlashLoanProvider__LoanTransferFailed();
    error FlashLoanProvider__RepaymentFailed();
    error FlashLoanProvider__InvalidRepayment();
    error FlashLoanProvider__NoFees();

    IERC20 public token;
    address public owner;

    uint256 public constant FLASH_LOAN_FEE = 9; // 0.09%
    uint256 public totalFees;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public interestEarned;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event FlashLoan(address indexed borrower, uint256 amount, uint256 fee);

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert FlashLoanProvider__NotTheOwner();
        }
        _;
    }

    constructor(address _token) {
        if (_token == address(0)) {
            revert FlashLoanProvider__InvalidToken();
        }
        token = IERC20(_token);
        owner = msg.sender;
    }

    function deposit(uint256 _amount) external {
        if (_amount <= 0) {
            revert FlashLoanProvider__AmountMustBeGreaterThanZero();
        }

        deposits[msg.sender] += _amount;
        if (!token.transferFrom(msg.sender, address(this), _amount)) {
            revert FlashLoanProvider__TransferFailed();
        }

        emit Deposited(msg.sender, _amount);
    }

    function withdrawn(uint256 _amount) external {
        if (_amount <= 0) {
            revert FlashLoanProvider__AmountMustBeGreaterThanZero();
        }
        if (deposits[msg.sender] < _amount) {
            revert FlashLoanProvider__InsufficientBalance();
        }

        deposits[msg.sender] -= _amount;
        if (!token.transfer(msg.sender, _amount)) {
            revert FlashLoanProvider__TransferFailed();
        }

        emit Withdrawn(msg.sender, _amount);
    }

    function flashLoan(
        address _borrower,
        uint256 _amount,
        bytes calldata _data
    ) external {
        if (_amount <= 0) {
            revert FlashLoanProvider__AmountMustBeGreaterThanZero();
        }
        
        uint256 balanceBefore = token.balanceOf(address(this));

        if (balanceBefore < _amount) {
            revert FlashLoanProvider__InsufficientLiquidity();
        }

        uint256 fee = (_amount * FLASH_LOAN_FEE) / 10000;
        uint256 amountDue = _amount + fee;

        if (!token.transfer(_borrower, _amount)) {
            revert FlashLoanProvider__LoanTransferFailed();
        }

        IFlashLoanReceiver(_borrower).onFlashLoan(
            address(token),
            _amount,
            fee,
            _data
        );

        if (!token.transferFrom(_borrower, address(this), amountDue)) {
            revert FlashLoanProvider__RepaymentFailed();
        }
        if (token.balanceOf(address(this)) < balanceBefore + fee) {
            revert FlashLoanProvider__InvalidRepayment();
        }

        totalFees += fee;
        emit FlashLoan(_borrower, _amount, fee);
    }

    function withdrawFees() external onlyOwner {
        if (totalFees <= 0) {
            revert FlashLoanProvider__NoFees();
        }

        uint256 amount = totalFees;
        totalFees = 0;

        if (!token.transfer(owner, amount)) {
            revert FlashLoanProvider__TransferFailed();
        }
    }

    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
