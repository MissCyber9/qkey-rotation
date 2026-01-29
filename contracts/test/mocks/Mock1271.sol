// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IERC1271.sol";

contract Mock1271 is IERC1271 {
    bytes32 public expectedHash;
    bytes public expectedSig;

    function setExpected(bytes32 h, bytes calldata sig) external {
        expectedHash = h;
        expectedSig = sig;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        if (hash == expectedHash && keccak256(signature) == keccak256(expectedSig)) {
            return 0x1626ba7e;
        }
        return 0xffffffff;
    }
}
