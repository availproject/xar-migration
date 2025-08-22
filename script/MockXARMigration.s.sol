// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockXARMigration} from "../src/mocks/MockXARMigration.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract XARMigrationScript is Script {
    MockXARMigration public xarMigration;

    function run() public {
        vm.startBroadcast();
        MockERC20 xar = new MockERC20("Mock Arcana", "mockXAR");
        MockERC20 avail = new MockERC20("Mock Avail", "mockAVAIL");
        xarMigration = new MockXARMigration(IERC20(address(xar)), IERC20(address(avail)), msg.sender);
        xarMigration.setPaused(false);
        xar.mint(msg.sender, 100000 ether);
        avail.mint(address(xarMigration), 100000 ether);
        xar.approve(address(xarMigration), 20 ether);
        xarMigration.deposit(10 ether);
        xarMigration.depositTo(msg.sender, 10 ether);

        vm.stopBroadcast();
    }
}
