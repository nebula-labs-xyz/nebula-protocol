// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface ITEAMMANAGER {
    event Upgrade(address indexed src, address indexed implementation);
    event AddTeamMember(
        address indexed account,
        address indexed vesting,
        uint256 amount
    );

    receive() external payable;

    /**
     * @dev Getter for the UUPS version, incremented each time an upgrade occurs.
     */
    function version() external view returns (uint8);

    /**
     * @dev Getter for the amount of tokens allocated to team member.
     */
    function allocations(address account) external view returns (uint256);

    /**
     * @dev Getter for the  address of vesting contract created for team member.
     */
    function vestingContracts(address account) external view returns (address);

    /**
     * @dev Total available supply.
     */
    function supply() external view returns (uint256);

    /**
     * @dev Total amount of token allocated so far.
     */
    function totalAllocation() external view returns (uint256);

    /**
     * @dev Pause contract.
     */
    function pause() external;

    /**
     * @dev Unpause contract.
     */
    function unpause() external;

    /**
     * @dev Create new vesting contract for a team member.
     */
    function addTeamMember(
        address beneficiary,
        uint256 amount
    ) external returns (bool);
}
