// SPDX-License-Identifier: MIT
// Derived from OpenZeppelin Contracts (last updated v5.0.0) (finance/VestingWallet.sol)
pragma solidity ^0.8.23;
/**
 * @title Yoda Investor Vesting Contract
 * @notice Investor Vesting contract
 * @notice Offers flexible withdrawal schedule (gas efficient)
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVESTING} from "../interfaces/IVesting.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract InvestorVesting is IVESTING, Context, Ownable {
    /// @dev token contract instance
    IERC20 internal tokenContract;
    /// @dev amount of tokens released
    mapping(address token => uint256) private _erc20Released;
    /// @dev start timestamp
    uint64 private _start;
    /// @dev duration seconds
    uint64 private _duration;
    /// @dev token address
    address private _token;

    /**
     * @dev Sets the owner to beneficiary address, the start timestamp and the
     * vesting duration of the vesting contract.
     */
    constructor(address token, address beneficiary, uint64 startTimestamp, uint64 durationSeconds)
        payable
        Ownable(beneficiary)
    {
        _token = token;
        _start = startTimestamp;
        _duration = durationSeconds;
        tokenContract = IERC20(token);
    }

    /**
     * @notice solidity receive function
     * @dev reverts on receive ETH
     */
    receive() external payable {
        if (msg.value > 0) revert CustomError("NO_RECEIVE");
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release() public virtual {
        uint256 amount = releasable();
        _erc20Released[_token] += amount;
        emit ERC20Released(_token, amount);
        SafeERC20.safeTransfer(tokenContract, owner(), amount);
    }

    /**
     * @dev Getter for the start timestamp.
     * @return start timestamp
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     * @return duration seconds
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the end timestamp.
     * @return end timnestamp
     */
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /**
     * @dev Getter for the amount of token already released
     * @return amount of tokens released so far
     */
    function released() public view virtual returns (uint256) {
        return _erc20Released[_token];
    }

    /**
     * @dev Getter for the amount of vested `ERC20` tokens.
     * @return amount of vested tokens
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     * @param timestamp current timestamp
     * @return amount vested
     */
    function vestedAmount(uint64 timestamp) internal view virtual returns (uint256) {
        return _vestingSchedule(tokenContract.balanceOf(address(this)) + released(), timestamp);
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
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }
}
