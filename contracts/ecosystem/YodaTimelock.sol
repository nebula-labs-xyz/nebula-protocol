// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/**
 * @title Yoda Timelock
 * @notice Standard OZUpgradeable Timelock, small modification with UUPS
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {TimelockControllerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

/// @custom:oz-upgrades
contract YodaTimelock is TimelockControllerUpgradeable, UUPSUpgradeable {
    /// @dev AccessControl Upgrader Role
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @dev UUPS version tracker
    uint8 public version;

    /**
     * @dev event emitted on UUPS upgrade
     * @param src upgrade sender address
     * @param implementation new implementation address
     */
    event Upgrade(address indexed src, address indexed implementation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the UUPS contract
     * @param minDelay timelock delay seconds
     * @param proposers address array of proposers
     * @param executors address array of executors
     * @param admin address of admin
     */
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        external
        initializer
    {
        ++version;
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __TimelockController_init(minDelay, proposers, executors, admin);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }
}
