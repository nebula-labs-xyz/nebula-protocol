// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ITEAMVESTING {
    event Cancelled(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);

    error CustomError(string msg);

    receive() external payable;

    /**
     * @dev Getter for the start timestamp.
     */
    function start() external returns (uint256);

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() external returns (uint256);

    /**
     * @dev Getter for the end timestamp.
     */
    function end() external returns (uint256);

    /**
     * @dev Amount of token already released
     */
    function released() external returns (uint256);

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable() external returns (uint256);

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release() external;

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     *
     * Refund the remainder to the timelock
     */
    function cancelContract() external;
}
