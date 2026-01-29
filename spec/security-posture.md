# Security Posture (Project Summary)

This repository implements key-governance primitives intended for high-assurance usage.
Security posture is based on explicit boundaries, formal invariants, and reproducible verification.

## Verification
- Provenance: `spec/verify-provenance-v0.2.0.md`
- Releases are tag-based; signed tags preferred.
- CI runs Foundry build/tests/invariants for every push and pull request.

## Threat Model & Boundaries
- Threat model: `spec/threat-model-v0.2.0.md`
- Limitations / non-goals: `spec/limitations-nongoals-v0.2.0.md`

## Formalized Guarantees
- Security invariants: `spec/security-invariants-v0.2.0.md`
- Invariants are exercised through Foundry invariant tests (property-based testing).

## Upgrade Discipline
- ABI stability & upgrade policy: `spec/abi-upgrade-policy-v0.2.0.md`

## Demo Reproducibility
- Local demo (Anvil): `./demo/anvil-demo.sh`

## Disclosure
- Security reporting policy: `SECURITY.md`
