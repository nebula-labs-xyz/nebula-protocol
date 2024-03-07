// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

interface IECOSYSTEM {
    event Burn(uint256 amount);
    event Reward(address indexed to, uint256 amount);
    event AirDrop(address[] addresses, uint256 amount);
    event Upgrade(address indexed src, address indexed implementation);
    event AddPartner(address indexed account, address indexed vesting, uint256 amount);

    error CustomError(string msg);

    /**
     * @dev Getter for the starting reward supply.
     */
    function rewardSupply() external view returns (uint256);

    /**
     * @dev Getter for the max one time reward amount.
     */
    function maxReward() external view returns (uint256);

    /**
     * @dev Getter for the starting airdrop supply.
     */
    function airdropSupply() external view returns (uint256);

    /**
     * @dev Getter for the starting partnership supply.
     */
    function partnershipSupply() external view returns (uint256);

    /**
     * @dev Getter for the issued amount of tokens issued as reward.
     */
    function issuedReward() external view returns (uint256);

    /**
     * @dev Getter for the issued amount of tokens airdropped.
     */
    function issuedAirDrop() external view returns (uint256);

    /**
     * @dev Getter for the issued amount of tokens allocated to partners.
     */
    function issuedPartnership() external view returns (uint256);

    /**
     * @dev Getter for the UUPS version.
     */
    function version() external view returns (uint8);

    /**
     * @dev Getter for the vesting contract addresses recorded by the AddPartner function.
     */
    function vestingContracts(address) external view returns (address);

    /**
     * @dev Pause contract.
     */
    function pause() external;

    /**
     * @dev Unpause contract.
     */
    function unpause() external;

    /**
     * @dev Airdrop tokens to community memebers
     *
     * Emits a {AirDrop} event.
     */
    function airdrop(address[] calldata winners, uint256 amount) external;

    /**
     * @dev Verify airdrop list is valid
     *
     * @return true
     */
    function verifyAirdrop(address[] calldata winners, uint256 amount) external returns (bool);

    /**
     * @dev Rewards liquidity providers participating in the Nebula Protocol.
     *
     * Emits a {Reward} event.
     */
    function reward(address to, uint256 amount) external;

    /**
     * @dev Burns tokens from the Ecosystem.
     *
     * Emits a {Burn} event.
     */
    function burn(uint256 amount) external;

    /**
     * @dev Creates vesting contracts for partners and funds them.
     *
     * Emits a {AddPartner} event.
     */
    function addPartner(address account, uint256 amount) external;

    receive() external payable;
}
