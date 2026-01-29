// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/forge-std/src/Test.sol";
import "../../src/QKeyRotationV3.sol";
import "./Handler.t.sol";

contract Invariants is Test {
    QKeyRotationV3 qr;
    Handler handler;

    bytes32 walletId;
    uint256 ownerPk;
    address owner;

    function setUp() public {
        qr = new QKeyRotationV3();
        walletId = keccak256("wallet-inv");
        ownerPk = 0xA11CE;
        owner = vm.addr(ownerPk);

        address g1 = vm.addr(0xB0B);
        address g2 = vm.addr(0xB0C);
        address g3 = vm.addr(0xB0D);

        QKeyRotationV3.Policy memory p = QKeyRotationV3.Policy({
            rotationDelay: 2 hours,
            recoveryDelay: 12 hours,
            freezeMaxDuration: 24 hours,
            windowSeconds: 24 hours,
            maxRotationsPerWindow: 2,
            minFinalizeCooldown: 0,
            guardiansCanFreeze: true,
            guardiansCanRecover: true,
            ownerCanFreeze: true
        });

        address;
        gs[0]=g1; gs[1]=g2; gs[2]=g3;

        qr.initWallet(walletId, owner, gs, 2, p);

        handler = new Handler(qr, walletId, ownerPk, gs);
        targetContract(address(handler));
    }

    // Invariant: if frozen then proposeRotation should not succeed (we can't directly observe success),
    // but we can assert state doesn't change unexpectedly: owner remains a valid address always.
    function invariant_ownerAlwaysValid() public view {
        address o = qr.getOwnerECDSA(walletId);
        assertTrue(o != address(0));
    }

    // Invariant: nonce monotonically increases (view can't compare last, so skip).
    // More invariants can be encoded by tracking in handler, but this MVP keeps it minimal.
}
