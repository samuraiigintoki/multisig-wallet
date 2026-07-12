# MultiSigWallet v1

## Goal

- Lightweight Ethereum multisig wallet.
- Holds ETH and executes arbitrary external calls only after enough owner confirmations.
- Built as a small security-focused v1, not a Safe clone.

## Users

- **Owners** — fixed signer set defined at deployment.
- **Targets** — EOAs or contracts that receive ETH or calldata during execution.
- **Funders** — any address that sends ETH to the wallet through `receive()`.

## Contract Scope

- Fixed owner set.
- Fixed threshold set at deployment.
- ETH custody.
- Arbitrary call execution after threshold is met.

## Out of Scope

- Owner add/remove.
- Signature-based off-chain approvals.
- Timelocks.
- Upgradeability.
- Transaction batching.
- ERC-1271 / module system.

## Functions

- `constructor(address[] memory _owners, uint256 _threshold)`
  - initializes owners
  - rejects empty owners array
  - rejects duplicate owners
  - rejects zero threshold
  - rejects threshold greater than owner count

- `submitTransaction(address _to, uint256 _value, bytes calldata _data)`
  - owner proposes a transaction
  - stores target, ETH value, calldata, executed flag

- `confirmTransaction(uint256 _txIndex)`
  - owner confirms an existing unexecuted transaction
  - prevents duplicate confirmation by the same owner

- `revokeConfirmation(uint256 _txIndex)`
  - owner removes their prior confirmation
  - only allowed before execution

- `executeTransaction(uint256 _txIndex)`
  - owner executes once derived confirmations meet threshold
  - sends stored ETH value and calldata to the stored target
  - can execute only once

- `receive() external payable`
  - accepts plain ETH transfers
  - no access control

## Transaction Lifecycle

- submit
- confirm
- optionally revoke
- execute once threshold is met

## Invariants

- Owner set is fixed at deployment.
- `0 < threshold <= owners.length` at deployment.
- A transaction starts with `executed = false`.
- A transaction can transition from `executed = false` to `true` only once.
- An executed transaction cannot be confirmed again.
- An executed transaction cannot be revoked.
- An executed transaction cannot be executed again.
- Execution is allowed only when derived confirmations are `>= threshold`.
- The same owner cannot confirm the same transaction twice without revoking in between.

## Security Notes

- `executeTransaction` uses Checks-Effects-Interactions.
- `executed = true` is set before the external call.
- Failed external call reverts the transaction, so the earlier `executed` flag write is rolled back.
- Confirmation count is derived from `isConfirmed`, not cached in separate storage.
- `receive()` has no event in v1.
- No explicit insufficient-balance custom error; failed value transfer bubbles as execution failure.

## Current Test Coverage

- constructor validation tests
- submit flow tests
- confirm flow tests
- revoke flow tests
- execute flow tests
- receive ETH test

## Test Status

- Full suite currently: **23 / 23 passing**

## How to Run

```bash
forge build
forge test
```

## Project Structure

- `src/MultiSigWallet.sol`
- `test/MultiSigWallet.t.sol`
- `docs/architecture.md`
- `docs/security-assumptions.md`

## Design Tradeoffs

- Confirmation count is recomputed by looping over owners.
- This is less gas-efficient than cached counts.
- Chosen for simpler state and lower divergence risk in v1.

## Known Limitations

- No zero-address owner check.
- No deposit event.
- No owner rotation or recovery flow.
- No `fallback()` function; unknown selectors / non-empty calldata calls revert.
