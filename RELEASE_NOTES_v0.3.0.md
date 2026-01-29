# QKeyRotation v0.3.0 — Release Notes (Audit-grade)

## Scope
Production-grade, wallet-scoped key governance primitive:
- time-delayed key rotation,
- guardian veto / recovery semantics,
- policy-governed emergency freeze,
- EIP-712 meta-operation authorization.

## Highlights
- Policy engine: cooldowns, max rotations per window, freeze/unfreeze.
- Guardian recovery: quorum-based approvals + time delay.
- Keyset abstraction designed to evolve into hybrid/PQ without ECDSA lock-in.
- Canonical EIP-712 operation digest helper for SDK determinism.
- Foundry test suite: smoke test + invariant harness.

## Out of scope
- Full PQ signatures on-chain.
- Hardware attestation enforcement (only readiness/hooks).
- Formal proofs beyond property-based invariants.

## Reproducible verification
- `git checkout v0.3.0`
- `git submodule update --init --recursive`
- `forge clean && forge test -vvv`

## Dependencies
- OpenZeppelin Contracts and forge-std are pinned via git submodules for reproducible builds.
