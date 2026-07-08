# MultiSigWallet — Architecture Flow

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
2. **Effects** - marks the transaction as executed *before* the external call.
3. **Interactions** - sends ETH or makes the external call to the target address.

Because the executed flag is set *before* the external call, a re-entrant callback would see the transaction as already executed and revert. This prevents double-execution.

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
