# MultiSigWallet v1 — Self-Audit

Date started: 2026-07-13  
Scope: `multisig-wallet/src/MultiSigWallet.sol`  
Checklist used: `audit-dojo/checklists/personal-checklist-v1.md`

## Summary

- v1 scope reviewed after `receive()` and README landed.
- No new critical issues identified inside the intended fixed-owner multisig scope.
- Notes below are checklist-driven limitations / improvement points, not judged contest findings.

## Note 1 — Input Validation: zero-address owner is not rejected

- **Checklist section:** Input Validation
- **Observation:** Constructor rejects empty owner array, duplicate owners, zero threshold, and threshold greater than owner count, but it does not reject `address(0)` inside `_owners`.
- **Risk:** A zero-address owner slot is unusable. In a poorly chosen configuration, this can contribute to an unreachable threshold and operationally lock part or all of the wallet approval process.
- **Current impact:** Low in honest deployment flow, because deployer chooses the owner set and threshold up front.
- **Recommendation:** Add an explicit zero-address owner check in the constructor, or keep it documented as an accepted v1 limitation if no further code changes are planned.

## Note 2 — Event Correctness / Observability: `receive()` emits no deposit event

- **Checklist section:** Event Correctness
- **Observation:** `receive() external payable {}` accepts plain ETH transfers but does not emit a `Deposit` / `Receive` event.
- **Risk:** Off-chain monitoring is weaker. Inbound funding must be inferred from traces, transaction history, or balance deltas instead of contract logs.
- **Current impact:** Informational. This does not break fund custody or execution correctness.
- **Recommendation:** Optional v2 improvement: emit a deposit event with `msg.sender` and `msg.value` if better indexing / monitoring is desired.

## Note 3 — External Call Diagnostics: insufficient balance is folded into generic execution failure

- **Checklist section:** External Calls
- **Observation:** `executeTransaction` forwards `transactions[_txIndex].value` using a low-level call and reverts with `MultiSigWallet__TxExecutionFailed()` on failure. There is no dedicated insufficient-balance custom error.
- **Risk:** Operator diagnostics are weaker. An underfunded wallet and a reverting target contract collapse into the same external symptom.
- **Current impact:** Informational. Safety is not broken because the whole execution reverts and the earlier `executed = true` write is rolled back.
- **Recommendation:** Optional improvement only. Keep generic failure for minimal v1, or add a pre-check / dedicated error if clearer operator feedback becomes important.

## Conclusion

- Technical Day 40 goals are now represented on disk: `receive()`, receive test, README, and self-audit start.
- Remaining decision is process, not code: whether to keep these notes as accepted v1 limitations or open a follow-up patch for the zero-address owner validation.
