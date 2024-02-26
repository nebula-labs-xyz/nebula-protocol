// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
/**
 * @title Yoda Ecosystem Contract
 * @notice Ecosystem contract handles airdrops, rewards, burning, and partnerships
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {IYODA} from "../interfaces/IYODA.sol";
import {IECOSYSTEM} from "../interfaces/IEcosystem.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @custom:oz-upgrades
contract Ecosystem is
    IECOSYSTEM,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 private constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IYODA private ecosystemToken;
    uint256 public rewardSupply;
    uint256 public maxReward;
    uint256 public totalReward;
    uint256 public maxBurn;
    uint256 public airdropSupply;
    uint256 public totalAirDrop;
    uint256 public partnershipSupply;
    uint256 public totalPartnership;
    uint8 public version;
    mapping(address => address) public vestingContracts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address token,
        address defaultAdmin,
        address pauser
    ) public initializer {
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }

    receive() external payable {
        if (msg.value > 0) revert();
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
     */
    function airdrop(
        address[] calldata winners,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        require(amount >= 1 ether, "ERR_INVALID_AMOUNT");
        uint256 len = winners.length;
        require(len <= 5000, "ERR_GAS_LIMIT");
        require(
            totalAirDrop + len * amount <= airdropSupply,
            "ERR_AIRDROP_LIMIT"
        );

        totalAirDrop += len * amount;
        emit AirDrop(winners, amount);
        for (uint256 i = 0; i < len; ++i) {
            // if (winners[i] == address(0)) continue;
            // if (winners[i].balance < 0.2e18) continue;
            require(ecosystemToken.transfer(winners[i], amount), "ERR_ATF");
        }
    }

    /**
     * @dev Performs Airdrop verification.
     */
    function verifyAirdrop(
        address[] calldata winners,
        uint256 amount
    ) public view returns (bool) {
        require(amount >= 1 ether, "ERR_INVALID_AMOUNT");
        uint256 len = winners.length;
        require(len <= 5000, "ERR_GAS_LIMIT");
        require(
            totalAirDrop + len * amount <= airdropSupply,
            "ERR_AIRDROP_LIMIT"
        );
        for (uint256 i = 0; i < len; ++i) {
            if (winners[i] == address(0)) return false;
            if (winners[i].balance < 0.2e18) return false;
        }
        return true;
    }

    /**
     * @dev Reward functionality for the Nebula Protocol.
     */
    function reward(
        address to,
        uint256 amount
    ) external onlyRole(REWARDER_ROLE) whenNotPaused {
        require(amount > 0, "ERR_INVALID_AMOUNT");
        require(amount <= maxReward, "ERR_REWARD_LIMIT");
        require(totalReward + amount <= rewardSupply, "ERR_SUPPLY_LIMIT");
        totalReward += amount;
        emit Reward(to, amount);
        require(
            ecosystemToken.transfer(to, amount),
            "ERR_REWARD_TRANSFER_FAILED"
        );
    }

    /**
     * @dev Enables Burn functionality for the DAO.
     */
    function burn(uint256 amount) external onlyRole(BURNER_ROLE) whenNotPaused {
        require(amount > 0, "ERR_INVALID_AMOUNT");
        require(totalReward + amount <= rewardSupply, "ERR_SUPPLY_LIMIT");
        require(amount <= maxBurn, "ERR_BURN_LIMIT");
        rewardSupply -= amount;
        emit Burn(amount);
        ecosystemToken.burn(amount);
    }

    /**
     * @dev Creates and funds new vesting contract for a new partner.
     */
    function addPartner(
        address partner,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        require(partner != address(0), "ERR_ADDRESS_ZERO");
        require(vestingContracts[partner] == address(0), "ERR_PARTNER_EXISTS");
        require(
            amount <= partnershipSupply / 2 && amount >= 100 ether,
            "ERR_INVALID AMOUNT"
        );
        require(
            totalPartnership + amount <= partnershipSupply,
            "ERR_AMOUNT_EXCEEDS_SUPPLY"
        );

        totalPartnership += amount;

        VestingWallet vestingContract = new VestingWallet(
            partner,
            uint64(block.timestamp + 365 days),
            uint64(730 days)
        );

        vestingContracts[partner] = address(vestingContract);

        emit AddPartner(partner, address(vestingContract), amount);
        require(
            ecosystemToken.transfer(address(vestingContract), amount),
            "ERR_ALLOCATION_TRANSFER_FAILED"
        );
    }
}
