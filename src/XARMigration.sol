// SPDX-License-Identifier: Apache-2.0
/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:´:°•.°+.*•´.*:˚.°*.˚•´
                                         __   __   __                         _  _ 
  __ _  _ __   ___   __ _  _ __    __ _  \ \  \ \  \ \    __ _ __   __  __ _ (_)| |
 / _` || '__| / __| / _` || '_ \  / _` |  \ \  \ \  \ \  / _` |\ \ / / / _` || || |
| (_| || |   | (__ | (_| || | | || (_| |  / /  / /  / / | (_| | \ V / | (_| || || |
 \__,_||_|    \___| \__,_||_| |_| \__,_| /_/  /_/  /_/   \__,_|  \_/   \__,_||_||_|
´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:´:°•.°+.*•´.*:˚.°*.˚•´*/
pragma solidity 0.8.30;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Ownable, Ownable2Step} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/// @title XARMigration
/// @author @QEDK (Avail)
/// @notice This contract facilitates the migration of XAR tokens to AVAIL tokens.
/// @dev This contract allows users to deposit XAR tokens and withdraw AVAIL tokens after a certain period.
/// @custom:security security@availproject.org
contract XARMigration is Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @dev Represents a user's deposit in the migration contract
    struct UserDeposit {
        /// @dev Amount of XAR tokens deposited
        uint248 amount;
        /// @dev Indicates if the user has made their first unlock withdrawal
        bool hasUnlockedOnce;
    }

    uint256 private constant XAR_PER_AVAIL = 4;
    uint256 private constant FIRST_UNLOCK_RATIO = 2; // implies 1/2
    /// @dev Fri Feb 27 2026 20:00:00 GMT+0000
    uint256 private constant DEPOSIT_DEADLINE = 1772222400;
    /// @dev Sat Feb 28 2026 20:00:00 GMT+0000
    uint256 private constant FIRST_UNLOCK_AT = 1772308800;
    /// @dev Fri Aug 28 2026 20:00:00 GMT+0000
    uint256 private constant SECOND_UNLOCK_AT = 1787947200;
    // slither-disable-next-line naming-convention
    IERC20 public immutable XAR;
    // slither-disable-next-line naming-convention
    IERC20 public immutable AVAIL;

    /// @dev Mapping of user addresses to their deposit information
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
        require(xar != IERC20(address(0)) && avail != IERC20(address(0)), ZeroAddress()); // we skip governance address check because ownable enforces zero-address checks
        XAR = xar;
        AVAIL = avail;
    }

    /// @notice Allows users to deposit XAR tokens
    /// @param amount Amount of tokens to deposit
    function deposit(uint248 amount) external whenNotPaused {
        // slither-disable-next-line timestamp
        require(block.timestamp <= DEPOSIT_DEADLINE, DepositClosed());
        require(amount != 0, ZeroAmount());
        deposits[msg.sender].amount += amount;
        emit Deposit(msg.sender, amount);
        XAR.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Allows users to deposit XAR tokens to another user's account
    /// @param user Address of the user to deposit tokens for
    /// @param amount Amount of tokens to deposit
    function depositTo(address user, uint248 amount) external whenNotPaused {
        // slither-disable-next-line timestamp
        require(block.timestamp <= DEPOSIT_DEADLINE, DepositClosed());
        require(amount != 0, ZeroAmount());
        require(user != address(0), ZeroAddress());
        deposits[user].amount += amount;
        emit Deposit(user, amount);
        XAR.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Allows users to withdraw their AVAIL tokens based on the unlock schedule
    function withdraw() external whenNotPaused {
        // slither-disable-next-line timestamp
        require(block.timestamp >= FIRST_UNLOCK_AT, NotYet());
        UserDeposit memory userDeposit = deposits[msg.sender];
        require(userDeposit.amount != 0, InsufficientBalance());
        // slither-disable-next-line timestamp
        if (block.timestamp >= SECOND_UNLOCK_AT) {
            deposits[msg.sender] = UserDeposit(0, false);
            emit Withdraw(msg.sender, userDeposit.amount);
            AVAIL.safeTransfer(msg.sender, userDeposit.amount / XAR_PER_AVAIL);
        } else {
            require(!userDeposit.hasUnlockedOnce, AlreadyWithdrawn());
            uint256 unlockAmount = userDeposit.amount / FIRST_UNLOCK_RATIO;
            deposits[msg.sender] = UserDeposit(userDeposit.amount - uint248(unlockAmount), true);
            emit Withdraw(msg.sender, unlockAmount);
            AVAIL.safeTransfer(msg.sender, unlockAmount / XAR_PER_AVAIL);
        }
    }

    /// @notice Allows the governance contract to pause or unpause deposits and withdrawals
    /// @param setPause Boolean indicating whether to pause or unpause
    function setPaused(bool setPause) external onlyOwner {
        if (setPause) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @notice Allows the governance contract to withdraw funds after migration
    /// @param token Address of token to withdraw
    /// @param amount Amount of tokens to withdraw
    function drain(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(msg.sender, amount);
    }
}
