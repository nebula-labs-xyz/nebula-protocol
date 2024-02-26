// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**
 * @title Yoda Timelock
 * @notice Standard OZUpgradeable Timelock, small modification with UUPS
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

/// @custom:oz-upgrades
contract YodaTimelock is TimelockControllerUpgradeable, UUPSUpgradeable {
    uint8 public version;
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event Upgrade(address indexed src, address indexed implementation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) public initializer {
        ++version;
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __TimelockController_init(minDelay, proposers, executors, admin);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }
}
