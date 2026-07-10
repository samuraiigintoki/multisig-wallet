# MultiSigWallet - Architecture Flow

## How it works (4-step lifecycle)

### 1. Owner submits a transaction

A wallet owner proposes an action: "send X ETH to address Y with calldata Z." The contract stores this proposal and assigns it a tracking number (transaction index). Nothing moves yet — it's just a draft sitting in storage.

### 2. Owners confirm

Other owners review the proposal. If they agree, they call `confirmTransaction` with the tracking number. The contract records their approval. A tally of unique confirmations is maintained per transaction.

### 3. Threshold reached

When the number of confirmations meets the predefined threshold (e.g. 2-of-3, 3-of-5), the transaction is approved and eligible for execution. It remains in this state until someone triggers execution — or until a confirmation is revoked, dropping the count below threshold again.

### 4. Execution occurs once

An owner calls `executeTransaction`. The contract:

1. **Checks** - is the transaction confirmed (threshold met)? Has it already been executed?
2. **Effects** - marks the transaction as executed _before_ the external call.
3. **Interactions** - sends ETH or makes the external call to the target address.

Because the executed flag is set _before_ the external call, a re-entrant callback would see the transaction as already executed and revert. This prevents double-execution.

If the external call fails, the entire execution reverts — the transaction stays pending and un-executed.

## Owner lifecycle

```
submit → confirm → (optionally revoke) → execute
```

## Security note

This design follows the Checks-Effects-Interactions (CEI) pattern in `executeTransaction` to prevent reentrancy on double-execution. The executed flag acts as a one-time guard per transaction index.

## Submit flow — implementation note

`submitTransaction` is the entry point to the lifecycle. It is owner-gated via the `onlyOwner` modifier (checks `isOwner[msg.sender]` — the same mapping populated during construction).

When called, the function:

1. Captures the current `transactions.length` as the transaction index.
2. Pushes a `Transaction` struct (`to`, `value`, `data`, `executed = false`) into the `transactions` array.
3. Emits `SubmitTransaction(msg.sender, txIndex, to, value, data)`.

The struct's `executed` field starts `false`. It is not touched by `confirmTransaction` or `revokeConfirmation` — only `executeTransaction` flips it to `true` (and does so before the external call, per CEI).

Transactions are indexed by their position in the array (`transactions[0]`, `transactions[1]`, ...). This index is how `confirmTransaction`, `revokeConfirmation`, and `executeTransaction` reference which transaction to operate on.

## Confirm flow — implementation note

`confirmTransaction(uint256 _txIndex)` is owner-gated via the existing `onlyOwner` modifier. It does three checks before recording a confirmation:

1. **Bounds** — `_txIndex >= transactions.length` → revert `TxDoesNotExist`.
2. **Duplicate-action prevention** — `isConfirmed[_txIndex][msg.sender] == true` → revert `TxAlreadyConfirmed`. This is the per-transaction per-owner idempotency guard. It prevents the same owner from inflating the confirmation count.
3. **Executed guard** — `transactions[_txIndex].executed == true` → revert `TxAlreadyExecuted`. Confirming a finalized transaction is a no-op with security implications (it could mask a race condition if execute were somehow bypassed).

The confirmation is recorded as `isConfirmed[_txIndex][msg.sender] = true` — a nested mapping (`mapping(uint256 => mapping(address => bool))`). This gives O(1) lookup for both "has owner X confirmed tx Y?" and "how many owners confirmed tx Y?" (derived by iterating owners or by maintaining a separate count mapping — the count is a derived value, not primary state).

No ETH moves in `confirmTransaction`. The event `ConfirmTransaction(owner, txIndex)` is emitted after the state write.

## Duplicate-action prevention — design note

The multisig lifecycle has two distinct places where duplicate-action prevention matters:

- **Constructor**: duplicate owners are rejected at deploy time (`DuplicateOwner`).
- **Confirm flow**: the `isConfirmed` nested mapping rejects a second confirmation by the same owner for the same transaction.

Without the confirm-flow guard, an owner could call `confirmTransaction` twice on the same tx, inflating the confirmation count without having called `revokeConfirmation` in between. The count would appear to meet the threshold when it shouldn't. This is the same class of bug as reentrancy and unidirectional token accounting — an action that should happen once happening more than once because state is not checked before the effect.

`revokeConfirmation` (future day) will unset `isConfirmed[_txIndex][msg.sender]` and must also be guarded against: cannot revoke if not confirmed, and cannot revoke after execution.
