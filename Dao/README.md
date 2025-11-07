# What is a DAO (short)

A **Decentralized Autonomous Organization** is a smart-contract governed organization where token holders (or other stakeholders) propose, vote, and execute decisions on treasury use, protocol params, upgrades, grants, etc. The core idea: **rules + execution → collective decision-making without a central authority**.

# Core components

1. **Governance token**

   * Usually ERC-20 or ERC-721. Token holders get voting power (often via ERC20Votes snapshotting).
   * Delegation support lets tokens be “delegated” to voters.

2. **Governance contract (Governor)**

   * Handles proposal creation, vote casting, tallying, and stores parameters (quorum, votingDelay, votingPeriod).
   * Examples: Governor Bravo, OpenZeppelin Governor, Compound Governor.

3. **Timelock/Executor contract**

   * Ensures a delay between proposal passing and execution to allow on-chain/off-chain actors to react. It holds the DAO’s treasury and executes queued transactions.

4. **Treasury**

   * The contract (often the timelock) that holds funds and assets to be managed by governance.

5. **Proposal & Vote metadata**

   * Proposals can be single or batched transactions (target addresses + calldata + ETH value).
   * Votes are typically “For / Against / Abstain” with weights.

6. **Snapshotting & Voting Power**

   * Voting power must be snapshotted at proposal creation to avoid manipulation via token transfers. ERC20Votes provides `getVotes(account, blockNumber)`.

7. **Off-chain tooling**

   * Snapshot.org for gasless signaling. Frontends (Gnosis Safe UI, Governor UIs) for UX.

# Typical proposal lifecycle

1. **Propose** — proposer creates a proposal (targets, calldata, description). May require proposer threshold (min tokens or stake).
2. **Voting delay** — short delay (in blocks/time) before voting begins (gives time to advertise).
3. **Voting period** — time window where token holders vote. Votes counted by weight at snapshot block.
4. **Vote tally** — check quorum (min yes votes relative to supply) and passing rules (e.g., yes > no).
5. **Queue (timelock)** — if passed, proposal is queued in timelock for `delay` seconds.
6. **Execute** — after timelock delay, anyone or the timelock admin executes transactions; funds or actions apply.
7. **Post-execution** — events, state updates; audits and monitoring.

# Key governance parameters (and formulas)

* **VotingDelay** — blocks or seconds before voting starts. Tradeoff: short = fast; long = more time to organize opposition.
* **VotingPeriod** — timeframe votes are open. E.g., 3 days–2 weeks.
* **Quorum** — minimum % of supply participating to validate outcome. Common: 4%–20% depending on DAO size.
* **ProposalThreshold** — minimum voting power to create a proposal (prevents spam).
* **Timelock Delay** — e.g., 48–72 hours for safety, longer for upgrades.
* **Supermajority** — some DAOs require >50% yes or >66% etc.

Example quorum check:

```
passed = (forVotes > againstVotes) && (forVotes >= quorumPercent * totalSupply / 100)
```

# Voting models (tradeoffs)

* **Token-weighted (1 token = 1 vote)** — simple, common, favors large holders.
* **Quadratic voting** — reduces whale influence, requires off-chain integration or special on-chain math.
* **Conviction voting / continuous approval** — dynamic, allows long-term support signals.
* **Reputation / Soulbound** — non-transferable reputation tokens for governance weight.
* **Delegation** — token holders delegate to active voters.

# On-chain vs Off-chain governance

* **On-chain** (Governor contracts): proposals, votes and execution all on chain. Pros: transparent, enforceable. Cons: expensive (gas), slower UX.
* **Off-chain signaling + on-chain execution** (Snapshot + multisig/Gnosis Safe): low gas for voting (off-chain snapshot), then an executor multisig or a relayer executes. Pros: cheap, faster. Cons: relies on off-chain integrity and a multisig (semi-centralized).

# Basic attack vectors & mitigations

* **Flash-loan attacks**: snapshot voting prevents use if snapshot block fixed at proposal creation; still possible if snapshot within same tx — require snapshot at block N − 1 or use timelock.
  *Mitigation*: use ERC20Votes snapshots, proposalDelay, staking/lockups.
* **Bribery / vote buying**: on-chain votes are susceptible.
  *Mitigation*: delegate restrictions, vote lockups, off-chain reputation layers.
* **Sybil (airdrop farming)**: many small addresses.
  *Mitigation*: minimum proposal thresholds, quadratic voting, KYC for large DAOs.
* **Governance capture**: whales buy tokens and pass self-beneficial proposals.
  *Mitigation*: treasury multisig, timelocks, veto multisig or guardian, distributed token distribution.
* **Griefing / spam proposals**: high proposal frequency wastes gas.
  *Mitigation*: proposal fees, higher proposer threshold.
* **Griefing execution**: malicious queued transactions that revert during execute to block further proposals.
  *Mitigation*: careful execution ordering, time locks, simulation & tests.

# Common governance architectures

1. **Governor + Timelock + ERC20Votes** (on-chain full stack) — OpenZeppelin pattern.
2. **Snapshot + Gnosis Safe** — off-chain voting, multisig executes—cheap for communities.
3. **Modular DAOs** — Aragon, DAOstack, Moloch (simple guild-based), Compound-style, UMA's multi-component DAOs.
4. **Meta-governance layers** — some DAOs let token holders delegate voting to other DAOs or councils.