# Flash Loan Provider

### Concept
A lending pool offering flash loans (borrow and repay in same transaction).

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
