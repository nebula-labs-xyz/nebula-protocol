// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
/**
 * @title Yoda GovernorV2
 * @notice Standard OZUpgradeable governor, small modification with UUPS
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {
    GovernorVotesUpgradeable,
    IVotes
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {
    GovernorTimelockControlUpgradeable,
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";

/// @custom:oz-upgrades-from contracts/ecosystem/YodaGovernor.sol:YodaGovernor
contract YodaGovernorV2 is
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    /// @dev UUPS version tracker
    uint8 public uupsVersion;
    uint256[50] private __gap;

    /**
     * @dev Initialized Event.
     * @param src sender address
     */
    event Initialized(address indexed src);

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
     * @param _token IVotes token instance
     * @param _timelock timelock instance
     * @param guardian owner address
     */
    function initialize(IVotes _token, TimelockControllerUpgradeable _timelock, address guardian)
        external
        initializer
    {
        require(address(_token) != address(0x0), "ZERO_ADDRESS");
        require(address(_timelock) != address(0x0), "ZERO_ADDRESS");
        require(guardian != address(0x0), "ZERO_ADDRESS");

        __Governor_init("Yoda Governor");
        __GovernorSettings_init(7200, /* 1 day */ 50400, /* 1 week */ 20000e18);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(1);
        __GovernorTimelockControl_init(_timelock);
        __Ownable_init(guardian);
        __UUPSUpgradeable_init();

        ++uupsVersion;
        emit Initialized(msg.sender);
    }

    // The following functions are overrides required by Solidity.
    /// @inheritdoc GovernorUpgradeable
    function votingDelay() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    /// @inheritdoc GovernorUpgradeable
    function votingPeriod() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingPeriod();
    }

    /// @inheritdoc GovernorUpgradeable
    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /// @inheritdoc GovernorUpgradeable
    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /// @inheritdoc GovernorUpgradeable
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @inheritdoc GovernorUpgradeable
    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        ++uupsVersion;
        emit Upgrade(msg.sender, newImplementation);
    }

    /// @inheritdoc GovernorUpgradeable
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc GovernorUpgradeable
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc GovernorUpgradeable
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc GovernorUpgradeable
    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }
}
