// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ITREASURY {
    event Upgrade(address indexed src, address indexed implementation);
    event EtherReleased(address indexed to, uint256 amount);
    event ERC20Released(address indexed token, address indexed to, uint256 amount);

    error CustomError(string msg);

    receive() external payable;

    /**
     * @dev UUPS version incremented every upgrade
     */
    function version() external returns (uint8);

    /**
     * @dev Pause contract
     */
    function pause() external;

    /**
     * @dev Unpause contract.
     */
    function unpause() external;

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
     * @dev Amount of eth already released
     */
    function released() external returns (uint256);

    /**
     * @dev Amount of token already released
     */
    function released(address token) external returns (uint256);

    /**
     * @dev Getter for the amount of releasable eth.
     */
    function releasable() external returns (uint256);

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address token) external returns (uint256);

    /**
     * @dev Release the native token (ether) that have already vested.
     *
     * Emits a {EtherReleased} event.
     */
    function release(address to, uint256 amount) external;

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token, address to, uint256 amount) external;
}
