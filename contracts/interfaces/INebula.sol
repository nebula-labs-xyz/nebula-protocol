// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;
/**
 * @title NEBULA Interface
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

interface INEBULA {
    /**
     *   @dev struct ProtocolSnapshot
     *   @param utilization
     *   @param borrowRate
     *   @param supplyRate
     *   @param totalBorrow
     *   @param totalBase
     *   @param targetReward
     *   @param rewardInterval
     *   @param rewardableSupply
     *   @param baseProfitTarget
     *   @param liquidatorThreshold
     */
    struct ProtocolSnapshot {
        uint256 utilization;
        uint256 borrowRate;
        uint256 supplyRate;
        uint256 totalBorrow;
        uint256 totalBase;
        uint256 targetReward;
        uint256 rewardInterval;
        uint256 rewardableSupply;
        uint256 baseProfitTarget;
        uint256 liquidatorThreshold;
    }

    /**
     *   @dev struct Asset
     *   @param oracleUSD
     *   @param oracleDecimals
     *   @param decimals
     *   @param active
     *   @param borrowThreshold
     *   @param liquidationThreshold
     *   @param maxSupplyThreshold
     */
    struct Asset {
        address oracleUSD;
        uint8 oracleDecimals;
        uint8 decimals;
        uint8 active;
        uint32 borrowThreshold;
        uint32 liquidationThreshold;
        uint256 maxSupplyThreshold;
    }

    /**
     * @dev Initialized Event.
     * @param src sender address
     */
    event Initialized(address indexed src);

    /**
     * @dev SupplyLiquidity Event
     * @param src sender address
     * @param amount USDC supplied (1e6)
     */
    event SupplyLiquidity(address indexed src, uint256 amount);

    /**
     * @dev Exchange Event
     * @param src sender address
     * @param amountIn nebula token to exchange
     * @param amountOut USDC amount
     */
    event Exchange(address indexed src, uint256 amountIn, uint256 amountOut);

    /**
     * @dev Borrow Event
     * @param src borrower address
     * @param amount USDC borrowed
     */
    event Borrow(address indexed src, uint256 amount);

    /**
     * @dev Repay Event
     * @param src borrower address
     * @param amount USDC repayed
     */
    event Repay(address indexed src, uint256 amount);

    /**
     * @dev SupplyCollateral Event
     * @param src sender address
     * @param asset address
     * @param amount of collateral
     */
    event SupplyCollateral(address indexed src, address indexed asset, uint256 amount);

    /**
     * @dev WithdrawCollateral Event
     * @param src sender address
     * @param asset address
     * @param amount of collateral
     */
    event WithdrawCollateral(address indexed src, address indexed asset, uint256 amount);

    /**
     * @dev Reward Event
     * @param to borrower address
     * @param amount USDC repayed
     */
    event Reward(address indexed to, uint256 amount);

    /**
     * @dev Liquidated Event
     * @param src borrower address
     * @param amount USDC repayed
     */
    event Liquidated(address indexed src, uint256 amount);

    /**
     * @dev UpdateCollateralConfig Event
     * @param token asset address
     */
    event UpdateCollateralConfig(address indexed token);

    /**
     * @dev UpdateBaseBorrowRate Event
     * @param rate new base borrow rate, default (0.06e6)
     */
    event UpdateBaseBorrowRate(uint256 rate);

    /**
     * @dev UpdateBaseProfitTarget Event
     * @param rate new profit rate, default (0.01e6)
     */
    event UpdateBaseProfitTarget(uint256 rate);

    /**
     * @dev UpdateTargetReward Event
     * @param amount new reward, default (20_000e18)
     */
    event UpdateTargetReward(uint256 amount);

    /**
     * @dev UpdateRewardInterval Event
     * @param interval new reward interval, default (6 months)
     */
    event UpdateRewardInterval(uint256 interval);

    /**
     * @dev UpdateRewardableSupply Event
     * @param amount new rewardable supply, default (100_000e18)
     */
    event UpdateRewardableSupply(uint256 amount);

    /**
     * @dev UpdateLiquidatorThreshold Event
     * @param amount new Liquidator limit, default (20_000e18)
     */
    event UpdateLiquidatorThreshold(uint256 amount);

    /**
     * @dev Upgrade Event.
     * @param src sender address
     * @param implementation address
     */
    event Upgrade(address indexed src, address indexed implementation);

    /**
     * @dev Custom Error.
     * @param msg error desription
     */
    error CustomError(string msg);

    /**
     * @dev Pause contract.
     */
    function pause() external;

    /**
     * @dev Unpause contract.
     */
    function unpause() external;

    /**
     * @dev Supply USDC liquidity to protocol, and receive Nebula tokens.
     * @param amount to be supplied in USDC (6 decimals)
     */
    function supplyLiquidity(uint256 amount) external;

    /**
     * @dev Exchange Nebula tokens back to USDC, receive yield.
     * @param amount to be exchanged in Nebula yield token (18 decimals)
     */
    function exchange(uint256 amount) external;

    /**
     * @dev Liquidates borrower collateral assets.
     * @param src borrower address
     * Emits a {Liquidated} event.
     */
    function liquidate(address src) external;

    /**
     * @dev Allows user to borrow USDC against his collateral.
     * @param amount to be borrowed
     * Emits a {Borrow} event.
     */
    function borrow(uint256 amount) external;

    /**
     * @dev Allows borrower to repay part of the debt.
     * @param amount to be repayed
     * Emits a {Repay} event.
     */
    function repay(uint256 amount) external;

    /**
     * @dev Allows borrower to repay total debt.
     *
     * Emits a {Repay} event.
     */
    function repayMax() external;

    /**
     * @dev Allows borrower to supply collateral.
     * @param asset address
     * @param amount to be supplied
     * Emits a {SupplyCollateral} event.
     */
    function supplyCollateral(address asset, uint256 amount) external;

    /**
     * @dev Allows borrower to withdraw collateral.
     * @param asset address
     * @param amount to be withdrawn
     * Emits a {WithdrawCollateral} event.
     */
    function withdrawCollateral(address asset, uint256 amount) external;

    /**
     * @dev Allows borrower to repay total debt, and withdraw all collateral
     * from the protocol in one transaction.
     *
     * Emits a {WithdrawCollateral} event.
     */
    function exitAll() external;

    /**
     * @dev Allows manager to update the base profit target.
     * @param rate protocol profit target, default (0.01e6)
     * Emits a {UpdateBaseProfitTarget} event.
     */
    function updateBaseProfitTarget(uint256 rate) external;

    /**
     * @dev Allows manager to update the liquidator threshold.
     * @param amount gov token amount (18 decimals)
     * Emits a {UpdateLiquidatorThreshold} event.
     */
    function updateLiquidatorThreshold(uint256 amount) external;

    /**
     * @dev Allows manager to update the base borrow rate.
     * @param rate default borrow rate, default (0.06e6)
     * Emits a {UpdateBaseBorrowRate} event.
     */
    function updateBaseBorrowRate(uint256 rate) external;

    /**
     * @dev Allows manager to update the target reward.
     * @param amount gov token amount (18 decimals)
     * Emits a {UpdateTargetReward} event.
     */
    function updateTargetReward(uint256 amount) external;

    /**
     * @dev Allows manager to update the reward interval.
     * @param interval number of seconds, default (6 months)
     * Emits a {UpdateRewardInterval} event.
     */
    function updateRewardInterval(uint256 interval) external;

    /**
     * @dev Allows manager to update collateral config.
     * @param amount USDC amount for min rewardable supply, default (100_000e6)
     * Emits a {UpdateCollateralConfig} event.
     */
    function updateRewardableSupply(uint256 amount) external;

    /**
     * @dev Allows manager to update collateral config.
     * @param asset address
     * @param oracleUSD address
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
        address oracleUSD,
        uint8 oracleDecimals,
        uint8 assetDecimals,
        uint8 active,
        uint32 borrowThreshold,
        uint32 liquidationThreshold,
        uint256 maxSupplyLimit
    ) external;

    /**
     * @dev Getter for the ERC20 decimals.
     * @return decimals
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Getter for the ERC20 balanceOf.
     * @param src address
     * @return user balance
     */
    function balanceOf(address src) external view returns (uint256);

    /**
     * @dev Getter for the ERC20 totalSupply.
     * @return totalSupply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev total borrow amount in USDC
     * @return current amount borrowed from protocol
     */
    function totalBorrow() external view returns (uint256);
    /**
     * @dev Getter for the total USDC in the protocol.
     * @return amount USDC (1e6)
     */
    function totalBase() external view returns (uint256);

    /**
     * @dev Getter withdrawnLiquidity .
     * @return total withdrawn liquidity
     */
    function withdrawnLiquidity() external view returns (uint256);
    /**
     * @dev Getter total amount of interest paid out to LPs
     * @return total interest paid to LPs
     */
    function supplyInterestAccrueIndex() external view returns (uint256);

    /**
     * @dev total amount of interest accrued by this contract
     * @return total interest collected from borrowers
     */
    function loanInterestAccrueIndex() external view returns (uint256);

    /**
     * @dev reward amount per base rewardable supply
     * @return reward amount
     */
    function targetReward() external view returns (uint256);

    /**
     * @dev reward interval rewards are paid out to LPs
     * @return reward interval
     */
    function rewardInterval() external view returns (uint256);

    /**
     * @dev amount of supply LPs must provide to qualify for reward
     * @return amount
     */
    function rewardableSupply() external view returns (uint256);

    /**
     * @dev minimal borrow rate charged for borrowing
     * @return base borrow rate, default (0.06e6)
     */
    function baseBorrowRate() external view returns (uint256);

    /**
     * @dev rate of commission this contract charges
     * @return protocol profit target rate, default (0.01e6)
     */
    function baseProfitTarget() external view returns (uint256);

    /**
     * @dev amount of gov tokens liquidator is required to have to run liquidations
     * @return required token amount
     */
    function liquidatorThreshold() external view returns (uint256);

    /**
     * @dev Getter returns the LP's rewardable status.
     * @param src LPs address
     * @return success boolean
     */
    function isRewardable(address src) external view returns (bool);

    /**
     * @dev Getter for the  protocol snapshot.
     * @return ProtocolSnapshot object
     */
    function getProtocolSnapshot() external view returns (ProtocolSnapshot memory);

    /**
     * @dev Getter for the current user collateral assets.
     * @param src address
     * @return Returns borrower collateral assets address array.
     */
    function getUserCollateralAssets(address src) external view returns (address[] memory);

    /**
     * @dev Getter for the individual collateral asset Info.
     * @param asset address
     * @return Returns Asset object.
     */
    function getCollateralInfo(address asset) external view returns (Asset memory);

    /**
     * @dev Getter for the current user collateral individual asset amount.
     * @param src address
     * @param asset address
     * @return Returns amount of collateral borrower has for the asset.
     */
    function getCollateral(address src, address asset) external view returns (uint256);

    /**
     * @dev Getter returns principal amount owed by a borrower on last transaction
     * @param src borrower address
     * @return borrower loan principal amount
     */
    function getLoanPrincipal(address src) external view returns (uint256);

    /**
     * @dev Getter returns total amount owed by a borrower
     * @param src borrower address
     * @return d - accrued borrower debt in USDC
     */
    function getAccruedDebt(address src) external view returns (uint256);

    /**
     * @dev Getter returns all listed collateral assets.
     * @return array of listed collateral assets
     */
    function getListings() external view returns (address[] memory array);

    /**
     * @dev Getter checks if collateral asset is listed.
     * @param token address
     * @return boolean value
     */
    function isListed(address token) external view returns (bool);

    /**
     * @dev Getter returns the total number of listed collateral assets.
     * @return number of listed collateral assets
     */
    function listedAssets() external view returns (uint256);

    /**
     * @dev Getter for the current utilization rate.
     * @return u - current utilization
     */
    function getUtilization() external view returns (uint256);

    /**
     * @dev Getter for the current supply rate.
     * @return the current supply rate
     */
    function getSupplyRate() external view returns (uint256);

    /**
     * @dev Getter for the current borrow rate.
     * @return the current borrow rate
     */
    function getBorrowRate() external view returns (uint256);

    /**
     * @dev Getter returns the price of a collateral assets.
     * @param oracle address
     * @return asset price
     */
    function getAssetPrice(address oracle) external view returns (uint256);

    /**
     * @dev Getter returns the Asset object.
     * @param asset address
     * @return Asset object
     */
    function getAssetInfo(address asset) external view returns (Asset memory);

    /**
     * @dev Getter for the total amount of particular asset collateral inside the protocol.
     * @param asset address
     * @return total amount of collateral held in this contract by asset.
     */
    function getTotalCollateral(address asset) external view returns (uint256);

    /**
     * @dev Getter returns true if borrowed amount reaches the collateral liquidation threshold.
     * @param src borrower address
     * @return success boolean
     */
    function isLiquidatable(address src) external view returns (bool);

    /**
     * @dev Getter calculates the health factor of a borrower.
     * @param src borrower address
     * @return health factor
     */
    function healthFactor(address src) external view returns (uint256);

    /**
     * @dev Getter calculates the max borrowable amount based on user collateral.
     * @param src borrower address
     * @return value in USDC
     */
    function creditValue(address src) external view returns (uint256);
}
