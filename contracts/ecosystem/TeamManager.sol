// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
/**
 * @title Yoda Ecosystem Team Manager
 * @notice Creates team vesting contracts
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */
import {IYODA} from "../interfaces/IYODA.sol";
import {ITEAMMANAGER} from "../interfaces/ITeamManager.sol";
import {TeamVesting} from "./TeamVesting.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @custom:oz-upgrades
contract TeamManager is
    ITEAMMANAGER,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    IYODA private ecosystemToken;
    uint256 public supply;
    uint256 public totalAllocation;
    mapping(address => uint256) public allocations;
    mapping(address => address) public vestingContracts;
    address private timelock;
    uint8 public version;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address token,
        address timelock_,
        address guardian
    ) external initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, guardian);
        _grantRole(MANAGER_ROLE, timelock_);

        timelock = timelock_;

        ecosystemToken = IYODA(payable(token));
        supply = (ecosystemToken.initialSupply() * 18) / 100;
        ++version;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }

    receive() external payable {
        if (msg.value > 0) revert CustomError("ERR_NO_RECEIVE");
    }

    /**
     * @dev Pause contract.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Create and fund a vesting contract for a new team member
     */
    function addTeamMember(
        address beneficiary,
        uint256 amount
    ) external whenNotPaused onlyRole(MANAGER_ROLE) returns (bool success) {
        if (totalAllocation + amount > supply)
            revert CustomError("SUPPLY_LIMIT");
        totalAllocation += amount;

        TeamVesting vestingContract = new TeamVesting(
            address(ecosystemToken),
            timelock,
            beneficiary,
            uint64(block.timestamp + 365 days), // cliff timestamp
            uint64(730 days) // duration after cliff
        );

        allocations[beneficiary] = amount;
        vestingContracts[beneficiary] = address(vestingContract);

        emit AddTeamMember(beneficiary, address(vestingContract), amount);
        success = ecosystemToken.transfer(address(vestingContract), amount);
        if (!success) revert CustomError("ERR_ALLOCATION_TRANSFER_FAILED");
    }
}
