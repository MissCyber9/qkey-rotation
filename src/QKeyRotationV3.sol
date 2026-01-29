// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {KeysetLib} from "./libraries/KeysetLib.sol";
import {EIP712Ops} from "./libraries/EIP712Ops.sol";

contract QKeyRotationV3 {
    using ECDSA for bytes32;

    // ---------- Types ----------
    enum OpType { ROTATE, RECOVER, FREEZE, UNFREEZE, UPDATE_POLICY, UPDATE_GUARDIANS }

    struct GuardianSet {
        address[] guardians;
        uint16 threshold;
        uint32 epoch;
    }

    struct Policy {
        uint32 rotationDelay;
        uint32 recoveryDelay;
        uint32 freezeMaxDuration;

        uint32 windowSeconds;
        uint16 maxRotationsPerWindow;
        uint32 minFinalizeCooldown;

        bool guardiansCanFreeze;
        bool guardiansCanRecover;
        bool ownerCanFreeze;
    }

    struct PendingOp {
        OpType  opType;
        uint32  createdAt;
        uint32  executableAt;
        uint32  expiresAt;
        uint32  guardianEpoch;
        bytes32 payloadHash;
        uint16  approvals;
        bool    canceled;
        bool    executed;
    }

    struct WalletState {
        // Owner key governance
        KeysetLib.Keyset ownerKeyset;

        // Guardians
        GuardianSet guardianSet;

        // Policy & emergency
        Policy policy;
        uint32 frozenUntil;

        // anti-spam / accounting
        uint32 lastFinalizeAt;
        uint32 windowStart;
        uint16 rotationsInWindow;

        // ops
        uint256 nonce;
        uint256 nextOpId;
        mapping(uint256 => PendingOp) ops;
        mapping(uint256 => mapping(address => bool)) approvedBy;
    }

    mapping(bytes32 => WalletState) internal W;

    // ---------- Events ----------
    event WalletInitialized(bytes32 indexed walletId, bytes32 ownerKeysetHash);
    event PolicyUpdated(bytes32 indexed walletId, bytes32 policyHash);
    event GuardiansUpdated(bytes32 indexed walletId, uint32 epoch, uint16 threshold, address[] guardians);

    event OpProposed(bytes32 indexed walletId, uint256 indexed opId, OpType opType, bytes32 payloadHash, uint32 executableAt, uint32 expiresAt);
    event OpApproved(bytes32 indexed walletId, uint256 indexed opId, address indexed guardian, uint16 approvals);
    event OpVetoed(bytes32 indexed walletId, uint256 indexed opId, address indexed guardian);
    event OpCanceled(bytes32 indexed walletId, uint256 indexed opId);

    event RotationExecuted(bytes32 indexed walletId, uint256 indexed opId, bytes32 oldKeysetHash, bytes32 newKeysetHash);
    event RecoveryExecuted(bytes32 indexed walletId, uint256 indexed opId, bytes32 oldKeysetHash, bytes32 newKeysetHash);

    event Frozen(bytes32 indexed walletId, uint32 frozenUntil, uint256 indexed opId);
    event Unfrozen(bytes32 indexed walletId, uint256 indexed opId);

    // ---------- Errors ----------
    error NotInitialized();
    error AlreadyInitialized();
    error Unauthorized();
    error WalletFrozen();      // renamed (was Frozen) to avoid collision with event Frozen
    error Cooldown();
    error RateLimited();
    error OpNotFound();
    error OpNotExecutable();
    error OpExpired();
    error OpCanceledOrExecuted();
    error BadPolicy();
    error BadGuardians();
    error BadSig();
    error Deadline();
    error GuardiansDisabled();
    error FreezeDisabled();

    // ---------- Init ----------
    function initWallet(
        bytes32 walletId,
        address owner,
        address[] calldata guardians,
        uint16 guardianThreshold,
        Policy calldata policy
    ) external {
        WalletState storage s = W[walletId];
        if (s.ownerKeyset.keysetHash != bytes32(0)) revert AlreadyInitialized();

        _validatePolicy(policy);
        _setOwnerKeyset(s, owner);
        _setGuardians(s, guardians, guardianThreshold);

        s.policy = policy;
        emit WalletInitialized(walletId, s.ownerKeyset.keysetHash);
        emit PolicyUpdated(walletId, keccak256(_encodePolicy(policy)));
    }

    // ---------- Views ----------
    function getOwnerECDSA(bytes32 walletId) external view returns (address) {
        WalletState storage s = W[walletId];
        if (s.ownerKeyset.keysetHash == bytes32(0)) revert NotInitialized();
        return KeysetLib.ecdsaAddress(s.ownerKeyset.keys[0]);
    }

    function getPolicy(bytes32 walletId) external view returns (Policy memory) {
        WalletState storage s = W[walletId];
        if (s.ownerKeyset.keysetHash == bytes32(0)) revert NotInitialized();
        return s.policy;
    }

    function getGuardians(bytes32 walletId) external view returns (GuardianSet memory) {
        WalletState storage s = W[walletId];
        if (s.ownerKeyset.keysetHash == bytes32(0)) revert NotInitialized();
        return s.guardianSet;
    }

    function getOp(bytes32 walletId, uint256 opId) external view returns (PendingOp memory) {
        WalletState storage s = W[walletId];
        if (s.ownerKeyset.keysetHash == bytes32(0)) revert NotInitialized();
        return s.ops[opId];
    }

    function isFrozen(bytes32 walletId) public view returns (bool) {
        return uint256(W[walletId].frozenUntil) > block.timestamp;
    }

    function getNonce(bytes32 walletId) external view returns (uint256) {
        return W[walletId].nonce;
    }

    // ---------- Core: Rotation ----------
    function proposeRotation(
        bytes32 walletId,
        address newOwner,
        uint256 deadline,
        bytes calldata ownerSig
    ) external returns (uint256 opId) {
        WalletState storage s = _state(walletId);
        if (isFrozen(walletId)) revert WalletFrozen();

        bytes32 payloadHash = keccak256(abi.encodePacked("ROTATE_TO", newOwner));
        _requireOwnerAuth(s, walletId, uint8(OpType.ROTATE), payloadHash, deadline, ownerSig);

        opId = _newOpId(s);
        uint32 execAt = uint32(block.timestamp + s.policy.rotationDelay);
        uint32 expAt  = uint32(block.timestamp + _defaultExpiry());

        s.ops[opId] = PendingOp({
            opType: OpType.ROTATE,
            createdAt: uint32(block.timestamp),
            executableAt: execAt,
            expiresAt: expAt,
            guardianEpoch: s.guardianSet.epoch,
            payloadHash: payloadHash,
            approvals: 0,
            canceled: false,
            executed: false
        });

        emit OpProposed(walletId, opId, OpType.ROTATE, payloadHash, execAt, expAt);
    }

    function vetoOp(bytes32 walletId, uint256 opId) external {
        WalletState storage s = _state(walletId);
        PendingOp storage op = s.ops[opId];
        _requireOpExists(op);

        if (!_isGuardian(s, msg.sender)) revert Unauthorized();
        if (op.canceled || op.executed) revert OpCanceledOrExecuted();

        op.canceled = true;
        emit OpVetoed(walletId, opId, msg.sender);
        emit OpCanceled(walletId, opId);
    }

    function executeRotation(bytes32 walletId, uint256 opId, address newOwner) external {
        WalletState storage s = _state(walletId);
        if (isFrozen(walletId)) revert WalletFrozen();

        PendingOp storage op = s.ops[opId];
        _requireOpExecutable(s, op, OpType.ROTATE);

        bytes32 expected = keccak256(abi.encodePacked("ROTATE_TO", newOwner));
        if (op.payloadHash != expected) revert OpNotExecutable();

        _enforceFinalizeGuards(s);

        bytes32 oldHash = s.ownerKeyset.keysetHash;
        _setOwnerKeyset(s, newOwner);

        op.executed = true;
        _countRotationFinalize(s);

        emit RotationExecuted(walletId, opId, oldHash, s.ownerKeyset.keysetHash);
    }

    // ---------- Core: Guardian Recovery ----------
    function proposeRecovery(
        bytes32 walletId,
        address newOwner,
        uint32 expiresInSeconds
    ) external returns (uint256 opId) {
        WalletState storage s = _state(walletId);
        if (!s.policy.guardiansCanRecover) revert GuardiansDisabled();
        if (isFrozen(walletId)) revert WalletFrozen();

        if (!_isGuardian(s, msg.sender)) revert Unauthorized();

        bytes32 payloadHash = keccak256(abi.encodePacked("RECOVER_TO", newOwner));

        opId = _newOpId(s);
        uint32 execAt = uint32(block.timestamp + s.policy.recoveryDelay);
        uint32 expAt  = uint32(block.timestamp + (expiresInSeconds == 0 ? _defaultExpiry() : expiresInSeconds));

        s.ops[opId] = PendingOp({
            opType: OpType.RECOVER,
            createdAt: uint32(block.timestamp),
            executableAt: execAt,
            expiresAt: expAt,
            guardianEpoch: s.guardianSet.epoch,
            payloadHash: payloadHash,
            approvals: 0,
            canceled: false,
            executed: false
        });

        _approveGuardian(s, walletId, opId, msg.sender);
        emit OpProposed(walletId, opId, OpType.RECOVER, payloadHash, execAt, expAt);
    }

    function approveRecovery(bytes32 walletId, uint256 opId) external {
        WalletState storage s = _state(walletId);
        PendingOp storage op = s.ops[opId];
        _requireOpExists(op);

        if (op.opType != OpType.RECOVER) revert OpNotExecutable();
        if (!_isGuardian(s, msg.sender)) revert Unauthorized();
        if (op.canceled || op.executed) revert OpCanceledOrExecuted();
        if (op.guardianEpoch != s.guardianSet.epoch) revert OpNotExecutable();

        _approveGuardian(s, walletId, opId, msg.sender);
    }

    function executeRecovery(bytes32 walletId, uint256 opId, address newOwner) external {
        WalletState storage s = _state(walletId);
        if (isFrozen(walletId)) revert WalletFrozen();

        PendingOp storage op = s.ops[opId];
        _requireOpExecutable(s, op, OpType.RECOVER);

        bytes32 expected = keccak256(abi.encodePacked("RECOVER_TO", newOwner));
        if (op.payloadHash != expected) revert OpNotExecutable();

        if (op.approvals < s.guardianSet.threshold) revert Unauthorized();

        _enforceFinalizeGuards(s);

        bytes32 oldHash = s.ownerKeyset.keysetHash;
        _setOwnerKeyset(s, newOwner);

        op.executed = true;
        emit RecoveryExecuted(walletId, opId, oldHash, s.ownerKeyset.keysetHash);
    }

    // ---------- Emergency Freeze ----------
    function freeze(
        bytes32 walletId,
        uint32 durationSeconds,
        uint256 deadline,
        bytes calldata ownerSig
    ) external returns (uint256 opId) {
        WalletState storage s = _state(walletId);

        if (!s.policy.ownerCanFreeze) revert FreezeDisabled();
        if (durationSeconds == 0 || durationSeconds > s.policy.freezeMaxDuration) revert BadPolicy();

        bytes32 payloadHash = keccak256(abi.encodePacked("FREEZE", durationSeconds));
        _requireOwnerAuth(s, walletId, uint8(OpType.FREEZE), payloadHash, deadline, ownerSig);

        opId = _newOpId(s);
        uint32 until = uint32(block.timestamp + durationSeconds);
        s.frozenUntil = until;

        s.ops[opId] = PendingOp({
            opType: OpType.FREEZE,
            createdAt: uint32(block.timestamp),
            executableAt: uint32(block.timestamp),
            expiresAt: uint32(block.timestamp + _defaultExpiry()),
            guardianEpoch: s.guardianSet.epoch,
            payloadHash: payloadHash,
            approvals: 0,
            canceled: false,
            executed: true
        });

        emit Frozen(walletId, until, opId);
    }

    function guardianFreeze(bytes32 walletId, uint32 durationSeconds) external returns (uint256 opId) {
        WalletState storage s = _state(walletId);

        if (!s.policy.guardiansCanFreeze) revert GuardiansDisabled();
        if (durationSeconds == 0 || durationSeconds > s.policy.freezeMaxDuration) revert BadPolicy();
        if (!_isGuardian(s, msg.sender)) revert Unauthorized();

        opId = _newOpId(s);
        uint32 until = uint32(block.timestamp + durationSeconds);
        if (until > s.frozenUntil) s.frozenUntil = until;

        s.ops[opId] = PendingOp({
            opType: OpType.FREEZE,
            createdAt: uint32(block.timestamp),
            executableAt: uint32(block.timestamp),
            expiresAt: uint32(block.timestamp + _defaultExpiry()),
            guardianEpoch: s.guardianSet.epoch,
            payloadHash: keccak256(abi.encodePacked("G_FREEZE", durationSeconds, msg.sender)),
            approvals: 0,
            canceled: false,
            executed: true
        });

        emit Frozen(walletId, s.frozenUntil, opId);
    }

    function unfreeze(bytes32 walletId, uint256 deadline, bytes calldata ownerSig) external returns (uint256 opId) {
        WalletState storage s = _state(walletId);

        bytes32 payloadHash = keccak256(abi.encodePacked("UNFREEZE"));
        _requireOwnerAuth(s, walletId, uint8(OpType.UNFREEZE), payloadHash, deadline, ownerSig);

        opId = _newOpId(s);
        s.frozenUntil = 0;

        s.ops[opId] = PendingOp({
            opType: OpType.UNFREEZE,
            createdAt: uint32(block.timestamp),
            executableAt: uint32(block.timestamp),
            expiresAt: uint32(block.timestamp + _defaultExpiry()),
            guardianEpoch: s.guardianSet.epoch,
            payloadHash: payloadHash,
            approvals: 0,
            canceled: false,
            executed: true
        });

        emit Unfrozen(walletId, opId);
    }

    // ---------- Admin: Policy / Guardians ----------
    function updatePolicy(bytes32 walletId, Policy calldata newPolicy, uint256 deadline, bytes calldata ownerSig) external {
        WalletState storage s = _state(walletId);
        if (isFrozen(walletId)) revert WalletFrozen();
        _validatePolicy(newPolicy);

        bytes32 payloadHash = keccak256(_encodePolicy(newPolicy));
        _requireOwnerAuth(s, walletId, uint8(OpType.UPDATE_POLICY), payloadHash, deadline, ownerSig);

        s.policy = newPolicy;
        emit PolicyUpdated(walletId, keccak256(_encodePolicy(newPolicy)));
    }

    function updateGuardians(bytes32 walletId, address[] calldata guardians, uint16 threshold, uint256 deadline, bytes calldata ownerSig) external {
        WalletState storage s = _state(walletId);
        if (isFrozen(walletId)) revert WalletFrozen();
        _validateGuardians(guardians, threshold);

        bytes32 payloadHash = keccak256(abi.encodePacked("GUARDIANS", keccak256(abi.encode(guardians)), threshold));
        _requireOwnerAuth(s, walletId, uint8(OpType.UPDATE_GUARDIANS), payloadHash, deadline, ownerSig);

        _setGuardians(s, guardians, threshold);
        emit GuardiansUpdated(walletId, s.guardianSet.epoch, threshold, guardians);
    }

    // ---------- Internals ----------
    function _state(bytes32 walletId) internal view returns (WalletState storage s) {
        s = W[walletId];
        if (s.ownerKeyset.keysetHash == bytes32(0)) revert NotInitialized();
    }

    function _newOpId(WalletState storage s) internal returns (uint256) {
        unchecked { s.nextOpId += 1; }
        return s.nextOpId;
    }

    function _requireOpExists(PendingOp storage op) internal view {
        if (op.createdAt == 0) revert OpNotFound();
    }

    function _requireOpExecutable(WalletState storage s, PendingOp storage op, OpType t) internal view {
        _requireOpExists(op);
        if (op.opType != t) revert OpNotExecutable();
        if (op.canceled || op.executed) revert OpCanceledOrExecuted();
        if (op.guardianEpoch != s.guardianSet.epoch) revert OpNotExecutable();
        if (block.timestamp < op.executableAt) revert OpNotExecutable();
        if (block.timestamp > op.expiresAt) revert OpExpired();
    }

    function _approveGuardian(WalletState storage s, bytes32 walletId, uint256 opId, address g) internal {
        if (s.approvedBy[opId][g]) return;
        s.approvedBy[opId][g] = true;
        unchecked { s.ops[opId].approvals += 1; }
        emit OpApproved(walletId, opId, g, s.ops[opId].approvals);
    }

    function _isGuardian(WalletState storage s, address who) internal view returns (bool) {
        address[] storage gs = s.guardianSet.guardians;
        for (uint256 i = 0; i < gs.length; i++) if (gs[i] == who) return true;
        return false;
    }

    function _setOwnerKeyset(WalletState storage s, address owner) internal {
        delete s.ownerKeyset.keys;
        s.ownerKeyset.keys.push(KeysetLib.ecdsaKey(owner));
        s.ownerKeyset.threshold = 1;
        s.ownerKeyset.flags = 0;
        unchecked { s.ownerKeyset.version += 1; }
        s.ownerKeyset.keysetHash =
            KeysetLib.computeKeysetHash(s.ownerKeyset.keys, s.ownerKeyset.threshold, s.ownerKeyset.flags, s.ownerKeyset.version);
    }

    function _setGuardians(WalletState storage s, address[] calldata guardians, uint16 threshold) internal {
        _validateGuardians(guardians, threshold);
        s.guardianSet.guardians = guardians;
        s.guardianSet.threshold = threshold;
        unchecked { s.guardianSet.epoch += 1; }
    }

    function _validateGuardians(address[] calldata guardians, uint16 threshold) internal pure {
        if (guardians.length == 0) revert BadGuardians();
        if (threshold == 0 || threshold > guardians.length) revert BadGuardians();
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == address(0)) revert BadGuardians();
            for (uint256 j = i + 1; j < guardians.length; j++) if (guardians[i] == guardians[j]) revert BadGuardians();
        }
    }

    function _validatePolicy(Policy calldata p) internal pure {
        if (p.rotationDelay < 1 hours) revert BadPolicy();
        if (p.recoveryDelay < 6 hours) revert BadPolicy();
        if (p.freezeMaxDuration < 1 hours) revert BadPolicy();
        if (p.windowSeconds < 1 hours) revert BadPolicy();
        if (p.maxRotationsPerWindow == 0) revert BadPolicy();
    }

    function _encodePolicy(Policy memory p) internal pure returns (bytes memory) {
        return abi.encode(
            p.rotationDelay, p.recoveryDelay, p.freezeMaxDuration,
            p.windowSeconds, p.maxRotationsPerWindow, p.minFinalizeCooldown,
            p.guardiansCanFreeze, p.guardiansCanRecover, p.ownerCanFreeze
        );
    }

    function _defaultExpiry() internal pure returns (uint32) {
        return 30 days;
    }

    function _requireOwnerAuth(
        WalletState storage s,
        bytes32 walletId,
        uint8 opType,
        bytes32 payloadHash,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        if (block.timestamp > deadline) revert Deadline();

        address owner = KeysetLib.ecdsaAddress(s.ownerKeyset.keys[0]);

        bytes32 structHash = EIP712Ops.opStructHash(walletId, opType, payloadHash, s.nonce, deadline);
        bytes32 digest = EIP712Ops.hashTyped(structHash);
        address recovered = digest.recover(sig);
        if (recovered != owner) revert BadSig();

        unchecked { s.nonce += 1; }
    }

    function _enforceFinalizeGuards(WalletState storage s) internal view {
        if (s.policy.minFinalizeCooldown != 0) {
            if (block.timestamp < uint256(s.lastFinalizeAt) + s.policy.minFinalizeCooldown) revert Cooldown();
        }

        if (s.windowStart != 0 && block.timestamp <= uint256(s.windowStart) + s.policy.windowSeconds) {
            if (s.rotationsInWindow >= s.policy.maxRotationsPerWindow) revert RateLimited();
        }
    }

    function _countRotationFinalize(WalletState storage s) internal {
        s.lastFinalizeAt = uint32(block.timestamp);

        if (s.windowStart == 0 || block.timestamp > uint256(s.windowStart) + s.policy.windowSeconds) {
            s.windowStart = uint32(block.timestamp);
            s.rotationsInWindow = 0;
        }
        unchecked { s.rotationsInWindow += 1; }
    }

    /// @notice Public helper to compute the exact digest verified for meta-ops.
    ///         SDKs/tests should use this to avoid domain/hash mismatches.
    function opDigest(
        bytes32 walletId,
        uint8 opType,
        bytes32 payloadHash,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32 structHash, bytes32 digest) {
        structHash = EIP712Ops.opStructHash(walletId, opType, payloadHash, nonce, deadline);
        digest = EIP712Ops.hashTyped(structHash);
    }

}
