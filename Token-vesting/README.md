
## **Token Vesting Contract**
**Difficulty:** 🟡 Intermediate

### Task:
Create a vesting contract that releases ERC20 tokens gradually over time.

### Requirements:
- ✅ Owner creates vesting schedules for beneficiaries
- ✅ Specify total amount, start time, cliff period, and vesting duration
- ✅ Beneficiaries can claim vested tokens
- ✅ Calculate how many tokens are currently vested
- ✅ Track total claimed and remaining tokens
- ✅ Support multiple vesting schedules per beneficiary

### Example Usage:
```solidity
// Owner creates vesting schedule
// 1000 tokens, 1 month cliff, 12 month vesting
vesting.createVestingSchedule(
    beneficiary,
    1000 * 10**18,
    block.timestamp,
    30 days,  // cliff
    365 days  // duration
);

// Beneficiary claims vested tokens
vesting.claim();

// Check vested amount
uint256 vested = vesting.getVestedAmount(beneficiary);
```

### Learning Objectives:
- Time-based logic
- Linear vesting calculations
- Cliff periods

---