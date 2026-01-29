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


