## Goal

This multisig wallet securely manages assets and executes smart contract calls by requiring a predefined majority of trusted owners to approve every transaction before it can be processed.

## Users

- **Wallet owner** - a signer/approver in the multisig set. Can submit, confirm, revoke, and execute transactions.
- **Target address** - the recipient of an executed ETH transfer or external call. Passive; does not interact with the multisig directly.
- **Unauthorized address (attacker)** - any address not in the owner set. Must be blocked from all owner-only actions.

## Functions

- `submitTransaction` - owner proposes a new transaction
- `confirmTransaction` - owner approves a proposed transaction
- `revokeConfirmation` - owner cancels a previous approval
- `executeTransaction` - runs the transaction once threshold is met
- `receive` - accepts incoming Ether