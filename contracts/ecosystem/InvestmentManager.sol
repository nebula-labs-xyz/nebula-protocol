// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;
/**
 * @title Yoda Ecosystem Investment manager
 * @notice Handles investment rounds and vesting contracts
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */
import {IYODA} from "../interfaces/IYODA.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IINVESTOR} from "../interfaces/IInvestmentManager.sol";
import {InvestorVesting} from "./InvestorVesting.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @custom:oz-upgrades
contract InvestmentManager is
    IINVESTOR,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    IYODA private ecosystemToken;
    IWETH9 private wethContract;
    address public timelock;
    address public treasury;

    uint256 public supply;
    uint256 public totalAllocation;

    uint8 public version;
    uint8 public round;
    Round[] public rounds;

    mapping(uint8 => address[]) private investors_;
    mapping(uint8 => mapping(address => uint256)) private ipos;
    mapping(uint8 => mapping(address => address)) public vestingContracts;
    mapping(uint8 => mapping(address => Investment)) public investorAllocations;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address token,
        address timelock_,
        address treasury_,
        address weth_,
        address guardian
    ) external initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, guardian);
        _grantRole(MANAGER_ROLE, timelock_);
        _grantRole(PAUSER_ROLE, guardian);

        ecosystemToken = IYODA(payable(token));
        wethContract = IWETH9(payable(weth_));

        timelock = timelock_;
        treasury = treasury_;
        version++;
    }

    receive() external payable {
        if (msg.sender != address(wethContract)) investEther(round);
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
     * @dev Getter ruturns the curretly active round.
     */
    function getCurrentRound() external view returns (uint8) {
        return round;
    }

    /**
     * @dev Getter ruturns the curretly active round details: Round object.
     */
    function getRoundInfo(
        uint8 round_
    ) external view returns (IINVESTOR.Round memory) {
        return rounds[round_];
    }

    /**
     * @dev Getter ruturns the curretly active round min invest amount.
     */
    function getMinInvestAmount(uint8 round_) external view returns (uint256) {
        IINVESTOR.Round memory item = rounds[round_];
        return item.etherTarget / 50;
    }

    /**
     * @dev Creates an investment round.
     */
    function createRound(
        uint64 start,
        uint64 duration,
        uint256 etherTarget,
        uint256 tokenAlloc
    ) external onlyRole(MANAGER_ROLE) {
        supply += tokenAlloc;
        uint256 balance = ecosystemToken.balanceOf(address(this));
        if (balance < supply) revert CustomError("NO_SUPPLY");
        uint64 end = start + duration;
        Round memory item = Round(etherTarget, 0, tokenAlloc, 0, start, end, 1);
        rounds.push(item);
    }

    /**
     * @dev Processes ETH investment into a round.
     */
    function investEther(uint8 round_) public payable whenNotPaused {
        if (round_ >= rounds.length) revert CustomError("INVALID_ROUND");
        invest(round_, msg.value);
        (bool success, ) = payable(address(wethContract)).call{
            value: msg.value
        }("");
        require(success, "TRANSFER_FAILED");
    }

    /**
     * @dev Processes WETH investment into a round.
     */
    function investWETH(
        uint8 round_,
        uint256 amount
    ) external whenNotPaused returns (bool success) {
        if (round_ >= rounds.length) revert CustomError("INVALID_ROUND");
        invest(round_, amount);
        success = wethContract.transferFrom(msg.sender, address(this), amount);
        if (!success) revert CustomError("WETH_TRANSFER_FAILED");
    }

    /**
     * @dev Allows investor to get a rufund from an open round.
     */
    function cancelInvestment(uint8 round_) external returns (bool success) {
        if (round_ > rounds.length) revert CustomError("INVALID_ROUND");
        Round storage current = rounds[round_];
        if (current.etherInvested == current.etherTarget)
            revert CustomError("ROUND_CLOSED");

        uint256 pos = ipos[round_][msg.sender];
        if (pos == 0) revert CustomError("INVESTOR_NOT_EXIST");

        investors_[round_][pos - 1] = investors_[round_][
            investors_[round_].length - 1
        ];
        investors_[round_].pop();
        delete ipos[round_][msg.sender];

        Investment memory item = investorAllocations[round_][msg.sender];
        delete investorAllocations[round][msg.sender];

        totalAllocation -= item.tokenAmount;
        current.etherInvested -= item.etherAmount;
        current.participants--;

        success = wethContract.transfer(msg.sender, item.etherAmount);
        if (!success) revert CustomError("CANCEL_INVESTMENT_FAILED");
    }

    /**
     * @dev Closes an investment round after the round target has been reached.
     */
    function closeRound(uint8 round_) external {
        if (round_ >= rounds.length) revert CustomError("INVALID_ROUND");
        Round memory current = rounds[round_];

        if (current.etherInvested < current.etherTarget)
            revert CustomError("ROUND_STILL_OPEN");

        deployVestingContracts(round_);
        round++;

        wethContract.withdraw(current.etherInvested);

        (bool success, ) = treasury.call{value: current.etherInvested}("");
        if (!success) revert CustomError("WITHDRAWAL_FAILED");
    }

    /**
     * @dev Allows manager to cancel a round if need be, and issues refunds (WETH) to investors.
     */
    function cancelRound(uint8 round_) external onlyRole(MANAGER_ROLE) {
        if (round_ >= rounds.length) revert CustomError("INVALID_ROUND");
        Round memory current = rounds[round_];
        if (current.etherInvested == current.etherTarget)
            revert CustomError("ROUND_CLOSED");

        address[] memory investors = investors_[round_];
        uint64 len = uint64(investors.length);
        if (round_ != rounds.length - 1 || round_ == 0)
            revert CustomError("CANT_CANCEL_ROUND");

        rounds.pop();
        supply -= current.tokenAllocation;
        withdrawTokens(current.tokenAllocation);

        for (uint64 i = 0; i < len; ++i) {
            Investment memory item = investorAllocations[round_][investors[i]];
            totalAllocation -= item.tokenAmount;
            delete investorAllocations[round_][investors[i]];

            bool success = wethContract.transfer(
                investors[i],
                item.etherAmount
            );
            if (!success) revert CustomError("WETH_TRANSFER_FAILED");
        }
    }

    function invest(uint8 round_, uint256 amount) internal {
        Round storage item = rounds[round_];

        if (amount < item.etherTarget / 50)
            revert CustomError("INVALID_AMOUNT");
        if (item.etherInvested + amount > item.etherTarget)
            revert CustomError("ROUND_OVERSUBSCRIBED");

        uint256 pos = ipos[round_][msg.sender];
        if (pos == 0) {
            investors_[round_].push(msg.sender);
            ipos[round_][msg.sender] = investors_[round_].length;
        }

        uint256 tokenAmount = (item.tokenAllocation * amount) /
            item.etherTarget;

        totalAllocation += tokenAmount;
        item.etherInvested += amount;
        item.participants = investors_[round_].length;
        Investment storage investment = investorAllocations[round_][msg.sender];
        investment.etherAmount += amount;
        investment.tokenAmount += tokenAmount;

        emit Invest(round_, msg.sender, amount);
        if (item.etherInvested == item.etherTarget) emit RoundClosed(round_);
    }

    function deployVestingContracts(uint8 round_) internal {
        address[] memory investors = investors_[round_];
        uint256 len = investors.length;
        delete investors;
        for (uint256 i = 0; i < len; ++i) {
            uint256 alloc = investorAllocations[round][investors[i]]
                .tokenAmount;
            InvestorVesting vestingContract = new InvestorVesting(
                address(ecosystemToken),
                investors[i],
                uint64(block.timestamp + 365 days), // cliff timestamp
                uint64(730 days) // duration after cliff
            );
            vestingContracts[round][investors[i]] = address(vestingContract);
            bool success = ecosystemToken.transfer(
                address(vestingContract),
                alloc
            );
            if (!success) revert CustomError("ALLOCATION_TRANSFER_FAILED");
        }
    }

    function withdrawTokens(uint256 amount) internal {
        require(
            ecosystemToken.transfer(treasury, amount),
            "ALLOCATION_TRANSFER_FAILED"
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }
}
