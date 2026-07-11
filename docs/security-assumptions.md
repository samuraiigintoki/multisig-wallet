# MultiSigWallet — Security Assumptions

This document records the assumptions made during design and implementation of MultiSigWallet v1. Each assumption is stated, the risk it introduces if violated, and how the code enforces it.

---

## 1. Owner set is correct and complete at deployment

**Assumption:** The addresses passed to the constructor are the intended and only owners. No address is mistakenly included or excluded.

**Risk if violated:** An unintended address can submit and confirm transactions, draining funds. A missing owner means the threshold may never be reachable.

**Enforcement:** Constructor validates:

- Owners array is not empty (`EmptyOwnersArray`).
- No duplicates in the owners array (`DuplicateOwner`).
- Threshold is not zero (`ZeroThreshold`).
- Threshold does not exceed owner count (`ThresholdTooHigh`).

**Residual risk:** v1 does not verify that owner addresses are externally owned accounts (not contracts). A contract owner cannot sign transactions directly — it would need to implement a multisig execution interface. This is not blocked but is out of scope for v1.

---

## 2. Threshold is set to a safe value

**Assumption:** `_threshold` is chosen such that a sufficient number of owners must approve any transaction before execution. A threshold of 1-of-N provides no security benefit. A threshold of N-of-N creates a single-point-of-failure if any owner key is lost.

**Risk if violated:** `threshold = 1` means any single owner can unilaterally execute any transaction. `threshold = N` means losing one owner key renders the wallet irrecoverably locked.

**Enforcement:** Constructor checks `_threshold > 0` and `_threshold <= owners.length`. It does not enforce a minimum or maximum beyond those bounds. The deployer must choose correctly.

---

## 3. Each transaction lifecycle step is atomic and isolated

**Assumption:** `submitTransaction`, `confirmTransaction`, `revokeConfirmation`, and `executeTransaction` are each atomic. No intermediate state is visible to or exploitable by another call in the same transaction.

**Risk if violated:** Cross-function reentrancy or cross-transaction state manipulation could cause confirmation counts or execution flags to become inconsistent.

**Enforcement:** All state changes in v1 are synchronous. No external calls are made during `submitTransaction` or `confirmTransaction`. `executeTransaction` (planned) will make the single external call last (after effects), following CEI. No reentrancy guard is needed at the function level — the executed flag check on entry and CEI in execute together prevent double-execution, provided execute is the only function that calls external contracts.

---

## 4. Confirmation counts are derived, not stored as primary state

**Assumption:** The confirmation count for a transaction is not stored directly. It is derived by querying `isConfirmed[txIndex][owner]` for each owner and counting `true` values.

**Risk if violated:** If the `isConfirmed` nested mapping is correct, the count is always accurate. If `confirmTransaction` or `revokeConfirmation` has a bug (double-write or missed write), the derived count becomes unreliable. This design trades storage cost for correctness — there is no cached count that could diverge from the source of truth.

**Enforcement:** No `confirmationCount` field is stored. Derived count is the only source.

---

## 5. No automatic self-confirmation

**Assumption:** The owner who submitted a transaction is not automatically counted as a confirmer. They must call `confirmTransaction` explicitly.

**Risk if violated:** If a submitter were auto-confirmed, a 2-of-3 wallet would effectively become 1-of-3 for any transaction the submitter proposes (they count as their own confirmation).

**Enforcement:** `confirmTransaction` records `isConfirmed[txIndex][msg.sender]`. The submitter is `msg.sender` of `submitTransaction`, but that value is not automatically applied to `isConfirmed`. Explicit call required.

---

## 6. Executed transactions are final

**Assumption:** Once `transactions[i].executed` is `true`, no further state changes (confirmation, revocation) are possible for that transaction index.

**Risk if violated:** If a confirmed, executed transaction could have its confirmations revoked, the state becomes inconsistent. If it could be re-confirmed, it could potentially be re-executed (dependent on execute's threshold check).

**Enforcement:** `confirmTransaction` reverts if `transactions[_txIndex].executed == true`. `revokeConfirmation` (future day) will also check this flag. `executeTransaction` (future day) will set it before the external call.

---

## 7. Contract receives no ETH by default

**Assumption:** The wallet contract may receive ETH via `receive()` for use in transactions. There is no强制性的 minimum balance requirement.

**Risk if violated:** Executed transactions that send ETH will revert if the contract balance is insufficient. No protective deposit mechanism exists in v1.

**Enforcement:** `receive()` is not yet implemented. ETH forwarding will depend on `executeTransaction` (not yet written).

---

## 8. Access control is enforced by `onlyOwner` alone

**Assumption:** Every state-changing function that should be owner-only uses the `onlyOwner` modifier, and `onlyOwner` correctly checks `isOwner[msg.sender]`.

**Risk if violated:** A missing or incorrect modifier would allow non-owners to call restricted functions.

**Enforcement:** `onlyOwner` uses `require(isOwner[msg.sender], "not owner")`. `isOwner` is populated in the constructor and never modified afterward. No function in v1 can add, remove, or reassign owners.

---

## Out of scope for v1

- Upgradeability
- Time-locks
- Module-based multisig (Gnosis Safe proxy pattern)
- EIP-712 off-chain signature aggregation
- Owner recovery mechanism
- Rate limiting
- Transaction batching
- ERC-1271 signature verification (contract owners)


## State-transition notes — confirmation and revoke flow

Confirmations are modeled as a per-transaction per-owner boolean:

- `false -> true` happens only through `confirmTransaction`.
- `true -> false` happens only through `revokeConfirmation`.
- A missing transaction index cannot enter either transition.
- An executed transaction cannot receive new confirmations or have existing confirmations revoked.
- A caller cannot revoke unless they previously confirmed the same transaction.
- Revoke is intentionally strict, not idempotent: calling `revokeConfirmation` while already unconfirmed reverts with `TxNotConfirmed`.

This keeps the confirmation lifecycle explicit and auditable. Duplicate confirms are rejected, empty revokes are rejected, and finalized transactions are immutable with respect to confirmation state.