# QKey Rotation (MVP)

[![CI](https://github.com/MissCyber9/qkey-rotation/actions/workflows/ci.yml/badge.svg)](https://github.com/MissCyber9/qkey-rotation/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MissCyber9/qkey-rotation)](https://github.com/MissCyber9/qkey-rotation/releases)

# QKey Rotation (MVP)
Timelocked key rotation registry for EVM wallets with EIP-712 signatures and EIP-1271 (smart-wallet) support.

## Why
This is a pragmatic mitigation layer against key compromise and future cryptographic transitions:
- Timelocked key rotation (cancel window)
- Signature-based authorization (EOA) via EIP-712
- Contract-wallet authorization via EIP-1271 (Safe / AA-compatible)

## Features
- `init(wallet, owner, firstKey)`
- `propose(wallet, newKey)` / `cancel(wallet)` (owner-only)
- `activate(wallet)` permissionless after delay
- `proposeWithSig`, `cancelWithSig`, `setOwnerWithSig` (EIP-712)
- EOA + contract owner verification (EIP-1271)
- Anti-malleability ECDSA (low-s)

## Security model (MVP)
- Rotations are delayed by `DELAY` seconds.
- Owner can cancel a pending rotation during the delay.
- Activation is permissionless (liveness), but only activates the staged key.
- Nonces prevent replay for signature-based calls.

## Tests
From `contracts/`:
```bash
forge test -vv
forge test -vv --match-contract QKeyRotationInvariantSmart



## Security
- Threat model (v0.2.0): `spec/threat-model-v0.2.0.md`
- Security invariants (v0.2.0): `spec/security-invariants-v0.2.0.md`
- Limitations & non-goals (v0.2.0): `spec/limitations-nongoals-v0.2.0.md`
- ABI stability & upgrade policy (v0.2.0): `spec/abi-upgrade-policy-v0.2.0.md`

## Local Demo (Anvil)
Run a full local flow (deploy → init → propose → guardians cancel → propose → activate):

```bash
./demo/anvil-demo.sh
