// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC1271} from "./interfaces/IERC1271.sol";

/// @notice Timelocked key rotation registry for EVM wallets.
/// @dev - Owner can be EOA or contract (EIP-1271)
///      - Signature-based methods use EIP-712 + per-wallet nonces (anti-replay)
///      - Guardians can cancel pending rotations (anti-coercion / anti-compromise)
contract QKeyRotation {
    // --- events ---
    event Initialized(address indexed wallet, address indexed owner, address indexed activeKey);
    event RotationProposed(address indexed wallet, address indexed newKey, uint64 activateAfter);
    event RotationCancelled(address indexed wallet);
    event RotationActivated(address indexed wallet, address indexed activeKey);
    event OwnerUpdated(address indexed wallet, address indexed oldOwner, address indexed newOwner);

    event GuardianAdded(address indexed wallet, address indexed guardian);
    event GuardianRemoved(address indexed wallet, address indexed guardian);
    event GuardianThresholdUpdated(address indexed wallet, uint256 oldThreshold, uint256 newThreshold);
    event GuardianCancel(address indexed wallet, uint256 approvals);

    // --- errors ---
    error NotOwner();
    error AlreadyInitialized();
    error NoPending();
    error TooEarly();
    error InvalidAddress();
    error InvalidKey();
    error SignatureExpired();
    error InvalidSignature();

    error NotGuardian();
    error ThresholdTooHigh();
    error DuplicateGuardian();
    error InvalidThreshold();

    // --- structs ---
    struct Pending {
        address newKey;
        uint64 activateAfter;
        bool exists;
    }

    // --- config ---
    uint64 public immutable DELAY;

    // --- core storage ---
    mapping(address wallet => address owner) public ownerOf;
    mapping(address wallet => address activeKey) public activeKeyOf;
    mapping(address wallet => Pending pending) public pendingOf;
    mapping(address wallet => uint256 nonce) public nonces;

    // --- guardian storage ---
    mapping(address wallet => mapping(address guardian => bool)) public isGuardian;
    mapping(address wallet => uint256 count) public guardianCount;
    mapping(address wallet => uint256 th) public guardianThreshold;

    // --- EIP-712 ---
    bytes32 private immutable _DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private constant _EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _NAME_HASH = keccak256("QKeyRotation");
    bytes32 private constant _VERSION_HASH = keccak256("1");

    bytes32 private constant _PROPOSE_TYPEHASH =
        keccak256("Propose(address wallet,address newKey,uint256 nonce,uint256 deadline)");
    bytes32 private constant _CANCEL_TYPEHASH =
        keccak256("Cancel(address wallet,uint256 nonce,uint256 deadline)");
    bytes32 private constant _SETOWNER_TYPEHASH =
        keccak256("SetOwner(address wallet,address newOwner,uint256 nonce,uint256 deadline)");

    constructor(uint64 delaySeconds) {
        DELAY = delaySeconds;
        _CACHED_CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    // --- EIP-712 helpers ---
    function domainSeparator() public view returns (bytes32) {
        return block.chainid == _CACHED_CHAIN_ID ? _DOMAIN_SEPARATOR : _buildDomainSeparator();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(_EIP712_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this)));
    }

    function _hashTypedData(bytes32 structHash) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
    }

    // --- modifiers ---
    modifier onlyOwner(address wallet) {
        if (msg.sender != ownerOf[wallet]) revert NotOwner();
        _;
    }

    // --- core ---
    function init(address wallet, address owner, address firstKey) external {
        if (wallet == address(0) || owner == address(0)) revert InvalidAddress();
        if (firstKey == address(0)) revert InvalidKey();
        if (ownerOf[wallet] != address(0)) revert AlreadyInitialized();

        ownerOf[wallet] = owner;
        activeKeyOf[wallet] = firstKey;

        emit Initialized(wallet, owner, firstKey);
        emit RotationActivated(wallet, firstKey);
    }

    function setOwner(address wallet, address newOwner) external onlyOwner(wallet) {
        if (newOwner == address(0)) revert InvalidAddress();
        address old = ownerOf[wallet];
        ownerOf[wallet] = newOwner;
        emit OwnerUpdated(wallet, old, newOwner);
    }

    function propose(address wallet, address newKey) external onlyOwner(wallet) {
        _propose(wallet, newKey);
    }

    function cancel(address wallet) external onlyOwner(wallet) {
        _cancel(wallet);
    }

    function activate(address wallet) external {
        Pending memory p = pendingOf[wallet];
        if (!p.exists) revert NoPending();
        if (block.timestamp < p.activateAfter) revert TooEarly();

        activeKeyOf[wallet] = p.newKey;
        delete pendingOf[wallet];

        emit RotationActivated(wallet, activeKeyOf[wallet]);
    }

    function isActive(address wallet, address key) external view returns (bool) {
        return activeKeyOf[wallet] == key;
    }

    // --- internal transitions ---
    function _propose(address wallet, address newKey) internal {
        if (newKey == address(0)) revert InvalidKey();
        uint64 when = uint64(block.timestamp) + DELAY;
        pendingOf[wallet] = Pending({newKey: newKey, activateAfter: when, exists: true});
        emit RotationProposed(wallet, newKey, when);
    }

    function _cancel(address wallet) internal {
        Pending memory p = pendingOf[wallet];
        if (!p.exists) revert NoPending();
        delete pendingOf[wallet];
        emit RotationCancelled(wallet);
    }

    // --- signature-based entrypoints (EIP-712) ---
    function proposeWithSig(address wallet, address newKey, uint256 deadline, bytes calldata sig) external {
        _checkDeadline(deadline);

        uint256 n = nonces[wallet]++;
        bytes32 structHash = keccak256(abi.encode(_PROPOSE_TYPEHASH, wallet, newKey, n, deadline));
        bytes32 digest = _hashTypedData(structHash);

        _verifyOwnerSignature(wallet, digest, sig);
        _propose(wallet, newKey);
    }

    function cancelWithSig(address wallet, uint256 deadline, bytes calldata sig) external {
        _checkDeadline(deadline);

        uint256 n = nonces[wallet]++;
        bytes32 structHash = keccak256(abi.encode(_CANCEL_TYPEHASH, wallet, n, deadline));
        bytes32 digest = _hashTypedData(structHash);

        _verifyOwnerSignature(wallet, digest, sig);
        _cancel(wallet);
    }

    function setOwnerWithSig(address wallet, address newOwner, uint256 deadline, bytes calldata sig) external {
        _checkDeadline(deadline);
        if (newOwner == address(0)) revert InvalidAddress();

        uint256 n = nonces[wallet]++;
        bytes32 structHash = keccak256(abi.encode(_SETOWNER_TYPEHASH, wallet, newOwner, n, deadline));
        bytes32 digest = _hashTypedData(structHash);

        _verifyOwnerSignature(wallet, digest, sig);

        address old = ownerOf[wallet];
        ownerOf[wallet] = newOwner;
        emit OwnerUpdated(wallet, old, newOwner);
    }

    function _checkDeadline(uint256 deadline) private view {
        if (block.timestamp > deadline) revert SignatureExpired();
    }

    function _verifyOwnerSignature(address wallet, bytes32 digest, bytes calldata sig) private view {
        address owner = ownerOf[wallet];
        if (owner == address(0)) revert InvalidAddress();

        if (_isContract(owner)) {
            bytes4 magic = IERC1271(owner).isValidSignature(digest, sig);
            if (magic != 0x1626ba7e) revert InvalidSignature();
        } else {
            (bytes32 r, bytes32 s, uint8 v) = _splitSig(sig);
            address recovered = ecrecover(digest, v, r, s);
            if (recovered == address(0) || recovered != owner) revert InvalidSignature();
        }
    }

    function _isContract(address a) private view returns (bool) {
        return a.code.length > 0;
    }

    function _splitSig(bytes calldata sig)
        private
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        if (sig.length != 65) revert InvalidSignature();

        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }

        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidSignature();

        // EIP-2 low-s check (prevents signature malleability)
        if (
            uint256(s)
                > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            revert InvalidSignature();
        }
    }

    // --- guardians: configuration (owner-only) ---
    function addGuardian(address wallet, address guardian) external onlyOwner(wallet) {
        if (guardian == address(0)) revert InvalidAddress();
        if (isGuardian[wallet][guardian]) revert DuplicateGuardian();

        isGuardian[wallet][guardian] = true;
        guardianCount[wallet] += 1;

        // default threshold = 1 if not set yet
        if (guardianThreshold[wallet] == 0) guardianThreshold[wallet] = 1;

        emit GuardianAdded(wallet, guardian);
    }

    function removeGuardian(address wallet, address guardian) external onlyOwner(wallet) {
        if (!isGuardian[wallet][guardian]) revert NotGuardian();

        isGuardian[wallet][guardian] = false;
        guardianCount[wallet] -= 1;

        // keep threshold <= count (if count becomes 0, keep threshold at 0)
        uint256 c = guardianCount[wallet];
        if (c == 0) {
            guardianThreshold[wallet] = 0;
        } else if (guardianThreshold[wallet] > c) {
            guardianThreshold[wallet] = c;
        }

        emit GuardianRemoved(wallet, guardian);
    }

    function setGuardianThreshold(address wallet, uint256 newThreshold) external onlyOwner(wallet) {
        uint256 c = guardianCount[wallet];
        if (c == 0) revert InvalidThreshold();
        if (newThreshold == 0) revert InvalidThreshold();
        if (newThreshold > c) revert ThresholdTooHigh();

        uint256 old = guardianThreshold[wallet];
        guardianThreshold[wallet] = newThreshold;
        emit GuardianThresholdUpdated(wallet, old, newThreshold);
    }

    // --- guardians: cancel (anti-coercion / anti-compromise) ---
    function cancelByGuardians(address wallet, address[] calldata guardians) external {
        uint256 th = guardianThreshold[wallet];
        if (th == 0) revert InvalidThreshold();
        if (guardians.length < th) revert InvalidThreshold();

        Pending memory p = pendingOf[wallet];
        if (!p.exists) revert NoPending();

        // verify guardians + uniqueness (O(n^2), acceptable for small n)
        for (uint256 i = 0; i < guardians.length; i++) {
            address g = guardians[i];
            if (!isGuardian[wallet][g]) revert NotGuardian();
            for (uint256 j = i + 1; j < guardians.length; j++) {
                if (g == guardians[j]) revert DuplicateGuardian();
            }
        }

        delete pendingOf[wallet];
        emit GuardianCancel(wallet, guardians.length);
        emit RotationCancelled(wallet);
    }
}
