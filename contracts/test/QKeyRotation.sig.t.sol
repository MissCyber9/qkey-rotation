// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QKeyRotation.sol";

contract QKeyRotationSigTest is Test {
    QKeyRotation rot;

    uint256 ownerPk;
    address owner;
    address wallet = address(0xA11CE);

    address k1 = address(0xBEEF1);
    address k2 = address(0xBEEF2);

    function setUp() public {
        rot = new QKeyRotation(1 hours);

        ownerPk = 0xA11CE123;
        owner = vm.addr(ownerPk);

        rot.init(wallet, owner, k1);
    }

    function testProposeWithSigEOA() public {
        uint256 deadline = block.timestamp + 1 days;

        uint256 nonce = rot.nonces(wallet);
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Propose(address wallet,address newKey,uint256 nonce,uint256 deadline)"),
                wallet,
                k2,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", rot.domainSeparator(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        rot.proposeWithSig(wallet, k2, deadline, sig);

        // pending should exist
        (address newKey,, bool exists) = rot.pendingOf(wallet);
        assertTrue(exists);
        assertEq(newKey, k2);
    }
}
