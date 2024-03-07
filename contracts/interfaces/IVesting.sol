// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVESTING {
    /// @notice  event emmited when contract cancelled
    event Cancelled(uint256 amount);

    /// @notice  event emmited when tokens released
    event ERC20Released(address indexed token, uint256 amount);

    /// @notice  Custom error used for errors
    error CustomError(string msg);

    /// @dev Getter for the start timestamp
    /// @return start timestamp
    function start() external returns (uint256);

    /// @dev Getter for the duration period
    /// @return duration seconds
    function duration() external returns (uint256);

    /// @dev Getter for the end timestamp.
    /// @return end timestamp
    function end() external returns (uint256);

    /// @dev Amount of token already released
    /// @return amount released
    function released() external returns (uint256);

    /// @dev Getter for the amount of releasable ERC20 tokens.
    /// @return available amount
    function releasable() external returns (uint256);

    /// @dev Release the tokens that have already vested.
    /// Emits a {ERC20Released} event.
    function release() external;
}
