// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QKeyRotation.sol";
import "./mocks/Mock1271.sol";

contract QKeyRotation1271Test is Test {
    QKeyRotation rot;
    Mock1271 mock;

    address wallet = address(0xA11CE);
    address k1 = address(0xBEEF1);
    address k2 = address(0xBEEF2);

    function setUp() public {
        rot = new QKeyRotation(1 hours);
        mock = new Mock1271();

        // owner is a contract now
        rot.init(wallet, address(mock), k1);
    }

    function testProposeWithSig_1271Owner() public {
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
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", rot.domainSeparator(), structHash));

        bytes memory sig = hex"deadbeef"; // arbitrary blob for mock

        mock.setExpected(digest, sig);

        rot.proposeWithSig(wallet, k2, deadline, sig);

        (address newKey,, bool exists) = rot.pendingOf(wallet);
        assertTrue(exists);
        assertEq(newKey, k2);
    }
}
