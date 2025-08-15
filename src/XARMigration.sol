// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable, Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/// @title XARMigration
/// @author QEDK <Avail>
/// @notice This contract facilitates the migration of XAR tokens to AVAIL tokens.
/// @dev This contract allows users to deposit XAR tokens and withdraw AVAIL tokens after a certain period.
/// @custom:security security@availproject.org
contract XARMigration is Ownable2Step {
    using SafeERC20 for IERC20;

    struct UserDeposit {
        uint248 amount;
        bool hasUnlockedOnce;
    }

    uint256 private constant XAR_PER_AVAIL = 4;
    uint256 private constant FIRST_UNLOCK_RATIO = 2; // implies 1/2
    uint256 private immutable SIX_MONTHS = block.timestamp + 180 days;
    uint256 private immutable ONE_YEAR = block.timestamp + 365 days;
    IERC20 public immutable XAR;
    IERC20 public immutable AVAIL;

    mapping(address => UserDeposit) public deposits;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    error ZeroAmount();
    error ZeroAddress();
    error DepositClosed();
    error InsufficientBalance();
    error NotYet();
    error AlreadyWithdrawn();

    constructor(IERC20 xar, IERC20 avail, address governance) Ownable(governance) {
        require(xar != IERC20(address(0)) && avail != IERC20(address(0)), ZeroAddress());
        XAR = xar;
        AVAIL = avail;
    }

    function deposit(uint248 amount) external {
        require(block.timestamp < SIX_MONTHS, DepositClosed());
        require(amount != 0, ZeroAmount());
        deposits[msg.sender] = UserDeposit(deposits[msg.sender].amount + amount, false);
        emit Deposit(msg.sender, amount);
        XAR.safeTransferFrom(msg.sender, address(this), amount);
    }

    function depositTo(address user, uint248 amount) external {
        require(block.timestamp < SIX_MONTHS, DepositClosed());
        require(amount != 0, ZeroAmount());
        require(user != address(0), ZeroAddress());
        UserDeposit memory userDeposit = deposits[user];
        deposits[user] = UserDeposit(userDeposit.amount + amount, false);
        emit Deposit(user, amount);
        XAR.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external {
        require(block.timestamp >= SIX_MONTHS, NotYet());
        UserDeposit memory userDeposit = deposits[msg.sender];
        require(userDeposit.amount != 0, InsufficientBalance());
        if (block.timestamp >= ONE_YEAR) {
            deposits[msg.sender] = UserDeposit(0, false);
            emit Withdraw(msg.sender, userDeposit.amount);
            AVAIL.safeTransfer(msg.sender, userDeposit.amount / XAR_PER_AVAIL);
        } else {
            require(!userDeposit.hasUnlockedOnce, AlreadyWithdrawn());
            uint256 unlockAmount = userDeposit.amount / 2;
            deposits[msg.sender] = UserDeposit(userDeposit.amount - uint248(unlockAmount), true);
            emit Withdraw(msg.sender, unlockAmount);
            AVAIL.safeTransfer(msg.sender, unlockAmount / XAR_PER_AVAIL);
        }
    }

    function drain(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(msg.sender, amount);
    }
}
