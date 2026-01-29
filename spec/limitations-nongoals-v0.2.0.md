# QKeyRotation v0.2.0 — Limitations & Non-Goals

This document clarifies what QKeyRotation v0.2.0 intentionally does NOT do.
It prevents over-claiming security properties and provides clean boundaries
for future versions (v0.3+) and higher layers (QVault, L1).

## 1. Security Boundaries (What v0.2.0 is NOT)

### Not a full wallet or custody system
QKeyRotation is a composable key-governance primitive. It does not provide:
- asset management, spending logic, or transaction validation for all wallet operations,
- a full account abstraction framework,
- complete custody controls (MPC/HSM policy orchestration).

### Not endpoint security
v0.2.0 cannot protect against:
- malware on phone/PC,
- clipboard hijacking,
- compromised browser extensions,
- SIM swaps or account takeovers off-chain.

These are addressed by higher layers (QVault hardware + attestation, operational controls).

### Not post-quantum secure at the signature primitive level
v0.2.0 is *quantum-aware*, not *quantum-safe*:
- It may still rely on ECDSA/secp256k1 for EOA signatures.
- True PQ security requires hybrid keysets and/or PQ signature verification, planned later.

## 2. Threats Out of Scope (Explicit)

### Owner + threshold guardians compromise
If an attacker controls the owner AND enough guardians to meet the threshold,
v0.2.0 cannot guarantee safety. Mitigation belongs to:
- diversified guardian selection,
- hardware-backed guardian keys (QVault),
- operational monitoring and response playbooks,
- future recovery policies.

### Chain-level failures and censorship
v0.2.0 assumes normal L1 conditions. It does not solve:
- prolonged censorship preventing guardian actions,
- extreme reorgs beyond standard finality assumptions,
- consensus compromise.

Higher-layer mitigations include multi-chain monitoring, fallback policies, and L1 design choices.

### Social engineering and identity verification
v0.2.0 cannot verify human identity or intent. It does not prevent:
- tricking guardians into cooperating,
- impersonation attacks off-chain.

This is handled by operational procedures and/or QVault UX safeguards.

## 3. Functional Non-Goals (v0.2.0)

### Guardians cannot recover by setting a new key
In v0.2.0, guardians are veto-only:
- They can cancel pending rotations.
- They cannot set a new active key or take control.

A recover-to-new-key path is a planned feature for later versions with strict policy controls.

### No “deniable duress mode”
v0.2.0 does not include a stealth/deniable duress mechanism.
Such mechanisms require:
- hardware interaction,
- secure UI/UX,
- attestation,
- offline policy enforcement.

This is a core objective of QVault.

### No spending caps, rate limits, or policy engine
v0.2.0 focuses on rotation governance.
Transaction policies (caps, cooldowns, allowlists, session keys) are out of scope and planned in v0.3+.

### No upgrade/migration framework guaranteed
Unless explicitly implemented, v0.2.0 does not guarantee proxy-based upgrades or automatic state migration.
Upgrade strategy must be defined as part of release engineering and future architecture decisions.

## 4. Compatibility Limits

### Wallet “address” vs “account”
v0.2.0 tracks a `wallet` address as an identifier. It does not enforce that
the wallet is an EOA or a smart contract; higher layers must decide how to bind identity.

### Event completeness
If event coverage is incomplete, off-chain monitoring may require direct state reads.
Event completeness can be improved in later versions without changing core safety properties.

## 5. Summary

QKeyRotation v0.2.0 provides:
- time-delayed rotations,
- guardian cancellation of pending rotations,
- EOA/EIP-1271 signature paths (if enabled),
- audit-friendly invariants with Foundry tests.

It does not provide:
- full custody,
- endpoint security,
- PQ signature security,
- deniable duress UX,
- recovery-to-new-key by guardians,
- policy engine (caps/cooldowns).

These are intentionally deferred to keep v0.2.0 small, verifiable, and composable.
