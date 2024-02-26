// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface INEBULA {
    event SupplyLiquidity(address indexed src, uint256 amount);
    event Exchange(address indexed src, uint256 amountIn, uint256 amountOut);
    event Borrow(address indexed src, uint256 amount);
    event Repay(address indexed src, uint256 amount);
    event SupplyCollateral(
        address indexed src,
        address indexed asset,
        uint256 amount
    );
    event WithdrawCollateral(
        address indexed src,
        address indexed asset,
        uint256 amount
    );
    event Reward(address indexed to, uint256 amount);
    event Liquidated(address indexed src, uint256 amount);
    event UpdateCollateralConfig(address indexed token);
    event UpdateBaseBorrowRate(uint256 rate);
    event UpdateBaseProfitTarget(uint256 rate);
    event UpdateTargetReward(uint256 amount);
    event UpdateRewardInterval(uint256 interval);
    event UpdateRewardableSupply(uint256 amount);
    event UpdateLiquidatorThreshold(uint256 amount);
    event Upgrade(address indexed src, address indexed implementation);

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

    struct Asset {
        address oracleUSD;
        uint8 oracleDecimals;
        uint8 decimals;
        uint8 active;
        uint32 borrowThreshold;
        uint32 liquidationThreshold;
        uint256 maxSupplyThreshold;
    }

    function decimals() external view returns (uint8);

    function balanceOf(address src) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalBase() external view returns (uint256);

    function withdrawnLiquidity() external view returns (uint256);

    function totalBorrow() external view returns (uint256);

    function supplyInterestAccrueIndex() external view returns (uint256);

    function loanInterestAccrueIndex() external view returns (uint256);

    function targetReward() external view returns (uint256);

    function rewardInterval() external view returns (uint256);

    function rewardableSupply() external view returns (uint256);

    function baseBorrowRate() external view returns (uint256);

    function baseProfitTarget() external view returns (uint256);

    function liquidatorThreshold() external view returns (uint256);

    function pause() external;

    function unpause() external;

    function supplyLiquidity(uint256 amount) external;

    function exchange(uint256 amount) external;

    function getProtocolSnapshot()
        external
        view
        returns (ProtocolSnapshot memory);

    function getUserCollateralAssets(
        address src
    ) external view returns (address[] memory);

    function getCollateralInfo(
        address token
    ) external view returns (Asset memory);

    function getCollateral(
        address src,
        address asset
    ) external view returns (uint256);

    function getLoanPrincipal(address src) external view returns (uint256);

    function getAccruedDebt(address src) external view returns (uint256);

    function getListings() external view returns (address[] memory array);

    function isListed(address token) external view returns (bool);

    function listedAssets() external view returns (uint256);

    function getUtilization() external view returns (uint256);

    function getSupplyRate() external view returns (uint256);

    function getBorrowRate() external view returns (uint256);

    function getAssetPrice(address oracle) external view returns (uint256);

    function getAssetInfo(address asset) external view returns (Asset memory);

    function getTotalCollateral(address asset) external view returns (uint256);

    function isLiquidatable(address src) external view returns (bool);

    function liquidate(address src) external;

    function healthFactor(address src) external view returns (uint256);

    function creditValue(address src) external view returns (uint256);

    function borrow(uint256 amount) external;

    function repay(uint256 amount) external;

    function repayMax() external;

    function supplyCollateral(address asset, uint256 amount) external;

    function withdrawCollateral(address asset, uint256 amount) external;

    function exitAll() external;

    function isRewardable(address src) external view returns (bool);

    function updateBaseProfitTarget(uint256 rate) external;

    function updateLiquidatorThreshold(uint256 amount) external;

    function updateBaseBorrowRate(uint256 rate) external;

    function updateTargetReward(uint256 amount) external;

    function updateRewardInterval(uint256 interval) external;

    function updateRewardableSupply(uint256 amount) external;

    function updateCollateralConfig(
        address asset,
        address oracleUSD,
        uint8 oracleDecimals,
        uint8 assetDecimals,
        uint8 active,
        uint32 borrowThreshold,
        uint32 liquidationThreshold,
        uint256 maxTarget
    ) external;
}
