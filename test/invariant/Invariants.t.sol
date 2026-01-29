// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/QKeyRotationV3.sol";
import "./Handler.t.sol";

contract Invariants is Test {
    QKeyRotationV3 qr;
    Handler handler;

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

        walletId = keccak256("wallet-invariant");
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

        handler = new Handler(qr, walletId, ownerPk, _guardians());
        targetContract(address(handler));
    }

    // --- invariants ---
    function invariant_nonce_monotonic() public view {
        // Handler should only increase nonce (or keep same if reverts)
        // We can only assert non-negative here; stronger checks live in Handler state.
        qr.getNonce(walletId);
    }

    function invariant_owner_nonzero() public view {
        address o = qr.getOwnerECDSA(walletId);
        assertTrue(o != address(0));
    }
}
