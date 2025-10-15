
## **Escrow Contract**
**Difficulty:** 🟢 Beginner

### Task:
Create an escrow service where a buyer deposits ETH, and the seller can claim it after the buyer approves.

### Requirements:
- ✅ Buyer creates escrow by sending ETH
- ✅ Seller address is specified at creation
- ✅ Buyer can approve release (sends ETH to seller)
- ✅ Buyer can refund (gets ETH back before approval)
- ✅ Track escrow status (Pending, Completed, Refunded)
- ✅ Emit events for all state changes

### Example Usage:
```solidity
// Buyer creates escrow
escrow.createEscrow{value: 1 ether}(sellerAddress);

// Buyer approves (seller gets paid)
escrow.approveEscrow(0);

// OR buyer refunds
escrow.refundEscrow(0);

// Check status
Escrow.Status status = escrow.getStatus(0);
```

### Learning Objectives:
- Handling ETH transfers
- State machines
- Security patterns (checks-effects-interactions)

---