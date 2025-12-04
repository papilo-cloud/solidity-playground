# Flash Loan Provider

## Overview
Flash loans are uncollateralized loans that must be borrowed and repaid within a single transaction. This project implements a complete flash loan system with three main components:

1. **FlashLoanProvider** - The lending pool contract
2. **LoanToken** - An ERC20 token for testing
3. **FlashBorrower** - A reference implementation for borrowing

### Common Use Cases

- **Arbitrage** - Exploit price differences across DEXs
- **Collateral Swaps** - Change collateral without closing positions
- **Liquidations** - Liquidate undercollateralized positions
- **Refinancing** - Move debt between protocols

### Features
- Users deposit tokens to earn interest
- Flash loans with 0.09% fee
- Fees distributed to depositors
- No collateral required for flash loans
- Callback pattern for loan execution

### Step-by-Step Walkthrough

#### Step 1: Deploy Required Contracts

**In Remix:**
1. Deploy LoanToken → Owner gets 100,000 tokens
2. Deploy FlashLoanProvider with LoanToken address

#### Step 2: Fund the Pool with Deposits
```
LoanToken:
- transfer(PROVIDER_ADDRESS, 50000 * 10^18)

FlashLoanProvider (depositors):
- approve(PROVIDER_ADDRESS, 50000 * 10^18)
- deposit(50000 * 10^18)
```

#### Step 3: Create Flash Loan Receiver

**In Remix:**
1. Deploy FlashBorrower -> borrow 10,000 tokens


#### Step 4: Request Flash Loan
```
FlashBorrower:
- requestFlashLoan(10000 * 10^18)
```

#### Step 5: Owner Withdraws Fees
```
FlashLoanProvider (owner):
- withdrawFees()
- Receives 0.09% of all loans taken
```
