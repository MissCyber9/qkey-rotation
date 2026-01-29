// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QKeyRotation.sol";

contract Deploy is Script {
    function run() external returns (QKeyRotation rot) {
        uint64 delay = uint64(vm.envUint("DELAY_SECONDS"));
        vm.startBroadcast();
        rot = new QKeyRotation(delay);
        vm.stopBroadcast();
    }
}
