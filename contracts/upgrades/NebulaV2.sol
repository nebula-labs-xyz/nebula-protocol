// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
/**
 * ,,       ,,  ,,    ,,,    ,,   ,,,      ,,,    ,,,   ,,,          ,,,
 *      ███▄     ██  ███▀▀▀███▄   ██▄██▀▀██▄    ██▌     ██▌  ██▌        ▄▄███▄▄
 *     █████,   ██  ██▌          ██▌     └██▌  ██▌     ██▌  ██▌        ╟█   ╙██
 *     ██ └███ ██  ██▌└██╟██   l███▀▄███╟█    ██      ╟██  ╟█i        ▐█▌█▀▄██╟
 *    ██   ╙████  ██▌          ██▌     ,██▀   ╙██    ▄█▀  ██▌        ▐█▌    ██
 *   ██     ╙██  █████▀▀▄██▀  ██▌██▌╙███▀`     ▀██▄██▌   █████▀▄██▀ ▐█▌    ██╟
 *  ¬─      ¬─   ¬─¬─  ¬─¬─'  ¬─¬─¬─¬ ¬─'       ¬─¬─    '¬─   '─¬   ¬─     ¬─'
 *
 * @title Nebula Protocol V2
 * @notice An efficient monolithic lending protocol
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {YodaMath} from "../lender/lib/YodaMath.sol";
import {INEBULA} from "../interfaces/INebula.sol";
import {IECOSYSTEM} from "../interfaces/IEcosystem.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20 as TH} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AggregatorV3Interface} from "../vendor/@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";

/// @custom:oz-upgrades-from contracts/lender/Nebula.sol:Nebula
contract NebulaV2 is
    INEBULA,
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    YodaMath
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev AccessControl Pauser Role
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @dev AccessControl Manager Role
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    /// @dev AccessControl Upgrader Role
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @dev EnumerableSet of listed collateral assets
    EnumerableSet.AddressSet internal listedAsset;
    /// @dev USDC token instance
    IERC20 internal baseContract;
    /// @dev governance token instance
    IERC20 internal tokenContract;
    /// @dev ecosystem contract instance
    IECOSYSTEM internal ecosystemContract;
    /// @dev total borrow amount in USDC
    uint256 public totalBorrow;
    /// @dev total amount of liquidity in USDC
    uint256 public totalBase;
    /// @dev total amount withdrawn by LPs
    uint256 public withdrawnLiquidity;
    /// @dev total amount of interest paid out to LPs
    uint256 public supplyInterestAccrueIndex;
    /// @dev total amount of interest accrued by this contract
    uint256 public loanInterestAccrueIndex;
    /// @dev reward amount per base rewardable supply
    uint256 public targetReward;
    /// @dev reward interval rewards are paid out to LPs
    uint256 public rewardInterval;
    /// @dev amount of supply LPs must provide to qualify for reward
    uint256 public rewardableSupply;
    /// @dev minimal borrow rate charged for borrowing
    uint256 public baseBorrowRate;
    /// @dev rate of commission this contract charges
    uint256 public baseProfitTarget;
    /// @dev amount of gov tokens liquidator is required to have to run liquidations
    uint256 public liquidatorThreshold;
    /// @dev number of UUPS upgrades
    uint8 public version;
    /// @dev treasury address
    address public treasury;
    /// @dev timelock address
    address public timelock;
    /// @dev collateral asset Info mapping
    mapping(address => Asset) internal assetInfo;
    /// @dev borrower principal mapping
    mapping(address => uint256) internal loans;
    /// @dev borrower last interest accrual timestamp mapping
    mapping(address => uint256) internal loanAccrueTimeIndex;
    /// @dev LPs last interest accrual timestamp mapping
    mapping(address => uint256) internal liquidityAccrueTimeIndex;
    /// @dev total collateral amounts by asset mapping
    mapping(address => uint256) internal totalCollateral;
    /// @dev borrower address position mapping used to remove userCollateralAssets when needed
    mapping(address => uint256) internal ucaPos;
    /// @dev borrower collateral assets address mapping
    mapping(address => address[]) internal userCollateralAssets;
    /// @dev borrower collateral assets (by user address, by asset address) mapping
    mapping(address => mapping(address => uint256)) internal collateral;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice solidity receive function
     * @dev reverts on receive ETH
     */
    receive() external payable {
        if (msg.value > 0) revert("ERR_NO_RECEIVE");
    }

    /**
     * @dev Initializes the UUPS contract
     * @param usdc USDC address
     * @param govToken governance token address
     * @param ecosystem address
     * @param treasury_ address
     * @param timelock_ address
     * @param guardian admin address
     */
    function initialize(
        address usdc,
        address govToken,
        address ecosystem,
        address treasury_,
        address timelock_,
        address guardian
    ) external initializer {
        __ERC20_init("Nebula Coin", "NBL");
        __ERC20Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, guardian);
        _grantRole(PAUSER_ROLE, guardian);
        _grantRole(MANAGER_ROLE, timelock_);

        baseContract = IERC20(usdc);
        tokenContract = IERC20(govToken);
        ecosystemContract = IECOSYSTEM(payable(ecosystem));
        treasury = treasury_;
        timelock = timelock_;

        targetReward = 2_000 ether;
        rewardInterval = 180 days;
        rewardableSupply = 100_000 * WAD;
        baseBorrowRate = 0.06e6;
        baseProfitTarget = 0.01e6;
        liquidatorThreshold = 20_000 ether;
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
     * @dev Supply USDC liquidity to protocol, and receive Nebula tokens.
     * @param amount to be supplied in USDC (6 decimals)
     */
    function supplyLiquidity(uint256 amount) external nonReentrant {
        require(baseContract.balanceOf(msg.sender) >= amount, "ERR_INSUFFICIENT_BALANCE");
        uint256 total = baseContract.balanceOf(address(this)) + totalBorrow;
        if (total == 0) total = WAD;
        uint256 supply = totalSupply();
        uint256 value = (amount * supply) / total;
        uint256 utilization = getUtilization();
        if (supply == 0 || utilization == 0) value = amount;

        totalBase += amount;

        liquidityAccrueTimeIndex[msg.sender] = block.timestamp;
        _mint(msg.sender, value);

        emit SupplyLiquidity(msg.sender, amount);
        TH.safeTransferFrom(baseContract, msg.sender, address(this), amount);
    }

    /**
     * @dev Exchange Nebula tokens back to USDC, receive yield.
     * @param amount to be exchanged in Nebula yield token (18 decimals)
     */
    function exchange(uint256 amount) external nonReentrant {
        uint256 userBal = balanceOf(msg.sender);
        require(userBal > 0, "ERR_INSUFFICIENT_BALANCE");
        if (userBal <= amount) amount = userBal;

        uint256 fee;
        uint256 target = (amount * baseProfitTarget) / WAD; //1% commission
        uint256 total = baseContract.balanceOf(address(this)) + totalBorrow;

        if (total >= totalBase + target) {
            // this guarantees the totalBase will always remain >= 0
            // by only charging a fee when there is enough profit to sustain it
            // preventing overflow
            fee = target;
            _mint(treasury, fee);
        }

        uint256 supply = totalSupply();
        uint256 value = (amount * total) / supply;
        uint256 baseAmount = (amount * totalBase) / (supply - fee);
        assert(baseAmount <= value - fee);
        totalBase -= baseAmount;
        withdrawnLiquidity += value;
        supplyInterestAccrueIndex += value - baseAmount;

        rewardInternal(baseAmount);
        _burn(msg.sender, amount);

        emit Exchange(msg.sender, amount, value);
        TH.safeTransfer(baseContract, msg.sender, value);
    }

    /**
     * @dev Allows user to borrow USDC against his collateral.
     * @param amount to be borrowed
     * Emits a {Borrow} event.
     */
    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        require(totalBorrow + amount <= totalBase, "ERR_NO_LIQUIDITY");
        uint256 rateRay = annualRateToRay(getBorrowRate());
        uint256 balance;

        if (loans[msg.sender] > 0) {
            uint256 time = block.timestamp - loanAccrueTimeIndex[msg.sender];
            require(time > 0, "ERR_TIMESPAN");
            balance = accrueInterest(loans[msg.sender], rateRay, time);
        }

        loanAccrueTimeIndex[msg.sender] = block.timestamp;
        uint256 cValue = creditValue(msg.sender);

        require(amount + balance <= cValue, "ERR_UNCOLLATERALIZED");
        totalBorrow += (amount + balance) - loans[msg.sender];
        loans[msg.sender] = amount + balance;

        emit Borrow(msg.sender, amount);
        TH.safeTransfer(baseContract, msg.sender, amount);
    }

    /**
     * @dev Allows borrower to repay part of the debt.
     * @param amount to be repayed
     * Emits a {Repay} event.
     */
    function repay(uint256 amount) external nonReentrant whenNotPaused {
        require(loans[msg.sender] > 0, "ERR_NO_EXISTING_LOAN");
        uint256 balance = getAccruedDebt(msg.sender);

        if (amount >= balance) {
            amount = balance;
            delete loanAccrueTimeIndex[msg.sender];
        } else {
            loanAccrueTimeIndex[msg.sender] = block.timestamp;
        }

        uint256 accruedInterest = balance - loans[msg.sender];
        loanInterestAccrueIndex += accruedInterest;
        totalBorrow = totalBorrow + (balance - amount) - loans[msg.sender];
        loans[msg.sender] = balance - amount;

        repayInternal(amount);
    }

    /**
     * @dev Allows borrower to supply collateral.
     * @param asset address
     * @param amount to be supplied
     * Emits a {SupplyCollateral} event.
     */
    function supplyCollateral(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(listedAsset.contains(asset), "ERR_UNSUPPORTED_ASSET");
        Asset memory token = assetInfo[asset];
        require(token.active == 1, "ERR_DISABLED_ASSET");
        require(totalCollateral[asset] + amount <= token.maxSupplyThreshold, "ERR_ASSET_MAX_THRESHOLD");

        IERC20 assetContract = IERC20(asset);
        require(assetContract.balanceOf(msg.sender) >= amount, "ERR_INSUFFICIENT_BALANCE");

        if (collateral[msg.sender][asset] == 0) {
            require(userCollateralAssets[msg.sender].length < 20, "ERR_TOO_MANY_ASSETS");
            userCollateralAssets[msg.sender].push(asset);
            ucaPos[asset] = userCollateralAssets[msg.sender].length - 1;
        }

        collateral[msg.sender][asset] += amount;
        totalCollateral[asset] += amount;

        emit SupplyCollateral(msg.sender, asset, amount);
        TH.safeTransferFrom(assetContract, msg.sender, address(this), amount);
    }

    /**
     * @dev Allows borrower to withdraw collateral.
     * @param asset address
     * @param amount to be withdrawn
     * Emits a {WithdrawCollateral} event.
     */
    function withdrawCollateral(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(collateral[msg.sender][asset] >= amount, "ERR_INSUFFICIENT_BALANCE");

        collateral[msg.sender][asset] -= amount;
        totalCollateral[asset] -= amount;
        uint256 cv = creditValue(msg.sender);
        require(cv >= loans[msg.sender], "ERR_UNCOLLATERALIZED_LOAN");
        if (collateral[msg.sender][asset] == 0) {
            // updateUserCollateralAssets(msg.sender);
            uint256 ipos = ucaPos[asset];
            uint256 len = userCollateralAssets[msg.sender].length;
            userCollateralAssets[msg.sender][ipos] = userCollateralAssets[msg.sender][len - 1];
            userCollateralAssets[msg.sender].pop();
        }

        IERC20 assetContract = IERC20(asset);
        emit WithdrawCollateral(msg.sender, asset, amount);
        TH.safeTransfer(assetContract, msg.sender, amount);
    }

    /**
     * @dev Allows borrower to repay total debt, and withdraw all collateral
     * from the protocol in one transaction.
     *
     * Emits a {WithdrawCollateral} event.
     */
    function exitAll() external nonReentrant whenNotPaused {
        if (loans[msg.sender] > 0) repayMax();
        address[] memory assets = userCollateralAssets[msg.sender];
        uint256 len = assets.length;
        delete userCollateralAssets[msg.sender];

        for (uint256 i = 0; i < len; ++i) {
            uint256 amount = collateral[msg.sender][assets[i]];
            if (amount > 0) {
                IERC20 assetContract = IERC20(assets[i]);
                delete collateral[msg.sender][assets[i]];
                emit WithdrawCollateral(msg.sender, assets[i], amount);
                TH.safeTransfer(assetContract, msg.sender, amount);
            }
        }
    }

    /**
     * @dev Liquidates borrower collateral assets.
     * @param src borrower address
     * Emits a {Liquidated} event.
     */
    function liquidate(address src) external nonReentrant whenNotPaused {
        require(tokenContract.balanceOf(msg.sender) >= liquidatorThreshold, "ERR_NOT_LIQUIDATOR");
        require(isLiquidatable(src), "ERR_NOT_LIQUIDATABLE");
        uint256 balance = getAccruedDebt(src);
        uint256 liquidationFee = (balance * baseProfitTarget) / WAD; //1% commission
        loanInterestAccrueIndex += balance - loans[src];
        delete loans[src];

        TH.safeTransferFrom(baseContract, msg.sender, address(this), balance + liquidationFee);

        address[] memory assets = userCollateralAssets[src];
        uint256 len = assets.length;
        delete userCollateralAssets[src];

        _mint(treasury, liquidationFee / 2);
        emit Liquidated(src, balance);

        for (uint256 i = 0; i < len; ++i) {
            uint256 amount = collateral[src][assets[i]];
            if (amount > 0) {
                delete collateral[src][assets[i]];
                TH.safeTransfer(IERC20(assets[i]), msg.sender, amount);
            }
        }
    }

    /**
     * @dev Allows manager to update the base profit target.
     * @param rate protocol profit target, default (0.01e6)
     * Emits a {UpdateBaseProfitTarget} event.
     */
    function updateBaseProfitTarget(uint256 rate) external onlyRole(MANAGER_ROLE) {
        require(rate >= 0.0025e6, "ERR_INVALID_AMOUNT");
        emit UpdateBaseProfitTarget(rate);
        baseProfitTarget = rate;
    }

    /**
     * @dev Allows manager to update the base borrow rate.
     * @param rate default borrow rate, default (0.06e6)
     * Emits a {UpdateBaseBorrowRate} event.
     */
    function updateBaseBorrowRate(uint256 rate) external onlyRole(MANAGER_ROLE) {
        emit UpdateBaseBorrowRate(rate);
        require(rate >= 0.01e6, "ERR_INVALID_AMOUNT");
        baseBorrowRate = rate;
    }

    /**
     * @dev Allows manager to update the liquidator threshold.
     * @param amount gov token amount (18 decimals)
     * Emits a {UpdateLiquidatorThreshold} event.
     */
    function updateLiquidatorThreshold(uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(amount >= 10e18, "ERR_INVALID_AMOUNT");
        emit UpdateLiquidatorThreshold(amount);
        liquidatorThreshold = amount;
    }

    /**
     * @dev Allows manager to update the target reward.
     * @param amount gov token amount (18 decimals)
     * Emits a {UpdateTargetReward} event.
     */
    function updateTargetReward(uint256 amount) external onlyRole(MANAGER_ROLE) {
        emit UpdateTargetReward(amount);
        targetReward = amount;
    }

    /**
     * @dev Allows manager to update the reward interval.
     * @param interval number of seconds, default (6 months)
     * Emits a {UpdateRewardInterval} event.
     */
    function updateRewardInterval(uint256 interval) external onlyRole(MANAGER_ROLE) {
        require(interval >= 90 days, "ERR_INVALID_INTERVAL");
        emit UpdateRewardInterval(interval);
        rewardInterval = interval;
    }

    /**
     * @dev Allows manager to update collateral config.
     * @param amount USDC amount for min rewardable supply, default (100_000e6)
     * Emits a {UpdateCollateralConfig} event.
     */
    function updateRewardableSupply(uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(amount >= 20_000 * WAD, "ERR_INVALID_AMOUNT");
        emit UpdateRewardableSupply(amount);
        rewardableSupply = amount;
    }

    /**
     * @dev Allows manager to update collateral config.
     * @param asset address
     * @param oracle_ address
     * @param oracleDecimals uint8
     * @param assetDecimals uint8
     * @param active uint8 (0 or 1)
     * @param borrowThreshold 87% is passed in as 870
     * @param liquidationThreshold 92% is passed in as 920
     * @param maxSupplyLimit total asset amount limit allowed by the protocol
     * Emits a {UpdateCollateralConfig} event.
     */
    function updateCollateralConfig(
        address asset,
        address oracle_,
        uint8 oracleDecimals,
        uint8 assetDecimals,
        uint8 active,
        uint32 borrowThreshold,
        uint32 liquidationThreshold,
        uint256 maxSupplyLimit
    ) external onlyRole(MANAGER_ROLE) {
        if (listedAsset.contains(asset) != true) {
            require(listedAsset.add(asset), "ERR_ADDING_ASSET");
        }

        Asset storage item = assetInfo[asset];

        item.active = active;
        item.oracleUSD = oracle_;
        item.oracleDecimals = oracleDecimals;
        item.decimals = assetDecimals;
        item.borrowThreshold = borrowThreshold;
        item.liquidationThreshold = liquidationThreshold;
        item.maxSupplyThreshold = maxSupplyLimit;

        emit UpdateCollateralConfig(asset);
    }

    /**
     * @dev Getter for the  protocol snapshot.
     * @return ProtocolSnapshot object
     */
    function getProtocolSnapshot() external view returns (ProtocolSnapshot memory) {
        uint256 utilization = getUtilization();
        uint256 borrowRate = getBorrowRate();
        uint256 supplyRate = getSupplyRate();

        return ProtocolSnapshot(
            utilization,
            borrowRate,
            supplyRate,
            totalBorrow,
            totalBase,
            targetReward,
            rewardInterval,
            rewardableSupply,
            baseProfitTarget,
            liquidatorThreshold
        );
    }

    /**
     * @dev Getter for the current user collateral assets.
     * @param src address
     * @return Returns borrower collateral assets address array.
     */
    function getUserCollateralAssets(address src) external view returns (address[] memory) {
        return userCollateralAssets[src];
    }

    /**
     * @dev Getter for the individual collateral asset Info.
     * @param asset address
     * @return Returns Asset object.
     */
    function getCollateralInfo(address asset) external view returns (Asset memory) {
        return assetInfo[asset];
    }

    /**
     * @dev Getter for the current user collateral individual asset amount.
     * @param src address
     * @param asset address
     * @return Returns amount of collateral borrower has for the asset.
     */
    function getCollateral(address src, address asset) external view returns (uint256) {
        return collateral[src][asset];
    }

    /**
     * @dev Getter for the total amount of particular asset collateral inside the protocol.
     * @param asset address
     * @return total amount of collateral held in this contract by asset.
     */
    function getTotalCollateral(address asset) external view returns (uint256) {
        return totalCollateral[asset];
    }

    /**
     * @dev Getter returns principal amount owed by a borrower on last transaction
     * @param src borrower address
     * @return borrower loan principal amount
     */
    function getLoanPrincipal(address src) external view returns (uint256) {
        return loans[src];
    }

    /**
     * @dev Getter returns all listed collateral assets.
     * @return array of listed collateral assets
     */
    function getListings() external view returns (address[] memory array) {
        array = listedAsset.values();
    }

    /**
     * @dev Getter checks if collateral asset is listed.
     * @param token address
     * @return boolean value
     */
    function isListed(address token) external view returns (bool) {
        return listedAsset.contains(token);
    }

    /**
     * @dev Getter returns the total number of listed collateral assets.
     * @return number of listed collateral assets
     */
    function listedAssets() external view returns (uint256) {
        return listedAsset.length();
    }

    /**
     * @dev Getter returns the Asset object.
     * @param asset address
     * @return Asset object
     */
    function getAssetInfo(address asset) external view returns (Asset memory) {
        return assetInfo[asset];
    }

    /**
     * @dev Getter calculates the health factor of a borrower.
     * @param src borrower address
     * @return health factor
     */
    function healthFactor(address src) external view returns (uint256) {
        if (loans[src] == 0) return 0;
        uint256 balance = getAccruedDebt(src);
        address[] memory assets = userCollateralAssets[src];
        uint256 len = assets.length;
        uint256 liqLevel;

        for (uint256 i = 0; i < len; ++i) {
            uint256 amount = collateral[src][assets[i]];
            if (amount > 0) {
                Asset memory token = assetInfo[assets[i]];
                uint256 price = getAssetPrice(token.oracleUSD);
                liqLevel += (amount * price * token.liquidationThreshold * WAD) / 10 ** token.decimals / 1000
                    / 10 ** token.oracleDecimals;
            }
        }
        return (liqLevel * WAD) / balance;
    }

    /**
     * @dev Getter returns the LP's rewardable status.
     * @param src LPs address
     * @return success boolean
     */
    function isRewardable(address src) external view returns (bool) {
        if (liquidityAccrueTimeIndex[src] == 0) return false;
        uint256 supply = totalSupply();
        uint256 baseAmount = (balanceOf(src) * totalBase) / supply;

        return block.timestamp - rewardInterval >= liquidityAccrueTimeIndex[src] && baseAmount >= rewardableSupply;
    }

    /**
     * @dev Allows borrower to repay total debt.
     *
     * Emits a {Repay} event.
     */
    function repayMax() public nonReentrant whenNotPaused {
        require(loans[msg.sender] > 0, "ERR_NO_EXISTING_LOAN");
        uint256 balance = getAccruedDebt(msg.sender);
        totalBorrow = totalBorrow - loans[msg.sender];
        loanInterestAccrueIndex += balance - loans[msg.sender];
        delete loanAccrueTimeIndex[msg.sender];
        delete loans[msg.sender];

        repayInternal(balance);
    }

    /**
     * @dev Getter for the current utilization rate.
     * @return u - current utilization
     */
    function getUtilization() public view returns (uint256 u) {
        if (totalBase == 0 || totalBorrow == 0) {
            u = 0;
        } else {
            u = (WAD * totalBorrow) / totalBase;
        }
    }

    /**
     * @dev Getter for the current supply rate.
     * @return the current supply rate
     */
    function getSupplyRate() public view returns (uint256) {
        uint256 fee;
        uint256 supply = totalSupply();
        uint256 target = (supply * baseProfitTarget) / WAD; //1% commission
        uint256 total = baseContract.balanceOf(address(this)) + totalBorrow;
        if (total >= totalBase + target) {
            fee = target;
        }

        if (total == 0 || supply == 0) return 0;
        return ((WAD * total) / (supply + fee)) - WAD; // r = 0.05e6;
    }

    /**
     * @dev Getter for the current borrow rate.
     * @return the current borrow rate
     */
    function getBorrowRate() public view returns (uint256) {
        uint256 duration = 365 days;
        uint256 defaultSupply = WAD;
        uint256 utilization = getUtilization();
        if (utilization == 0) return baseBorrowRate;
        if (loans[msg.sender] > 0) {
            duration = block.timestamp - loanAccrueTimeIndex[msg.sender];
        }

        uint256 loan = (defaultSupply * utilization) / WAD;
        uint256 supplyRateRay = annualRateToRay(getSupplyRate());
        uint256 supplyInterest = getInterest(defaultSupply, supplyRateRay, duration);
        uint256 breakEven = breakEvenRate(loan, supplyInterest);

        uint256 rate = breakEven + baseProfitTarget;
        return rate > baseBorrowRate ? rate : baseBorrowRate;
    }

    /**
     * @dev Getter returns total amount owed by a borrower
     * @param src borrower address
     * @return d - accrued borrower debt in USDC
     */
    function getAccruedDebt(address src) public view returns (uint256 d) {
        uint256 time = block.timestamp - loanAccrueTimeIndex[src];
        require(time > 0, "ERR_TIMESPAN");
        uint256 rateRay = annualRateToRay(getBorrowRate());
        d = accrueInterest(loans[src], rateRay, time);
    }

    /**
     * @dev Getter returns true if borrowed amount reaches the collateral liquidation threshold.
     * @param src borrower address
     * @return success boolean
     */
    function isLiquidatable(address src) public view returns (bool) {
        if (loans[src] == 0) return false;
        uint256 balance = getAccruedDebt(src);
        address[] memory assets = userCollateralAssets[src];
        uint256 len = assets.length;
        uint256 cValue;

        for (uint256 i = 0; i < len; ++i) {
            uint256 amount = collateral[src][assets[i]];
            if (amount > 0) {
                Asset memory token = assetInfo[assets[i]];
                uint256 price = getAssetPrice(token.oracleUSD);
                cValue += (amount * price * token.liquidationThreshold * WAD) / 10 ** token.decimals / 1000
                    / 10 ** token.oracleDecimals;
            }
        }

        return balance >= cValue;
    }

    /**
     * @dev Getter returns the price of a collateral assets.
     * @param oracle address
     * @return asset price
     */
    function getAssetPrice(address oracle) public view returns (uint256) {
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(oracle).latestRoundData();

        require(answeredInRound >= roundId, "ERR_STALE_PRICE");
        require(updatedAt > block.timestamp - 60 * 60, "ERR_STALE_PRICE");

        return uint256(price);
    }

    /**
     * @dev Getter calculates the max borrowable amount based on user collateral.
     * @param src borrower address
     * @return value in USDC
     */
    function creditValue(address src) public view returns (uint256 value) {
        address[] memory assets = userCollateralAssets[src];
        uint256 len = assets.length;

        for (uint256 i = 0; i < len; ++i) {
            uint256 amount = collateral[src][assets[i]];
            if (amount > 0) {
                Asset memory token = assetInfo[assets[i]];
                uint256 price = getAssetPrice(token.oracleUSD);
                value += (amount * price * token.borrowThreshold * WAD) / 10 ** token.decimals / 1000
                    / 10 ** token.oracleDecimals;
            }
        }
    }

    /**
     * @dev See {ERC20-decimals}.
     * @inheritdoc ERC20Upgradeable
     */
    function decimals() public view virtual override(ERC20Upgradeable, INEBULA) returns (uint8) {
        return IERC20Metadata(address(baseContract)).decimals();
    }

    /**
     * @dev See {ERC20-balanceOf}.
     * @inheritdoc ERC20Upgradeable
     */
    function balanceOf(address src) public view virtual override(ERC20Upgradeable, INEBULA) returns (uint256) {
        return super.balanceOf(src);
    }

    /**
     * @dev See {ERC20-totalSupply}.
     * @inheritdoc ERC20Upgradeable
     */
    function totalSupply() public view virtual override(ERC20Upgradeable, INEBULA) returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc ERC20Upgradeable
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._update(from, to, value);
    }

    /**
     * @dev internal repay function.
     * @param amount to be repayed
     */
    function repayInternal(uint256 amount) internal {
        emit Repay(msg.sender, amount);
        TH.safeTransferFrom(baseContract, msg.sender, address(this), amount);
    }

    /**
     * @dev Calculates if reward is due to lenders on exchange operation
     * @param amount to be exchanged
     */
    function rewardInternal(uint256 amount) internal {
        bool rewardable =
            block.timestamp - rewardInterval >= liquidityAccrueTimeIndex[msg.sender] && amount >= rewardableSupply;

        if (rewardable) {
            uint256 duration = block.timestamp - liquidityAccrueTimeIndex[msg.sender];
            uint256 reward = (targetReward * duration) / rewardInterval;
            uint256 maxReward = ecosystemContract.maxReward();
            uint256 target = reward > maxReward ? maxReward : reward;
            delete liquidityAccrueTimeIndex[msg.sender];
            emit Reward(msg.sender, target);
            ecosystemContract.reward(msg.sender, target);
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }
}
