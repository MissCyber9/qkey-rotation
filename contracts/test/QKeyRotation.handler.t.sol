// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/QKeyRotation.sol";

// Foundry cheatcodes interface
interface VmLike {
    function prank(address) external;
    function warp(uint256) external;
}

contract Handler {
    QKeyRotation public rot;
    VmLike public vm;

    address public wallet;
    address public owner;

    uint256 public proposeCount;
    uint256 public activateCount;

    constructor(QKeyRotation _rot, address _wallet, address _owner, VmLike _vm) {
        rot = _rot;
        wallet = _wallet;
        owner = _owner;
        vm = _vm;
    }

    function setOwner(address newOwner) external {
        if (newOwner == address(0)) return;
        vm.prank(owner);
        rot.setOwner(wallet, newOwner);
        owner = newOwner;
    }

    function propose(address newKey) external {
        if (newKey == address(0)) return;
        vm.prank(owner);
        rot.propose(wallet, newKey);
        proposeCount++;
    }

    function cancel() external {
        vm.prank(owner);
        try rot.cancel(wallet) {} catch {}
    }

    function activate(uint256 warpSeconds) external {
        uint256 w = warpSeconds % (2 hours);
        vm.warp(block.timestamp + w);
        try rot.activate(wallet) {
            activateCount++;
        } catch {}
    }
}

contract QKeyRotationInvariantSmart is Test {
    QKeyRotation rot;
    Handler handler;

    address wallet = address(0xA11CE);
    address owner  = address(0x0B0B);

    function setUp() public {
        rot = new QKeyRotation(1 hours);
        rot.init(wallet, owner, address(0xBEEF1));

        handler = new Handler(rot, wallet, owner, VmLike(address(vm)));

        // drive fuzz through handler (much better exploration)
        targetContract(address(handler));
    }

    function invariant_activeKeyNeverZero() public view {
        assertTrue(rot.activeKeyOf(wallet) != address(0));
    }

    function invariant_ownerNeverZero() public view {
        assertTrue(rot.ownerOf(wallet) != address(0));
    }

    function invariant_ifPendingExists_thenNewKeyNonZero() public view {
        (address newKey,, bool exists) = rot.pendingOf(wallet);
        if (exists) assertTrue(newKey != address(0));
    }
}
