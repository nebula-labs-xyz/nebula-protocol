// SPDX-License-Identifier: MIT
// Derived from OpenZeppelin Contracts (last updated v5.0.0) (finance/VestingWallet.sol)
pragma solidity 0.8.23;
/**
 * @title Yoda Team Vesting Contract
 * @notice Cancellable Vesting contract
 * @notice Offers flexible withdrawal schedule (gas efficient)
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {ITEAMVESTING} from "../interfaces/ITeamVesting.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract TeamVesting is ITEAMVESTING, Context, Ownable2Step {
    /// @dev token contract instance
    IERC20 private immutable TOKEN_INSTANCE;
    /// @dev start timestamp
    uint64 private immutable START;
    /// @dev duration seconds
    uint64 private immutable DURATION;
    /// @dev timelock address
    address private immutable TIMELOCK;
    /// @dev token address
    address private immutable TOKEN;
    /// @dev amount of tokens released
    mapping(address token => uint256 amount) private _erc20Released;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyTimelock() {
        _checkTimelock();
        _;
    }

    /**
     * @dev Sets the owner to beneficiary address, the start timestamp and the
     * vesting duration of the vesting contract.
     */
    constructor(
        address token,
        address timelock,
        address beneficiary, // solhint-disable-line
        uint64 startTimestamp,
        uint64 durationSeconds
    ) payable Ownable(beneficiary) {
        TOKEN = token;
        TIMELOCK = timelock;
        START = startTimestamp;
        DURATION = durationSeconds;
        TOKEN_INSTANCE = IERC20(token);
    }

    /**
     * @dev Allows the DAO to cancel the contract in case the team member is fired.
     *      Release vested amount and refund the remainder to timelock.
     */
    function cancelContract() external onlyTimelock {
        release();
        uint256 remainder = TOKEN_INSTANCE.balanceOf(address(this));
        emit Cancelled(remainder);
        SafeERC20.safeTransfer(TOKEN_INSTANCE, TIMELOCK, remainder);
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release() public virtual {
        uint256 amount = releasable();
        _erc20Released[TOKEN] += amount;
        emit ERC20Released(TOKEN, amount);
        SafeERC20.safeTransfer(TOKEN_INSTANCE, owner(), amount);
    }

    /**
     * @dev Getter for the start timestamp.
     * @return start timestamp
     */
    function start() public view virtual returns (uint256) {
        return START;
    }

    /**
     * @dev Getter for the vesting duration.
     * @return duration seconds
     */
    function duration() public view virtual returns (uint256) {
        return DURATION;
    }

    /**
     * @dev Getter for the end timestamp.
     * @return end timestamp
     */
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /**
     * @dev Getter for the amount of token already released
     * @return amount of tokens released so far
     */
    function released() public view virtual returns (uint256) {
        return _erc20Released[TOKEN];
    }

    /**
     * @dev Getter for the amount of releasable `token` ERC20 tokens.
     * @return amount of vested tokens
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(SafeCast.toUint64(block.timestamp)) - released();
    }

    /**
     * @dev Throws if the sender is not the timelock.
     */
    function _checkTimelock() internal view virtual {
        if (TIMELOCK != _msgSender()) {
            revert CustomError("UNAUTHORIZED");
        }
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     * @param timestamp current timestamp
     * @return amount vested
     */
    function vestedAmount(uint64 timestamp) internal view virtual returns (uint256) {
        return _vestingSchedule(TOKEN_INSTANCE.balanceOf(address(this)) + released(), timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     * @param totalAllocation initial amount
     * @param timestamp current timestamp
     * @return amount vested
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return totalAllocation;
        }
        return (totalAllocation * (timestamp - start())) / duration();
    }
}
