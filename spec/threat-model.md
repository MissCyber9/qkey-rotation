# Threat Model (MVP)

## Assets
- activeKeyOf(wallet): current active key used by the wallet policy layer
- pendingOf(wallet): staged key awaiting timelocked activation
- ownerOf(wallet): authority controlling rotations

## Adversaries
- A1: remote attacker with phishing capability
- A2: malware on user's machine
- A3: coercer forcing immediate transfers
- A4: insider / compromised owner key

## Goals
- Prevent silent instant key swap (timelock + cancel window)
- Limit damage window (rotation is delayed; can be cancelled)
- Make activation permissionless but safe (only activates staged key)

## Non-goals (MVP)
- True on-chain post-quantum signatures
- Full social recovery / guardians
- Hardware attestation

## Key mitigations
- Timelocked rotation (DELAY)
- Owner-only propose/cancel
- Permissionless activate after delay (liveness)
