// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/forge-std/src/Test.sol";
import "../../src/QKeyRotationV3.sol";
import "../../src/libraries/EIP712Ops.sol";

contract Handler is Test {
    QKeyRotationV3 public qr;
    bytes32 public walletId;

    uint256 public ownerPk;
    address public owner;

    address[] public guardians;

    constructor(QKeyRotationV3 _qr, bytes32 _walletId, uint256 _ownerPk, address[] memory _guardians) {
        qr = _qr;
        walletId = _walletId;
        ownerPk = _ownerPk;
        owner = vm.addr(ownerPk);
        guardians = _guardians;
    }

    function _sign(uint8 opType, bytes32 payloadHash, uint256 deadline) internal returns (bytes memory) {
        uint256 nonce = qr.getNonce(walletId);
        bytes32 structHash = EIP712Ops.opStructHash(walletId, opType, payloadHash, nonce, deadline);
        bytes32 digest = EIP712Ops.hashTyped(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function proposeRotation(address newOwner) external {
        uint256 deadline = block.timestamp + 2 days;
        bytes32 payloadHash = keccak256(abi.encodePacked("ROTATE_TO", newOwner));
        bytes memory sig = _sign(uint8(QKeyRotationV3.OpType.ROTATE), payloadHash, deadline);

        // call without prank: relayer allowed (auth via sig)
        try qr.proposeRotation(walletId, newOwner, deadline, sig) {} catch {}
    }

    function executeRotation(uint256 opId, address newOwner) external {
        try qr.executeRotation(walletId, opId, newOwner) {} catch {}
    }

    function proposeRecovery(uint256 guardianIndex, address newOwner) external {
        if (guardians.length == 0) return;
        address g = guardians[guardianIndex % guardians.length];
        vm.prank(g);
        try qr.proposeRecovery(walletId, newOwner, 0) {} catch {}
    }

    function approveRecovery(uint256 guardianIndex, uint256 opId) external {
        if (guardians.length == 0) return;
        address g = guardians[guardianIndex % guardians.length];
        vm.prank(g);
        try qr.approveRecovery(walletId, opId) {} catch {}
    }

    function veto(uint256 guardianIndex, uint256 opId) external {
        if (guardians.length == 0) return;
        address g = guardians[guardianIndex % guardians.length];
        vm.prank(g);
        try qr.vetoOp(walletId, opId) {} catch {}
    }

    function ownerFreeze(uint32 dur) external {
        uint256 deadline = block.timestamp + 2 days;
        bytes32 payloadHash = keccak256(abi.encodePacked("FREEZE", dur));
        bytes memory sig = _sign(uint8(QKeyRotationV3.OpType.FREEZE), payloadHash, deadline);
        try qr.freeze(walletId, dur, deadline, sig) {} catch {}
    }

    function ownerUnfreeze() external {
        uint256 deadline = block.timestamp + 2 days;
        bytes32 payloadHash = keccak256(abi.encodePacked("UNFREEZE"));
        bytes memory sig = _sign(uint8(QKeyRotationV3.OpType.UNFREEZE), payloadHash, deadline);
        try qr.unfreeze(walletId, deadline, sig) {} catch {}
    }

    function warp(uint32 secondsForward) external {
        // bound warp to avoid absurd jumps
        uint256 s = uint256(secondsForward % 3 days);
        vm.warp(block.timestamp + s);
    }
}
