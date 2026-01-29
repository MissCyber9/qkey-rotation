// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library EIP712Ops {
    // EIP-712 domain separator (name/version fixed)
    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 internal constant NAME_HASH = keccak256(bytes("QKeyRotation"));
    bytes32 internal constant VERSION_HASH = keccak256(bytes("0.3"));

    // Generic operation typed data (payloadHash is op-specific)
    bytes32 internal constant OP_TYPEHASH =
        keccak256("Op(bytes32 walletId,uint8 opType,bytes32 payloadHash,uint256 nonce,uint256 deadline)");

    function domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(this)));
    }

    function hashTyped(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
    }

    function opStructHash(
        bytes32 walletId,
        uint8 opType,
        bytes32 payloadHash,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(OP_TYPEHASH, walletId, opType, payloadHash, nonce, deadline));
    }
}

