## 1. **Simple Voting System** 
**Difficulty:** 🟢 Beginner

### Task:
Create a contract where users can create proposals and vote on them. Each address can only vote once per proposal.

### Requirements:
- ✅ Owner can create proposals with a description
- ✅ Any address can vote (Yes/No) on active proposals
- ✅ Each address can only vote once per proposal
- ✅ Owner can close voting on a proposal
- ✅ Get vote counts for any proposal
- ✅ Check if an address has voted

### Example Usage:
```solidity
// Deploy contract
Voting voting = new Voting();

// Create proposal
voting.createProposal("Should we upgrade the protocol?");

// Vote on proposal
voting.vote(0, true); // Vote Yes on proposal 0

// Get results
(uint yes, uint no) = voting.getVotes(0);

// Close voting
voting.closeProposal(0);
```

### Learning Objectives:
- Structs and mappings
- Access control with modifiers
- Events and basic state management
