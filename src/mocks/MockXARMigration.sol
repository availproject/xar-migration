// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Ownable, Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/// @title XARMigration
/// @author QEDK <Avail>
/// @notice This contract facilitates the migration of XAR tokens to AVAIL tokens.
/// @dev ⚠️ Do not use this in production
/// @custom:security security@availproject.org
contract MockXARMigration is Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    struct UserDeposit {
        uint248 amount;
        bool hasUnlockedOnce;
    }

    uint256 private constant XAR_PER_AVAIL = 4;
    uint256 private constant FIRST_UNLOCK_RATIO = 2; // implies 1/2
    uint256 private immutable DEPOSIT_DEADLINE;
    uint256 private immutable FIRST_UNLOCK_AT;
    uint256 private immutable SECOND_UNLOCK_AT;
    IERC20 public immutable xar;
    IERC20 public immutable avail;

    mapping(address => UserDeposit) public deposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    error ZeroAmount();
    error ZeroAddress();
    error DepositClosed();
    error InsufficientBalance();
    error NotYet();
    error AlreadyWithdrawn();

    constructor(IERC20 newXar, IERC20 newAvail, address governance) Ownable(governance) {
        require(newXar != IERC20(address(0)) && newAvail != IERC20(address(0)), ZeroAddress());
        DEPOSIT_DEADLINE = block.timestamp + 2 hours;
        FIRST_UNLOCK_AT = block.timestamp + 3 hours;
        SECOND_UNLOCK_AT = block.timestamp + 5 hours;
        xar = newXar;
        avail = newAvail;
        _pause();
    }

    function deposit(uint248 amount) external whenNotPaused {
        // slither-disable-next-line timestamp
        require(block.timestamp <= DEPOSIT_DEADLINE, DepositClosed());
        require(amount != 0, ZeroAmount());
        deposits[msg.sender] = UserDeposit(deposits[msg.sender].amount + amount, false);
        emit Deposit(msg.sender, amount);
        xar.safeTransferFrom(msg.sender, address(this), amount);
    }

    function depositTo(address user, uint248 amount) external whenNotPaused {
        // slither-disable-next-line timestamp
        require(block.timestamp <= DEPOSIT_DEADLINE, DepositClosed());
        require(amount != 0, ZeroAmount());
        require(user != address(0), ZeroAddress());
        UserDeposit memory userDeposit = deposits[user];
        deposits[user] = UserDeposit(userDeposit.amount + amount, false);
        emit Deposit(user, amount);
        xar.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external whenNotPaused {
        // slither-disable-next-line timestamp
        require(block.timestamp >= FIRST_UNLOCK_AT, NotYet());
        UserDeposit memory userDeposit = deposits[msg.sender];
        require(userDeposit.amount != 0, InsufficientBalance());
        // slither-disable-next-line timestamp
        if (block.timestamp >= SECOND_UNLOCK_AT) {
            deposits[msg.sender] = UserDeposit(0, false);
            emit Withdraw(msg.sender, userDeposit.amount);
            avail.safeTransfer(msg.sender, userDeposit.amount / XAR_PER_AVAIL);
        } else {
            require(!userDeposit.hasUnlockedOnce, AlreadyWithdrawn());
            uint256 unlockAmount = userDeposit.amount / FIRST_UNLOCK_RATIO;
            deposits[msg.sender] = UserDeposit(userDeposit.amount - uint248(unlockAmount), true);
            emit Withdraw(msg.sender, unlockAmount);
            avail.safeTransfer(msg.sender, unlockAmount / XAR_PER_AVAIL);
        }
    }

    function setPaused(bool setPause) external onlyOwner {
        if (setPause) {
            _pause();
        } else {
            _unpause();
        }
    }

    function drain(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(msg.sender, amount);
    }
}
