// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {XARMigration} from "../src/XARMigration.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract XARMigrationScript is Script {
    XARMigration public xarMigration;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address xar = vm.envAddress("XAR");
        address avail = vm.envAddress("AVAIL");
        address governance = vm.envAddress("GOVERNANCE");
        xarMigration = new XARMigration(IERC20(xar), IERC20(avail), governance);

        vm.stopBroadcast();
    }
}
