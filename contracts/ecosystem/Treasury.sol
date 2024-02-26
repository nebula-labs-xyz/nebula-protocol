// SPDX-License-Identifier: MIT
// Derived from OpenZeppelin Contracts (last updated v5.0.0) (finance/VestingWallet.sol)
pragma solidity ^0.8.20;
/**
 * @title Yoda Treasury Contract
 * @notice Vesting contract: initialRelease + (36 month duration)
 * @notice Offers flexible withdrawal schedule (gas efficient)
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {ITREASURY} from "../interfaces/ITreasury.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @custom:oz-upgrades
contract Treasury is
    ITREASURY,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    uint256 private _released;
    mapping(address token => uint256) private _erc20Released;
    uint64 private _start;
    uint64 private _duration;
    uint8 public version;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer.
     */
    function initialize(address admin, address timelock) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, timelock);

        _start = uint64(block.timestamp - 219 days);
        _duration = uint64(1095 days + 219 days);
        version++;
    }

    /**
     * @dev UUPS upgrade proxy.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }

    receive() external payable virtual {}

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
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the end timestamp.
     */
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /**
     * @dev Getter for the amount of eth already released
     */
    function released() public view virtual returns (uint256) {
        return _released;
    }

    /**
     * @dev Getter for the amount of token already released
     */
    function released(address token) public view virtual returns (uint256) {
        return _erc20Released[token];
    }

    /**
     * @dev Getter for the amount of releasable eth.
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address token) public view virtual returns (uint256) {
        return vestedAmount(token, uint64(block.timestamp)) - released(token);
    }

    /**
     * @dev Release the native token (ether) that have already vested.
     *
     * Emits a {EtherReleased} event.
     */
    function release(
        address to,
        uint256 amount
    ) external nonReentrant whenNotPaused onlyRole(MANAGER_ROLE) {
        uint256 vested = releasable();
        require(vested >= amount, "ERR_NOT_ENOUGH_VESTED");
        _released += amount;
        emit EtherReleased(to, amount);
        Address.sendValue(payable(to), amount);
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(
        address token,
        address to,
        uint256 amount
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        uint256 vested = releasable(token);
        require(vested >= amount, "ERR_NOT_ENOUGH_VESTED");
        _erc20Released[token] += amount;
        emit ERC20Released(token, to, amount);
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }

    /**
     * @dev Calculates the amount of ether that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(
        uint64 timestamp
    ) internal view virtual returns (uint256) {
        return _vestingSchedule(address(this).balance + released(), timestamp);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(
        address token,
        uint64 timestamp
    ) internal view virtual returns (uint256) {
        return
            _vestingSchedule(
                IERC20(token).balanceOf(address(this)) + released(token),
                timestamp
            );
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }
}
