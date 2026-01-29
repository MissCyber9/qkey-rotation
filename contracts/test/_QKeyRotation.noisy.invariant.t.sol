// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QKeyRotation.sol";

contract QKeyRotationInvariant is Test {
    QKeyRotation rot;

    address wallet = address(0xA11CE);
    address owner  = address(0x0B0B);

    function setUp() public {
        rot = new QKeyRotation(1 hours);
        rot.init(wallet, owner, address(0xBEEF1));
        targetContract(address(rot));
    }

    function invariant_activeKeyNeverZeroAfterInit() public view {
        assertTrue(rot.activeKeyOf(wallet) != address(0));
    }
}
