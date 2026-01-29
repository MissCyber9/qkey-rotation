// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC1271 {
    /// @dev Should return whether the signature provided is valid for the provided data
    /// @return magicValue 0x1626ba7e when valid
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}
