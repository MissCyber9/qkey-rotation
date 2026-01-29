// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QKeyRotation.sol";

contract QKeyRotationTest is Test {
    QKeyRotation rot;

    address wallet = address(0xA11CE);
    address owner  = address(0x0B0B);
    address k1     = address(0xBEEF1);
    address k2     = address(0xBEEF2);

    function setUp() public {
        rot = new QKeyRotation(1 hours);
        rot.init(wallet, owner, k1);
    }

    function testOnlyOwnerCanProposeOrCancel() public {
        vm.prank(wallet);
        vm.expectRevert(QKeyRotation.NotOwner.selector);
        rot.propose(wallet, k2);

        vm.prank(owner);
        rot.propose(wallet, k2);

        vm.prank(wallet);
        vm.expectRevert(QKeyRotation.NotOwner.selector);
        rot.cancel(wallet);

        vm.prank(owner);
        rot.cancel(wallet);
    }

    function testProposeAndActivateAfterDelay() public {
        vm.prank(owner);
        rot.propose(wallet, k2);

        vm.expectRevert(QKeyRotation.TooEarly.selector);
        rot.activate(wallet);

        vm.warp(block.timestamp + 1 hours + 1);
        rot.activate(wallet);

        assertEq(rot.activeKeyOf(wallet), k2);
    }
}
