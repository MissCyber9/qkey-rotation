# QKeyRotation v0.2.0 — Security Invariants

This document defines the invariants (properties that must always hold) for QKeyRotation v0.2.0.
They are designed to be:
- machine-checkable via Foundry tests (unit + invariants),
- reviewable by auditors,
- stable as a contract-level safety baseline for higher layers (QVault, L1).

## Terminology
- **wallet**: the logical wallet identity tracked in the registry (address key in mappings).
- **owner**: the authority allowed to propose/cancel rotations and manage guardian set.
- **activeKey**: the currently active key for a wallet (non-zero after init).
- **pending rotation**: (newKey, eta, exists) stored while a timelock is running.
- **guardians**: a set of addresses allowed to veto a pending rotation (cancel-only in v0.2.0).

## Core Safety Invariants

### INV-1: Active key is never zero after initialization
**Property:** If a wallet has been initialized, then `activeKeyOf(wallet) != address(0)`.  
**Rationale:** Prevents a “bricked” wallet state.  
**Validation:** Foundry invariant tests (activeKeyNeverZero after init).

### INV-2: Owner is never zero after initialization
**Property:** If a wallet has been initialized, then `ownerOf(wallet) != address(0)`.  
**Rationale:** Prevents unowned state that could block governance.  
**Validation:** Foundry invariants / handler-based invariants.

### INV-3: Pending rotation newKey is never zero when pending exists
**Property:** If `pendingOf(wallet).exists == true`, then `pendingOf(wallet).newKey != address(0)`.  
**Rationale:** Prevents storing an invalid pending rotation.  
**Validation:** Handler-based invariants.

### INV-4: Timelock is enforced for activation
**Property:** Activation must fail if `block.timestamp < pending.eta`.  
**Rationale:** Ensures time-delayed safety window exists.  
**Validation:** Unit tests (propose then activate only after delay).

### INV-5: Activation clears pending state
**Property:** After a successful `activate(wallet)`, `pendingOf(wallet).exists == false`.  
**Rationale:** Prevents replay/duplicate activations.  
**Validation:** Unit tests; may also be asserted in invariants.

### INV-6: Cancel clears pending state (owner cancel path)
**Property:** After a successful owner cancellation, `pendingOf(wallet).exists == false`.  
**Rationale:** Ensures veto takes effect and removes pending rotation.  
**Validation:** Unit tests.

## Authorization Invariants

### INV-7: Only the owner can propose or cancel (owner-only paths)
**Property:** Calls that change rotation state through owner-only entrypoints must revert if caller is not owner.  
**Rationale:** Prevents unauthorized rotations.  
**Validation:** Unit tests (onlyOwnerCanProposeOrCancel).

### INV-8: Guardian actions cannot seize control (cancel-only guarantee)
**Property:** Guardian entrypoints must not directly set `activeKey` or `owner`. They may only cancel pending state.  
**Rationale:** Guardians are veto parties, not controllers, in v0.2.0.  
**Validation:** Code review + tests (guardian cancel pending; activeKey unchanged).

## Signature / Account-Model Invariants (if enabled in your build)

### INV-9: EOA signature path must be non-malleable
**Property:** ECDSA signatures must enforce low-s and valid v (27/28).  
**Rationale:** Prevent signature malleability and weird edge cases.  
**Validation:** Unit tests + `_splitSig` checks.

### INV-10: EIP-1271 owner must validate signatures through `isValidSignature`
**Property:** For smart account owners, signature authorization must use EIP-1271 validation.  
**Rationale:** Supports AA/smart wallets safely.  
**Validation:** Unit tests (1271 test).

## Guardian-Set Invariants (if guardians are enabled)

### INV-11: Guardian threshold is bounded
**Property:** `0 <= threshold <= guardianCount` (implementation-specific constraints).  
**Rationale:** Prevents impossible security configurations.  
**Validation:** Unit tests (if present) + require checks.

### INV-12: Duplicate guardians are not allowed
**Property:** Adding the same guardian twice must revert / have no effect (implementation-specific).  
**Rationale:** Prevents threshold inflation tricks and ambiguity.  
**Validation:** Unit tests (recommended to add in v0.2.x if not already).

## Operational Invariants (Non-cryptographic but critical)

### INV-13: State transitions are observable and attributable
**Property:** Rotation state transitions should emit events with wallet + actor + key info where applicable.  
**Rationale:** Enables monitoring, alerting, and incident response.  
**Validation:** Event emission checks (recommended).

## Known Limits (Not Invariants)
- v0.2.0 does not provide deniable duress signaling (QVault layer).
- v0.2.0 is quantum-aware, not quantum-safe at the signature primitive level.
- If owner + threshold guardians are compromised, safety guarantees do not hold (out of scope).

