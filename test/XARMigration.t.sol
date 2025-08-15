// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {XARMigration} from "../src/XARMigration.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract XARMigrationTest is Test {
    XARMigration public xarMigration;
    MockERC20 public xar;
    MockERC20 public avail;

    function setUp() public {
        xar = new MockERC20("XAR", "XAR");
        avail = new MockERC20("AVAIL", "AVAIL");
        address governance = makeAddr("governance");
        xarMigration = new XARMigration(IERC20(xar), IERC20(avail), governance);
    }
}
