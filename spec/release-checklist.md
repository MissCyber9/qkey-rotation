# Release Checklist (QKeyRotation)

This checklist defines the minimum requirements to publish an official release.

## 0) Preconditions
- Work on a clean branch (or main if disciplined).
- Local repo is synced: `git pull --rebase origin main`
- No uncommitted changes: `git status` is clean.

## 1) Code Quality Gates
- Build succeeds:
  - `cd contracts && forge build`
- Unit tests pass:
  - `forge test -vv`
- Invariants pass:
  - `forge test -vv --match-test invariant`
  - `forge test -vv --match-contract QKeyRotationInvariantSmart`

## 2) Security Documentation Gates
Ensure docs are current and accurate:
- Threat model: `spec/threat-model-v0.2.0.md`
- Security invariants: `spec/security-invariants-v0.2.0.md`
- Limitations & non-goals: `spec/limitations-nongoals-v0.2.0.md`
- ABI stability & upgrade policy: `spec/abi-upgrade-policy-v0.2.0.md`
- Verify & provenance: `spec/verify-provenance-v0.2.0.md`

## 3) Provenance Gates
- Tag is created (annotated at minimum; signed preferred).
- Tag points to intended commit:
  - `git rev-list -n 1 <TAG>`
- For signed tags:
  - `git tag -v <TAG>`

## 4) Release Publication Gates
- GitHub Release created:
  - `gh release create <TAG> --title ... --notes ...`
- Release notes include:
  - Summary of changes
  - Any ABI/storage implications
  - Test status statement
  - Verification pointer

## 5) Post-Release Verification
- Clone fresh and verify:
  - `git clone ...`
  - `git checkout <TAG>`
  - `cd contracts && forge test -vv`
- Optional: deploy to a public testnet and verify bytecode.
