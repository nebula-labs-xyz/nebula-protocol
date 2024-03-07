// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
/**
 * @title Yoda Ecosystem Contract
 * @notice Ecosystem contract handles airdrops, rewards, burning, and partnerships
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {IYODA} from "../interfaces/IYODA.sol";
import {IECOSYSTEM} from "../interfaces/IEcosystem.sol";
import {SafeERC20 as TH} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
/// @custom:oz-upgrades

contract Ecosystem is
    IECOSYSTEM,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /// @dev AccessControl Burner Role
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    /// @dev AccessControl Pauser Role
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @dev AccessControl Upgrader Role
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @dev AccessControl Rewarder Role
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    /// @dev AccessControl Manager Role
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev governance token instance
    IYODA public ecosystemToken;
    /// @dev starting reward supply
    uint256 public rewardSupply;
    /// @dev maximal one time reward amount
    uint256 public maxReward;
    /// @dev issued reward
    uint256 public issuedReward;
    /// @dev maximum one time burn amount
    uint256 public maxBurn;
    /// @dev starting airdrop supply
    uint256 public airdropSupply;
    /// @dev total amount airdropped so far
    uint256 public issuedAirDrop;
    /// @dev starting partnership supply
    uint256 public partnershipSupply;
    /// @dev partnership tokens issued so far
    uint256 public issuedPartnership;
    /// @dev number of UUPS upgrades
    uint8 public version;
    /// @dev Addresses of vesting contracts issued to partners
    mapping(address => address) public vestingContracts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice solidity receive function
     * @dev reverts on receive ETH
     */
    receive() external payable {
        if (msg.value > 0) revert CustomError("NO_RECEIVE");
    }

    /**
     * @dev Initializes the ecosystem contract
     * @param token token address
     * @param defaultAdmin admin address
     * @param pauser pauser address
     */
    function initialize(address token, address defaultAdmin, address pauser) external initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);

        ecosystemToken = IYODA(payable(token));
        uint256 initialSupply = ecosystemToken.initialSupply();
        rewardSupply = (initialSupply * 26) / 100;
        airdropSupply = (initialSupply * 10) / 100;
        partnershipSupply = (initialSupply * 8) / 100;
        maxReward = rewardSupply / 1000;
        maxBurn = rewardSupply / 50;
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
     * @dev Performs Airdrop.
     * @param winners address array
     * @param amount token amount per winner
     */
    function airdrop(address[] calldata winners, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyRole(MANAGER_ROLE)
    {
        if (amount < 1 ether) revert CustomError("INVALID_AMOUNT");
        uint256 len = winners.length;

        if (issuedAirDrop + len * amount > airdropSupply) {
            revert CustomError("AIRDROP_SUPPLY_LIMIT");
        }

        issuedAirDrop += len * amount;
        emit AirDrop(winners, amount);

        if (len > 5000) revert CustomError("GAS_LIMIT");
        for (uint256 i = 0; i < len; ++i) {
            TH.safeTransfer(ecosystemToken, winners[i], amount);
        }
    }

    /**
     * @dev Reward functionality for the Nebula Protocol.
     * @param to beneficiary address
     * @param amount token amount
     */
    function reward(address to, uint256 amount) external nonReentrant whenNotPaused onlyRole(REWARDER_ROLE) {
        if (amount == 0) revert CustomError("INVALID_AMOUNT");
        if (amount > maxReward) revert CustomError("REWARD_LIMIT");
        if (issuedReward + amount > rewardSupply) {
            revert CustomError("REWARD_SUPPLY_LIMIT");
        }

        issuedReward += amount;
        emit Reward(to, amount);
        TH.safeTransfer(ecosystemToken, to, amount);
    }

    /**
     * @dev Enables Burn functionality for the DAO.
     * @param amount token amount
     */
    function burn(uint256 amount) external nonReentrant whenNotPaused onlyRole(BURNER_ROLE) {
        if (amount == 0) revert CustomError("INVALID_AMOUNT");
        if (issuedReward + amount > rewardSupply) {
            revert CustomError("BURN_SUPPLY_LIMIT");
        }

        if (amount > maxBurn) revert CustomError("MAX_BURN_LIMIT");
        rewardSupply -= amount;
        emit Burn(amount);
        ecosystemToken.burn(amount);
    }

    /**
     * @dev Creates and funds new vesting contract for a new partner.
     * @param partner beneficiary address
     * @param amount token amount
     */
    function addPartner(address partner, uint256 amount) external nonReentrant whenNotPaused onlyRole(MANAGER_ROLE) {
        if (partner == address(0)) revert CustomError("INVALID_ADDRESS");
        if (vestingContracts[partner] != address(0)) {
            revert CustomError("PARTNER_EXISTS");
        }
        if (amount > partnershipSupply / 2 || amount < 100 ether) {
            revert CustomError("INVALID_AMOUNT");
        }
        if (issuedPartnership + amount > partnershipSupply) {
            revert CustomError("AMOUNT_EXCEEDS_SUPPLY");
        }

        issuedPartnership += amount;

        VestingWallet vestingContract = new VestingWallet(partner, uint64(block.timestamp + 365 days), uint64(730 days));

        vestingContracts[partner] = address(vestingContract);

        emit AddPartner(partner, address(vestingContract), amount);
        TH.safeTransfer(ecosystemToken, address(vestingContract), amount);
    }

    /**
     * @dev Performs Airdrop verification.
     * @param winners address array
     * @param amount token amount per winner
     * @return success boolean
     */
    function verifyAirdrop(address[] calldata winners, uint256 amount) external view returns (bool) {
        if (amount < 1 ether) revert CustomError("INVALID_AMOUNT");
        uint256 len = winners.length;

        if (issuedAirDrop + len * amount > airdropSupply) {
            revert CustomError("AIRDROP_SUPPLY_LIMIT");
        }

        if (len > 5000) revert CustomError("GAS_LIMIT");
        for (uint256 i = 0; i < len; ++i) {
            if (winners[i] == address(0)) return false;
            if (winners[i].balance < 0.2e18) return false;
        }
        return true;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }
}
