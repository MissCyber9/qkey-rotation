// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/QKeyRotationV3.sol";
import "../src/libraries/EIP712Ops.sol";

contract QKeyRotationV3SmokeTest is Test {
    QKeyRotationV3 qr;
    bytes32 walletId;
    uint256 ownerPk;
    address owner;

    function _guardians() internal pure returns (address[] memory gs) {
        gs = new address[](3);
        gs[0] = address(0xB0B);
        gs[1] = address(0xB0C);
        gs[2] = address(0xB0D);
    }

    function setUp() public {
        qr = new QKeyRotationV3();
        walletId = keccak256("wallet-1");
        ownerPk = 0xA11CE;
        owner = vm.addr(ownerPk);

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

        qr.initWallet(walletId, owner, _guardians(), 2, p);
    }

    function _sign(uint8 opType, bytes32 payloadHash, uint256 deadline) internal view returns (bytes memory sig) {
        uint256 nonce = qr.getNonce(walletId);
        (, bytes32 digest) = qr.opDigest(walletId, opType, payloadHash, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_rotation_smoke() public {
        address newOwner = address(0x1234);
        bytes32 payloadHash = keccak256(abi.encodePacked("ROTATE_TO", newOwner));
        uint256 deadline = block.timestamp + 1 days;

        bytes memory sig = _sign(uint8(QKeyRotationV3.OpType.ROTATE), payloadHash, deadline);
        uint256 opId = qr.proposeRotation(walletId, newOwner, deadline, sig);

        vm.warp(block.timestamp + 2 hours + 1);
        qr.executeRotation(walletId, opId, newOwner);

        assertEq(qr.getOwnerECDSA(walletId), newOwner);
    }
}
