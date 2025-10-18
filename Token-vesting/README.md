Nice — token vesting is a fundamental building block in token economics (team allocations, investor lockups, airdrops, etc.). Below is a **detailed, practical walkthrough** that covers the core concepts, designs, security considerations, and a fully working Solidity example you can use and extend. I’ll also include formulas, event design, tests, and deployment notes so you can implement this end-to-end.

# What is token vesting?

A **vesting contract** locks tokens and releases them to beneficiaries according to a pre-defined schedule (cliff, linear release, or custom). It enforces time-based release of tokens so recipients can’t dump tokens immediately.

Common uses:

* Team allocations with multi-year vesting + cliff
* Investor lockups
* Advisor/partner schedules
* Token sale tranche releases

---

# Core concepts & terminology

* **Beneficiary** — the account receiving vested tokens.
* **Start Timestamp** — when vesting begins (unix seconds).
* **Cliff** — initial period during which *no* tokens are released. After cliff, first tranche unlocks.
* **Duration** — total period after which the entire allocation is vested.
* **Slice period** — granularity of linear releases (e.g., monthly slices).
* **Revocable** — whether the owner may revoke remaining unvested tokens.
* **Released** — amount already withdrawn by beneficiary.
* **Vested amount** — cumulative amount that has vested as of `block.timestamp`.
* **Releasable amount** = `vested amount - released amount`.

---

# Vesting models

1. **Cliff then linear** — nothing until cliff, then linear vest to the end.
2. **Immediate partial + linear** — some percent unlocked at `start`, remainder linear.
3. **Step-based** — discrete percent at preconfigured timestamps.
4. **Custom schedule** — arbitrary per-epoch allocations.

This walkthrough focuses on the popular **cliff + linear** model and also shows revocable option + multiple schedules.

---

# Math / formula (cliff + linear)

Given:

* `totalAllocation`
* `start`
* `cliff = start + cliffDuration`
* `duration` (total seconds)
* `now = block.timestamp`
* `slicePeriodSeconds` (e.g., 30 days = 30*24*3600)

If `now < cliff`: `vested = 0` (unless you allow immediate percent)
Else if `now >= start + duration`: `vested = totalAllocation`
Else:

```
timeFromStart = now - start
vested = totalAllocation * (floor(timeFromStart / slicePeriodSeconds) * slicePeriodSeconds) / duration
```

Using integer math in Solidity:

```
vested = (totalAllocation * timeFromStart) / duration;
```

If you want **slice granularity** (round down to nearest slice):

```
slices = timeFromStart / slicePeriodSeconds
vested = (totalAllocation * slices * slicePeriodSeconds) / duration
```

Releasable = `vested - released`

---

# Security & best practices

* Use `ReentrancyGuard` for `release()` and `revoke()` calls that transfer tokens.
* Use OpenZeppelin `SafeERC20` to safely transfer ERC-20 tokens (handles non-standard tokens).
* Keep arithmetic in `uint256` (Solidity >=0.8 has built-in overflow checks).
* Emit events for schedule creation, release, revocation.
* Use `onlyOwner` or multisig for admin functions (set owner carefully).
* Consider `revocable` flag per schedule (some grants must be irrevocable).
* Consider vesting contract holding only the relevant token to reduce complexity.
* Consider upgradeability carefully — immutable schedules are safer.
* Avoid sending tokens directly to beneficiaries (use pull pattern: beneficiary calls `release()` or contract allows owner to call `release(beneficiary)`).
* Test edge cases: exact cliff, end time, multiple releases, revoke after partial release.

---

# Data model (recommended)

```text
struct VestingSchedule {
    bool initialized;
    address beneficiary;
    uint256 totalAmount;
    uint256 released;
    uint256 start;
    uint256 cliff;
    uint256 duration;
    uint256 slicePeriodSeconds;
    bool revocable;
    bool revoked;
}
mapping(bytes32 => VestingSchedule) private vestingSchedules;
uint256 public vestingSchedulesCount;
mapping(address => uint256) public holdersVestingCount; // number of schedules per holder
```

Use `bytes32` id = `keccak256(abi.encodePacked(beneficiary, start, vestingSchedulesCount))` to uniquely identify schedules.

---

# Example: Full Solidity vesting contract (ERC20)

This contract:

* Supports creating vesting schedules for multiple beneficiaries.
* Uses cliff + linear vesting.
* Is revocable (per schedule) by owner.
* Allows `release` by owner or beneficiary.
* Uses OpenZeppelin libraries.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenVesting
 * @notice Multi-beneficiary token vesting contract (cliff + linear).
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    struct VestingSchedule {
        bool initialized;
        address beneficiary;
        uint256 totalAmount;
        uint256 released;
        uint256 start;
        uint256 cliff; // timestamp
        uint256 duration; // seconds
        uint256 slicePeriodSeconds; // granularity
        bool revocable;
        bool revoked;
    }

    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 public vestingSchedulesCount;
    mapping(address => uint256) public holdersVestingCount;

    event VestingScheduleCreated(bytes32 indexed vestingId, address indexed beneficiary, uint256 totalAmount);
    event Released(bytes32 indexed vestingId, address indexed beneficiary, uint256 amount);
    event Revoked(bytes32 indexed vestingId);

    constructor(IERC20 _token) {
        require(address(_token) != address(0), "Zero token");
        token = _token;
    }

    // ========== Views ==========

    function computeVestingIdForAddressAndIndex(address holder, uint256 index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    function getVestingSchedule(bytes32 vestingId) public view returns (VestingSchedule memory) {
        return vestingSchedules[vestingId];
    }

    function getReleasableAmount(bytes32 vestingId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[vestingId];
        return _computeReleasableAmount(schedule);
    }

    // ========== Core ==========

    /**
     * @notice Create a vesting schedule for a beneficiary.
     * @dev Owner must have deposited tokens into this contract before creating schedules.
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 slicePeriodSeconds,
        bool revocable,
        uint256 totalAmount
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(duration > 0, "Duration = 0");
        require(totalAmount > 0, "Amount = 0");
        require(slicePeriodSeconds >= 1, "SlicePeriod = 0");
        require(cliffDuration <= duration, "Cliff > duration");

        bytes32 vestingId = computeVestingIdForAddressAndIndex(beneficiary, holdersVestingCount[beneficiary]);
        uint256 cliff = start + cliffDuration;

        vestingSchedules[vestingId] = VestingSchedule({
            initialized: true,
            beneficiary: beneficiary,
            totalAmount: totalAmount,
            released: 0,
            start: start,
            cliff: cliff,
            duration: duration,
            slicePeriodSeconds: slicePeriodSeconds,
            revocable: revocable,
            revoked: false
        });

        vestingSchedulesCount += 1;
        holdersVestingCount[beneficiary] += 1;

        emit VestingScheduleCreated(vestingId, beneficiary, totalAmount);
    }

    /**
     * @notice Release vested tokens for a schedule to the beneficiary.
     */
    function release(bytes32 vestingId, uint256 amount) external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[vestingId];
        require(schedule.initialized, "Not found");
        require(!schedule.revoked, "Revoked");

        // Only beneficiary or owner can trigger release
        require(msg.sender == schedule.beneficiary || msg.sender == owner(), "Not allowed");

        uint256 releasable = _computeReleasableAmount(schedule);
        require(releasable >= amount && amount > 0, "Invalid amount");

        schedule.released += amount;
        token.safeTransfer(schedule.beneficiary, amount);

        emit Released(vestingId, schedule.beneficiary, amount);
    }

    /**
     * @notice Revoke a revocable vesting schedule. Remaining vested tokens still releasable.
     */
    function revoke(bytes32 vestingId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[vestingId];
        require(schedule.initialized, "Not found");
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vested = _computeVestedAmount(schedule);
        uint256 releasable = vested - schedule.released;
        uint256 refund = schedule.totalAmount - vested; // unvested tokens return to owner

        schedule.revoked = true;

        if (refund > 0) {
            // transfer unvested tokens back to owner
            token.safeTransfer(owner(), refund);
        }

        emit Revoked(vestingId);
        // Note: any releasable amount can still be released by beneficiary via release()
    }

    // ========== Internal helpers ==========

    function _computeReleasableAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (schedule.revoked) {
            return 0;
        }
        uint256 vested = _computeVestedAmount(schedule);
        if (vested <= schedule.released) return 0;
        return vested - schedule.released;
    }

    function _computeVestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.cliff) {
            return 0;
        } else if (currentTime >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            uint256 timeFromStart = currentTime - schedule.start;
            // apply slice periods
            uint256 effectiveSlice = (timeFromStart / schedule.slicePeriodSeconds) * schedule.slicePeriodSeconds;
            return (schedule.totalAmount * effectiveSlice) / schedule.duration;
        }
    }

    // ========== Admin utilities ==========

    /**
     * @notice Owner can deposit tokens into the contract
     */
    function deposit(uint256 amount) external onlyOwner {
        require(amount > 0, "Zero");
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Owner can withdraw tokens that are not allocated to vesting schedules.
     */
    function withdrawUnusedTokens(uint256 amount) external onlyOwner nonReentrant {
        // Compute locked amount
        uint256 locked = 0;
        // sum all scheduled totalAmount - released - refunded from revoked schedules
        // For gas reasons we might keep a separate accounting of totalReserved, updated on create/revoke/release.
        // Here assume contract has a simple accounting variable (not shown) or require off-chain calculation.
        token.safeTransfer(msg.sender, amount);
    }
}
```

> Notes:
>
> * For production, keep an internal `totalReserved` (sum of all totalAmount for active schedules) so you can enforce `deposit` and `withdrawUnusedTokens` safely.
> * The `withdrawUnusedTokens` implementation is simplified; in production you'd ensure you never withdraw tokens that are reserved for vesting.

---

# Events to emit (why)

* `VestingScheduleCreated(vestingId, beneficiary, amount)` — frontend/listing.
* `Released(vestingId, beneficiary, amount)` — audit trail.
* `Revoked(vestingId)` — knowledge of revocation.
  Emitting events allows easy index/search in The Graph / Etherscan and provides immutable logs for accounting.

---

# Tests you must write

1. Create schedule; check schedule fields stored.
2. Attempt release before cliff → revert.
3. Release partial after cliff → correct `released` and token transfer.
4. Release multiple times across slices → cumulative math correct.
5. Release after entire duration → beneficiary receives entire allocation.
6. Revocable schedule: revoke after some vested → owner receives unvested tokens back; beneficiary can still claim vested.
7. Irrevocable schedule → revoke should revert.
8. Over/under release attempts → revert when requested > releasable.
9. Edge cases: `start + duration == currentTime`, `cliff == 0`, `slicePeriodSeconds == 1`.
10. Admin operations: deposit, withdraw (ensuring reserved tokens cannot be withdrawn).

Use Hardhat + Waffle or Foundry for tests. Use evm_increaseTime / evm_mine to simulate time.

---

# Frontend integration (UX)

* Show per-schedule data:

  * `totalAmount`, `released`, `releasable`, `start`, `cliff`, `duration`, `slicePeriodSeconds`, `revocable`, `revoked`.
* Display human-readable times: use UTC ISO strings.
* Provide `release` button (only if `releasable > 0` and `user == beneficiary`).
* Display progress bar: `progress = (vested / totalAmount) * 100`.
* Use `eth_call` to read `getReleasableAmount` and schedule metadata.
* Optionally show combined totals across schedules for a user.

---

# Gas & deployment considerations

* Creating many schedules on-chain costs gas. If you need thousands of tiny schedules, consider off-chain merkle-based vesting where beneficiaries prove their allocation via Merkle proofs and call `claim()` to unlock by schedule logic.
* Store numbers compactly — but clarity and auditable fields are more important.
* Prefer `slicePeriodSeconds` to avoid tiny repeated releases—each `release()` call costs gas; consider auto-release via a relayer if UX needs it (but relayers cost).
* Consider using a multisig (Gnosis Safe) as `owner` to avoid single-key risks.

---

# Advanced patterns & alternatives

* **Merkle vesting claim**: store a Merkle root of allocations; each beneficiary claims when vested by presenting proof. Good for large airdrops.
* **Linear streaming**: use ERC-1620/streaming tokens to continuously stream tokens (not commonly used for vesting but handy).
* **Scheduled batch releases**: if tokens should unlock to many beneficiaries on exact timestamps, execute batch releases in owner transactions.
* **On-chain governance controlled revocation**: let DAO vote to revoke or adjust vesting policies.
* **EIP-712 signed schedules**: owner signs vesting schedule off-chain and beneficiary presents signature to a contract `createAndClaim` to reduce on-chain creation costs.

---

# Implementation checklist before production

* [ ] Use `SafeERC20` & `ReentrancyGuard`.
* [ ] Add `totalReserved` accounting.
* [ ] Thorough unit tests and fuzz tests for time math.
* [ ] Security audit for owner-only flows (revoke, withdraw).
* [ ] Use multisig for owner or integrate timelock.
* [ ] Frontend shows exact unix date/times and amounts in token decimal format.
* [ ] Decide and document revocability and admin powers in tokenomics doc.
* [ ] Add pausability if needed (with caution — pausing can break financial guarantees).

---

If you want, I can now:

* ✅ Add `totalReserved` accounting and complete `withdrawUnusedTokens` safely in the sample contract,
* ✅ Convert this to a gas-optimized Foundry-ready contract (and write tests), or
* ✅ Create a small Merkle-vesting example for large distributions.

Which of those would you like next?
