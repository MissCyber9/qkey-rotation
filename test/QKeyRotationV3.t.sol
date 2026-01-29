// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/forge-std/src/Test.sol";
import "../src/QKeyRotationV3.sol";
import "../src/libraries/EIP712Ops.sol";

contract QKeyRotationV3Test is Test {
    QKeyRotationV3 qr;

    bytes32 walletId;
    uint256 ownerPk;
    address owner;

    uint256 g1Pk; address g1;
    uint256 g2Pk; address g2;
    uint256 g3Pk; address g3;

    function setUp() public {
        qr = new QKeyRotationV3();
        walletId = keccak256("wallet-1");

        ownerPk = 0xA11CE;
        owner = vm.addr(ownerPk);

        g1Pk = 0xB0B; g1 = vm.addr(g1Pk);
        g2Pk = 0xB0C; g2 = vm.addr(g2Pk);
        g3Pk = 0xB0D; g3 = vm.addr(g3Pk);

        QKeyRotationV3.Policy memory p = QKeyRotationV3.Policy({
            rotationDelay: 2 hours,
            recoveryDelay: 12 hours,
            freezeMaxDuration: 24 hours,
            windowSeconds: 24 hours,
            maxRotationsPerWindow: 2,
            minFinalizeCooldown: 10 minutes,
            guardiansCanFreeze: true,
            guardiansCanRecover: true,
            ownerCanFreeze: true
        });

        address;
        gs[0]=g1; gs[1]=g2; gs[2]=g3;

        qr.initWallet(walletId, owner, gs, 2, p);
    }

    function _signOp(uint8 opType, bytes32 payloadHash, uint256 deadline) internal returns (bytes memory sig) {
        uint256 nonce = qr.getNonce(walletId);

        bytes32 structHash = EIP712Ops.opStructHash(walletId, opType, payloadHash, nonce, deadline);
        bytes32 digest = EIP712Ops.hashTyped(structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function testRotationFlow() public {
        address newOwner = address(0x1234);
        bytes32 payloadHash = keccak256(abi.encodePacked("ROTATE_TO", newOwner));
        uint256 deadline = block.timestamp + 1 days;
        bytes memory sig = _signOp(uint8(QKeyRotationV3.OpType.ROTATE), payloadHash, deadline);

        uint256 opId = qr.proposeRotation(walletId, newOwner, deadline, sig);

        // too early
        vm.expectRevert();
        qr.executeRotation(walletId, opId, newOwner);

        // after delay
        vm.warp(block.timestamp + 2 hours + 1);

        qr.executeRotation(walletId, opId, newOwner);
        assertEq(qr.getOwnerECDSA(walletId), newOwner);
    }

    function testGuardianVetoCancelsRotation() public {
        address newOwner = address(0x9999);
        bytes32 payloadHash = keccak256(abi.encodePacked("ROTATE_TO", newOwner));
        uint256 deadline = block.timestamp + 1 days;
        bytes memory sig = _signOp(uint8(QKeyRotationV3.OpType.ROTATE), payloadHash, deadline);

        uint256 opId = qr.proposeRotation(walletId, newOwner, deadline, sig);

        vm.prank(g1);
        qr.vetoOp(walletId, opId);

        vm.warp(block.timestamp + 2 hours + 1);
        vm.expectRevert();
        qr.executeRotation(walletId, opId, newOwner);
    }

    function testRecoveryRequiresThreshold() public {
        address newOwner = address(0x7777);

        vm.prank(g1);
        uint256 opId = qr.proposeRecovery(walletId, newOwner, 0);

        // only 1 approval so far
        vm.warp(block.timestamp + 12 hours + 1);
        vm.expectRevert();
        qr.executeRecovery(walletId, opId, newOwner);

        vm.prank(g2);
        qr.approveRecovery(walletId, opId);

        qr.executeRecovery(walletId, opId, newOwner);
        assertEq(qr.getOwnerECDSA(walletId), newOwner);
    }

    function testFreezeBlocksRotation() public {
        // freeze
        uint32 dur = 2 hours;
        bytes32 payloadHash = keccak256(abi.encodePacked("FREEZE", dur));
        uint256 deadline = block.timestamp + 1 days;
        bytes memory sig = _signOp(uint8(QKeyRotationV3.OpType.FREEZE), payloadHash, deadline);
        qr.freeze(walletId, dur, deadline, sig);

        address newOwner = address(0xABCD);
        bytes32 rPayload = keccak256(abi.encodePacked("ROTATE_TO", newOwner));
        bytes memory rSig = _signOp(uint8(QKeyRotationV3.OpType.ROTATE), rPayload, deadline);

        vm.expectRevert();
        qr.proposeRotation(walletId, newOwner, deadline, rSig);
    }
}
