# QKeyRotation v0.2.0 — ABI Stability & Upgrade Policy

This document defines the ABI stability expectations for QKeyRotation v0.2.0
and the official upgrade policy. It is intended to reduce integration risk
for downstream systems (QVault, wallets, L1 components, SDKs).

## 1. ABI Stability Statement (v0.2.0)

### Status: Stable-for-v0.2
- The v0.2.0 public ABI is considered stable for the v0.2.x line.
- Backward-compatible additions MAY be introduced in v0.2.x (e.g., new view helpers).
- Breaking changes MUST NOT be introduced in v0.2.x.

### What counts as a breaking change
- Changing function signatures (name/args/returns)
- Changing event signatures (topics layout)
- Changing storage layout in a way that affects state interpretation
- Changing authorization semantics (who can call what)
- Changing revert conditions in ways that break integrations

## 2. Storage Layout Expectations

### Status: Fixed-for-v0.2.x
- Storage layout is treated as fixed across v0.2.x.
- Any storage additions (if required) must be append-only and must not reorder/overwrite existing slots.

## 3. Upgrade Model (Official)

### v0.2.0 deployment model: Non-proxy (default)
- v0.2.0 is deployed as a standard contract (no proxy assumed).
- Integrations SHOULD treat v0.2.0 addresses as immutable.

### Upgrades: Redeploy + Migrate (recommended for v0.3+)
For major feature expansions (v0.3+), the official policy is:
1. Deploy a new version at a new address.
2. Provide a migration tool / script to copy state or re-initialize per wallet.
3. Optionally provide an adapter contract for backward ABI compatibility.

Rationale:
- Simplifies auditing and reasoning.
- Reduces proxy-specific risks (admin key compromise, implementation swaps).
- Keeps the primitive minimal and verifiable.

## 4. Migration Strategy (Baseline)

### Wallet-scoped state
QKeyRotation stores state per `wallet` identity. A migration can be performed by:
- exporting wallet state from old contract (owner, activeKey, pending, guardians),
- initializing state in the new contract,
- setting guardians/threshold and policy parameters accordingly.

### Safety during migration
- If migration is performed, recommended operational steps include:
  - temporarily disabling rotation actions on the old registry (policy decision),
  - verifying new contract bytecode + release provenance,
  - running a small replay test (propose/cancel/activate) on testnet or Anvil.

## 5. Versioning Rules

### Semantic versioning (SemVer)
- Patch: v0.2.(x+1) — bug fixes, non-breaking helpers, documentation, test improvements.
- Minor: v0.(y+1).0 — feature additions that are ABI-compatible but may expand semantics.
- Major: v1.0.0 — stability pledge for long-term integrations.

### Release requirements (for any published version)
- Tag must exist (e.g., v0.2.0).
- Release notes must describe ABI/storage changes (if any).
- Foundry test suite must pass (unit + invariants).
- Security docs must be updated when behavior changes.

## 6. Integration Guidance

- Integrators should pin to tagged releases (v0.2.0) and verify commit hashes.
- For production use, prefer deployments that correspond to official signed releases.
- Do not rely on internal/private functions or storage introspection.

