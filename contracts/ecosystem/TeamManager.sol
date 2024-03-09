// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;
/**
 * @title Yoda Ecosystem Team Manager
 * @notice Creates team vesting contracts
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {IYODA} from "../interfaces/IYODA.sol";
import {ITEAMMANAGER} from "../interfaces/ITeamManager.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20 as TH} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TeamVesting} from "./TeamVesting.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @custom:oz-upgrades
contract TeamManager is
    ITEAMMANAGER,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /// @dev AccessControl Pauser Role
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @dev AccessControl Manager Role
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    /// @dev AccessControl Upgrader Role
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @dev governance token instance
    IYODA internal ecosystemToken;
    /// @dev amount of ecosystem tokens in the contract
    uint256 public supply;
    /// @dev amount of tokens allocated so far
    uint256 public totalAllocation;
    /// @dev token allocations to team members
    mapping(address => uint256) public allocations;
    /// @dev vesting contract addresses for team members
    mapping(address => address) public vestingContracts;
    /// @dev timelock address
    address public timelock;
    /// @dev number of UUPS upgrades
    uint8 public version;
    uint256[50] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the this contract
     * @param token ecosystem token address
     * @param timelock_ timelock address
     * @param guardian guardian address
     */
    function initialize(address token, address timelock_, address guardian) external initializer {
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
     * @param beneficiary beneficiary address
     * @param amount token amount
     */
    function addTeamMember(address beneficiary, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyRole(MANAGER_ROLE)
    {
        if (totalAllocation + amount > supply) {
            revert CustomError("SUPPLY_LIMIT");
        }
        totalAllocation += amount;

        TeamVesting vestingContract = new TeamVesting(
            address(ecosystemToken),
            timelock,
            beneficiary,
            SafeCast.toUint64(block.timestamp + 365 days), // cliff timestamp
            SafeCast.toUint64(730 days) // duration after cliff
        );

        allocations[beneficiary] = amount;
        vestingContracts[beneficiary] = address(vestingContract);

        emit AddTeamMember(beneficiary, address(vestingContract), amount);
        TH.safeTransfer(ecosystemToken, address(vestingContract), amount);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }
}
