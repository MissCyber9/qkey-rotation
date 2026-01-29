// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library KeysetLib {
    uint16 internal constant SCHEME_ECDSA_SECP256K1 = 1;

    struct KeyRef {
        uint16 scheme;     // 1 = ECDSA addr-encoded
        bytes  pubkey;     // for ECDSA: 20 bytes address
        uint32 weight;     // reserved (v0.3 keep 1)
    }

    struct Keyset {
        uint32 version;
        bytes32 keysetHash;   // keccak256(canonical encoding)
        KeyRef[] keys;        // keep small
        uint32 threshold;     // v0.3 default 1
        uint16 flags;         // reserved
    }

    function ecdsaKey(address a) internal pure returns (KeyRef memory k) {
        k.scheme = SCHEME_ECDSA_SECP256K1;
        k.pubkey = abi.encodePacked(a);
        k.weight = 1;
    }

    function ecdsaAddress(KeyRef memory k) internal pure returns (address a) {
        require(k.scheme == SCHEME_ECDSA_SECP256K1, "KeyRef:scheme");
        bytes memory pk = k.pubkey;
        require(pk.length == 20, "KeyRef:pubkey");
        assembly {
            a := shr(96, mload(add(pk, 32)))
        }
    }

    function hashKeyRef(KeyRef memory k) internal pure returns (bytes32) {
        return keccak256(abi.encode(k.scheme, keccak256(k.pubkey), k.weight));
    }

    // Canonical hashing: v0.3 minimal (single ECDSA key expected).
    // In production: sort keys by (scheme, pubkey bytes) to stabilize hash if multi-key.
    function computeKeysetHash(
        KeyRef[] memory keys,
        uint32 threshold,
        uint16 flags,
        uint32 version
    ) internal pure returns (bytes32) {
        bytes32[] memory hk = new bytes32[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) hk[i] = hashKeyRef(keys[i]);
        return keccak256(abi.encode(version, flags, threshold, hk));
    }
}

