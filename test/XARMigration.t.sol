// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {XARMigration} from "../src/XARMigration.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract XARMigrationTest is Test {
    /// @dev Fri Feb 27 2026 20:00:00 GMT+0000
    uint256 private immutable DEPOSIT_DEADLINE = 1772222400;
    /// @dev Sat Feb 28 2026 20:00:00 GMT+0000
    uint256 private immutable FIRST_UNLOCK_AT = 1772308800;
    /// @dev Fri Aug 28 2026 20:00:00 GMT+0000
    uint256 private immutable SECOND_UNLOCK_AT = 1787947200;

    XARMigration public xarMigration;
    MockERC20 public xar;
    MockERC20 public avail;
    address public governance;

    function setUp() public {
        xar = new MockERC20("XAR", "XAR");
        avail = new MockERC20("AVAIL", "AVAIL");
        governance = makeAddr("governance");
        xarMigration = new XARMigration(IERC20(xar), IERC20(avail), governance);
        vm.prank(governance);
        xarMigration.setPaused(false);
    }

    function test_revertZeroAddress_constructor() public {
        vm.expectRevert(XARMigration.ZeroAddress.selector);
        new XARMigration(IERC20(address(0)), IERC20(address(avail)), governance);
        vm.expectRevert(XARMigration.ZeroAddress.selector);
        new XARMigration(IERC20(address(xar)), IERC20(address(0)), governance);
        vm.expectRevert(XARMigration.ZeroAddress.selector);
        new XARMigration(IERC20(address(0)), IERC20(address(0)), governance);
    }

    function test_revertDepositClosed_deposit(uint248 amount, uint256 when) public {
        vm.assume(amount != 0 && when > DEPOSIT_DEADLINE);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        vm.warp(when);
        vm.expectRevert(XARMigration.DepositClosed.selector);
        xarMigration.deposit(amount);
    }

    function test_revertZeroAmount_deposit(uint256 when) public {
        vm.assume(when <= DEPOSIT_DEADLINE);
        address user = makeAddr("user");
        vm.startPrank(user);
        vm.warp(when);
        vm.expectRevert(XARMigration.ZeroAmount.selector);
        xarMigration.deposit(0);
    }

    function test_deposit(uint248 amount) public {
        vm.assume(amount != 0);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.deposit(amount);
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(user);
        assertEq(depositAmount, amount);
        assertEq(hasUnlockedOnce, false);
    }

    function test_depositTwice(uint248 amount, uint248 amount2) public {
        vm.assume(amount != 0 && amount2 != 0 && uint256(amount) + uint256(amount2) <= type(uint248).max);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount + amount2);
        xar.approve(address(xarMigration), amount + amount2);
        xarMigration.deposit(amount);
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(user);
        assertEq(depositAmount, amount);
        assertEq(hasUnlockedOnce, false);
        xarMigration.deposit(amount2);
        (depositAmount, hasUnlockedOnce) = xarMigration.deposits(user);
        assertEq(depositAmount, amount + amount2);
        assertEq(hasUnlockedOnce, false);
    }

    function test_revertDepositClosed_depositTo(uint248 amount, uint256 when, address someone) public {
        vm.assume(amount != 0 && when > DEPOSIT_DEADLINE && someone != address(0));
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        vm.warp(when);
        vm.expectRevert(XARMigration.DepositClosed.selector);
        xarMigration.depositTo(someone, amount);
    }

    function test_revertZeroAmount_depositTo(address someone, uint256 when) public {
        vm.assume(when <= DEPOSIT_DEADLINE && someone != address(0));
        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(XARMigration.ZeroAmount.selector);
        xarMigration.depositTo(someone, 0);
    }

    function test_revertZeroAddress_depositTo(uint248 amount, uint256 when) public {
        vm.assume(amount != 0 && when <= DEPOSIT_DEADLINE);
        address user = makeAddr("user");
        vm.startPrank(user);
        vm.warp(when);
        vm.expectRevert(XARMigration.ZeroAddress.selector);
        xarMigration.depositTo(address(0), amount);
    } 

    function test_depositTo(uint248 amount, address someone) public {
        vm.assume(amount != 0 && someone != address(0));
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.depositTo(someone, amount);
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(someone);
        assertEq(depositAmount, amount);
        assertEq(hasUnlockedOnce, false);
    }

    function test_depositToTwice(uint248 amount, uint248 amount2, address someone) public {
        vm.assume(
            amount != 0 && amount2 != 0 && someone != address(0)
                && uint256(amount) + uint256(amount2) <= type(uint248).max
        );
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount + amount2);
        xar.approve(address(xarMigration), amount + amount2);
        xarMigration.depositTo(someone, amount);
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(someone);
        assertEq(depositAmount, amount);
        assertEq(hasUnlockedOnce, false);
        xarMigration.depositTo(someone, amount2);
        (depositAmount, hasUnlockedOnce) = xarMigration.deposits(someone);
        assertEq(depositAmount, amount + amount2);
        assertEq(hasUnlockedOnce, false);
    }

    function test_depositToDifferentAddresses(uint248 amount, uint248 amount2, address someone, address someoneElse)
        public
    {
        vm.assume(
            amount != 0 && amount2 != 0 && someone != address(0) && someoneElse != address(0) && someone != someoneElse
                && uint256(amount) + uint256(amount2) <= type(uint248).max
        );
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount + amount2);
        xar.approve(address(xarMigration), amount + amount2);
        xarMigration.depositTo(someone, amount);
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(someone);
        assertEq(depositAmount, amount);
        assertEq(hasUnlockedOnce, false);
        xarMigration.depositTo(someoneElse, amount2);
        (depositAmount, hasUnlockedOnce) = xarMigration.deposits(someoneElse);
        assertEq(depositAmount, amount2);
        assertEq(hasUnlockedOnce, false);
    }

    function test_revertNotYet_depositAndFirstUnlock(uint248 amount, uint256 when) public {
        vm.assume(amount != 0 && when < FIRST_UNLOCK_AT);
        vm.warp(DEPOSIT_DEADLINE - 1);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.deposit(amount);
        vm.warp(when);
        vm.expectRevert(XARMigration.NotYet.selector);
        xarMigration.withdraw();
    }

    function test_depositAndFirstUnlock(uint248 amount) public {
        vm.assume(amount != 0);
        vm.warp(DEPOSIT_DEADLINE - 1);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.deposit(amount);
        vm.warp(FIRST_UNLOCK_AT);
        avail.mint(address(xarMigration), amount / 8); // 4:1 / 2
        xarMigration.withdraw();
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(user);
        assertApproxEqAbs(depositAmount, amount / 2, 1); // because of integer division
        assertEq(hasUnlockedOnce, true);
        assertEq(xar.balanceOf(user), 0);
        assertEq(avail.balanceOf(user), amount / 8);
    }

    function test_depositAndUnlockOnce(uint248 amount) public {
        vm.assume(amount != 0);
        vm.warp(DEPOSIT_DEADLINE - 1);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.deposit(amount);
        vm.warp(SECOND_UNLOCK_AT);
        avail.mint(address(xarMigration), amount / 4); // 4:1 / 2
        xarMigration.withdraw();
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(user);
        assertEq(depositAmount, 0);
        assertEq(hasUnlockedOnce, false);
        assertEq(xar.balanceOf(user), 0);
        assertEq(avail.balanceOf(user), amount / 4);
    }

    function test_revertAlreadyWithdrawn_depositAndUnlockTwice(uint248 amount) public {
        vm.assume(amount != 0);
        vm.warp(DEPOSIT_DEADLINE - 1);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.deposit(amount);
        vm.warp(FIRST_UNLOCK_AT);
        avail.mint(address(xarMigration), amount / 4); // 4:1 / 2
        xarMigration.withdraw();
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(user);
        assertApproxEqAbs(depositAmount, amount / 2, 1); // because of integer division
        assertEq(hasUnlockedOnce, true);
        assertEq(xar.balanceOf(user), 0);
        assertApproxEqAbs(avail.balanceOf(user), amount / 8, 1);
        vm.expectRevert(XARMigration.AlreadyWithdrawn.selector);
        xarMigration.withdraw();
    }

    function test_revertInsufficientBalance_depositAndUnlockTwice(uint248 amount) public {
        vm.assume(amount != 0);
        vm.warp(DEPOSIT_DEADLINE - 1);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.deposit(amount);
        vm.warp(FIRST_UNLOCK_AT);
        avail.mint(address(xarMigration), amount / 4); // 4:1 / 2
        xarMigration.withdraw();
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(user);
        assertApproxEqAbs(depositAmount, amount / 2, 1); // because of integer division
        assertEq(hasUnlockedOnce, true);
        assertEq(xar.balanceOf(user), 0);
        assertApproxEqAbs(avail.balanceOf(user), amount / 8, 1);
        vm.warp(SECOND_UNLOCK_AT);
        avail.mint(address(xarMigration), amount / 8); // 4:1 / 2
        xarMigration.withdraw();
        (depositAmount, hasUnlockedOnce) = xarMigration.deposits(user);
        assertEq(depositAmount, 0);
        assertEq(hasUnlockedOnce, false);
        assertEq(xar.balanceOf(user), 0);
        assertApproxEqAbs(avail.balanceOf(user), amount / 4, 1);
        vm.expectRevert(XARMigration.InsufficientBalance.selector);
        xarMigration.withdraw();

        address user2 = makeAddr("user2");
        vm.startPrank(user2);
        vm.expectRevert(XARMigration.InsufficientBalance.selector);
        xarMigration.withdraw();
    }

    function test_depositAndUnlockTwice(uint248 amount) public {
        vm.assume(amount != 0);
        vm.warp(DEPOSIT_DEADLINE - 1);
        address user = makeAddr("user");
        vm.startPrank(user);
        xar.mint(user, amount);
        xar.approve(address(xarMigration), amount);
        xarMigration.deposit(amount);
        vm.warp(FIRST_UNLOCK_AT);
        avail.mint(address(xarMigration), amount / 4); // 4:1 / 2
        xarMigration.withdraw();
        (uint248 depositAmount, bool hasUnlockedOnce) = xarMigration.deposits(user);
        assertApproxEqAbs(depositAmount, amount / 2, 1); // because of integer division
        assertEq(hasUnlockedOnce, true);
        assertEq(xar.balanceOf(user), 0);
        assertApproxEqAbs(avail.balanceOf(user), amount / 8, 1);
        vm.warp(SECOND_UNLOCK_AT);
        avail.mint(address(xarMigration), amount / 8); // 4:1 / 2
        xarMigration.withdraw();
        (depositAmount, hasUnlockedOnce) = xarMigration.deposits(user);
        assertEq(depositAmount, 0);
        assertEq(hasUnlockedOnce, false);
        assertEq(xar.balanceOf(user), 0);
        assertApproxEqAbs(avail.balanceOf(user), amount / 4, 1);
    }

    function test_setPaused(uint248 amount) public {
        vm.startPrank(governance);
        xarMigration.setPaused(true);
        assertEq(xarMigration.paused(), true);
        vm.stopPrank();
        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        xarMigration.deposit(amount);     
        vm.expectRevert(Pausable.EnforcedPause.selector);
        xarMigration.depositTo(user, amount);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        xarMigration.withdraw();
        vm.stopPrank();
        vm.startPrank(governance);
        xarMigration.setPaused(false);
        assertEq(xarMigration.paused(), false);
    }

    function test_drain(uint256 amount1, uint256 amount2) public {
        xar.mint(address(xarMigration), amount1);
        avail.mint(address(xarMigration), amount2);
        vm.startPrank(governance);
        xarMigration.drain(IERC20(xar), amount1);
        xarMigration.drain(IERC20(avail), amount2);
        assertEq(xar.balanceOf(governance), amount1);
        assertEq(avail.balanceOf(governance), amount2);
    }
}
