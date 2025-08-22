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
        address xar = address(new MockERC20("Mock Arcana", "mockXAR"));
        address avail = address(new MockERC20("Mock Avail", "mockAVAIL"));
        xarMigration = new MockXARMigration(IERC20(xar), IERC20(avail), msg.sender);
        xarMigration.setPaused(false);

        vm.stopBroadcast();
    }
}
