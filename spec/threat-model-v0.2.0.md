# QKeyRotation v0.2.0 — Threat Model

## 1. Scope

### In scope (v0.2.0)
- EVM wallet / smart account key governance primitives
- Time-delayed key rotation (timelock)
- Guardian-based cancellation of pending rotations (anti-coercion / anti-hijack)
- Owner authorization (EOA or EIP-1271 smart account owner)
- On-chain observability and verifiability of rotation state

### Out of scope (explicit)
- Endpoint security (phone/PC malware, clipboard hijack, keylogger, etc.)
- Hardware wallet security (covered by QVault layer)
- Full L1 compromise / extreme reorgs beyond normal threat assumptions
- Cryptographic breaks of ECDSA (pre-quantum)
- Off-chain social engineering and identity verification

## 2. Actors and Assumptions

### Actors
- **Owner**: the authority controlling the wallet’s rotation policy (EOA or smart account).
- **Guardians**: a set of partially trusted parties that can veto a pending rotation.
- **On-chain adversary**: can observe mempool, attempt MEV/front-running, and spam transactions.
- **Coercive adversary**: can pressure the owner to sign under duress.

### Assumptions
- The contract is deployed correctly and users interact with the intended address/bytecode.
- L1 consensus is functioning normally (finality assumptions of the underlying chain hold).
- Not all guardians at/above threshold are compromised at the same time.
- The timelock delay is set large enough to allow intervention (human/ops response).

## 3. Threats Mitigated by v0.2.0

### T1 — Temporary owner key compromise
**Scenario:** the owner key is exposed briefly (phishing/malware/hot-wallet leakage).  
**Mitigation:** rotations are not instantaneous; guardians can cancel pending rotations before activation.  
**Residual risk:** if attacker controls owner long enough and guardians do not respond in time.

### T2 — Coercion to rotate keys
**Scenario:** the owner is forced to authorize a key change under duress.  
**Mitigation:** the rotation is delayed; guardians can veto (cancel) during the delay window.  
**Residual risk:** v0.2.0 does not provide deniable/undetectable duress signaling (QVault layer).

### T3 — MEV/front-running around rotation transactions
**Scenario:** adversary tries to reorder, front-run, or exploit rotation-related calls.  
**Mitigation:** no immediate effect; activation is time-based; no direct value extraction pathway.  
**Residual risk:** L1-level censorship could delay guardian intervention (operational mitigations needed).

### T4 — Single guardian compromise
**Scenario:** one guardian is malicious or compromised.  
**Mitigation:** threshold (M-of-N) prevents unilateral action; guardians cannot seize control (cancel-only).  
**Residual risk:** threshold-wide compromise is out of scope for v0.2.0.

## 4. Threats NOT Mitigated (Non-Goals)

### NT1 — Owner + threshold guardians compromised
Out of scope for v0.2.0; addressed by higher layers (QVault device attestation, operational controls).

### NT2 — Guardians forcing a new active key
v0.2.0 does not allow guardians to set a new key; guardians can only cancel a pending rotation.

### NT3 — Post-quantum cryptographic security
v0.2.0 is *quantum-aware* (upgrade path), not *quantum-safe* at the signature primitive level.
Hybrid keysets / PQ enforcement are planned in later versions and/or L1 design.

### NT4 — Endpoint compromise (UI malware, clipboard hijack, supply chain attacks)
Out of scope for a smart contract primitive; intended to be mitigated by QVault (hardware + attestation).

## 5. Security Guarantees (What v0.2.0 Claims)

- A non-zero active key exists after initialization.
- Rotation activation cannot happen before the timelock delay elapses.
- Guardians can cancel a pending rotation without the owner key.
- Guardian actions cannot transfer control; they are veto-only in v0.2.0.
- All rotation state transitions are publicly verifiable on-chain.

## 6. Positioning

QKeyRotation v0.2.0 is not a full custody solution. It is a composable key-governance primitive
meant to be integrated into higher-level systems (QVault hardware layer and future L1 designs).
