// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QKeyRotation.sol";

contract QKeyRotationGuardianTest is Test {
    QKeyRotation rot;

    address wallet = address(0xA11CE);
    address owner  = address(0x0B0B);
    address k1     = address(0xBEEF1);
    address k2     = address(0xBEEF2);

    address g1 = address(0x1111);
    address g2 = address(0x2222);
    address g3 = address(0x3333);

    function setUp() public {
        rot = new QKeyRotation(1 hours);
        rot.init(wallet, owner, k1);

        vm.prank(owner); rot.addGuardian(wallet, g1);
        vm.prank(owner); rot.addGuardian(wallet, g2);
        vm.prank(owner); rot.addGuardian(wallet, g3);

        vm.prank(owner); rot.setGuardianThreshold(wallet, 2);
    }

    function testGuardianCancelPending() public {
        vm.prank(owner);
        rot.propose(wallet, k2);

        address[] memory approvals = new address[](2);
        approvals[0] = g1;
        approvals[1] = g2;

        rot.cancelByGuardians(wallet, approvals);

        (, , bool exists) = rot.pendingOf(wallet);
        assertFalse(exists);
        assertEq(rot.activeKeyOf(wallet), k1);
    }
}
