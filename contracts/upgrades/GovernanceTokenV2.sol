// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**
 * @title Yoda GovernanceTokenV2
 * @notice Burnable contract that votes and has BnM-Bridge functionality
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ERC20PermitUpgradeable, NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @custom:oz-upgrades-from contracts/ecosystem/GovernanceToken.sol:GovernanceToken
contract GovernanceTokenV2 is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    uint256 public initialSupply;
    uint256 public maxBridge;
    uint8 public version;
    uint8 public tge;

    event TGE(uint256 amount);
    event BridgeMint(address to, uint256 amount);
    event Upgrade(address indexed src, address indexed implementation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeUUPS(address admin) public initializer {
        __ERC20_init("Yoda Coin", "YODA");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("Yoda Coin");
        __ERC20Votes_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        initialSupply = 50_000_000 ether;
        maxBridge = 10_000 ether;
    }

    function initializeTGE(
        address ecosystem,
        address treasury,
        address timelock
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tge == 0, "ERR_ALREADY_INITIALIZED");
        ++tge;

        emit TGE(initialSupply);
        _mint(address(this), initialSupply);

        uint256 maxTimelock = (initialSupply * 36) / 100;
        uint256 maxTreasury = (initialSupply * 20) / 100;
        uint256 maxEcosystem = (initialSupply * 44) / 100;
        _transfer(address(this), timelock, maxTimelock);
        _transfer(address(this), treasury, maxTreasury);
        _transfer(address(this), ecosystem, maxEcosystem);
    }

    receive() external payable {
        if (msg.value > 0) revert();
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function bridgeMint(
        address to,
        uint256 amount
    ) external onlyRole(BRIDGE_ROLE) whenNotPaused {
        require(amount <= maxBridge, "ERR_BRIDGE_LIMIT");
        require(amount + totalSupply() <= initialSupply, "ERR_BRIDGE_PROBLEM");
        emit BridgeMint(to, amount);
        _mint(to, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(
            ERC20Upgradeable,
            ERC20PausableUpgradeable,
            ERC20VotesUpgradeable
        )
    {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    )
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
