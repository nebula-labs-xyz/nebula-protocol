// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**  
      ,,       ,,  ,,    ,,,    ,,   ,,,      ,,,    ,,,   ,,,          ,,,
     ███▄     ██  ███▀▀▀███▄   ██▄██▀▀██▄    ██▌     ██▌  ██▌        ▄▄███▄▄
    █████,   ██  ██▌          ██▌     └██▌  ██▌     ██▌  ██▌        ╟█   ╙██ 
    ██ └███ ██  ██▌└██╟██   l███▀▄███╟█    ██      ╟██  ╟█i        ▐█▌█▀▄██╟
   ██   ╙████  ██▌          ██▌     ,██▀   ╙██    ▄█▀  ██▌        ▐█▌    ██ 
  ██     ╙██  █████▀▀▄██▀  ██▌██▌╙███▀`     ▀██▄██▌   █████▀▄██▀ ▐█▌    ██╟ 
 ¬─      ¬─   ¬─¬─  ¬─¬─'  ¬─¬─¬─¬ ¬─'       ¬─¬─    '¬─   '─¬   ¬─     ¬─'

 * @title Nebula Protocol Liquidator
 * @notice Liquidation contract example
 * @author Nebula Labs Inc
 * @disclaimer !!! USE AT YOUR OWN RISK !!!
 * @custom:security-contact security@nebula-labs.xyz
 */
import "../interfaces/INebula.sol";
import "../vendor/@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "../vendor/@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "../vendor/@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashLoanRecipient is IFlashLoanRecipient, Ownable {
    IERC20 private immutable usdcContract;
    IVault private immutable balancerVault; // 0xBA12222222228d8Ba445958a75a0704d566BF2C8
    INEBULA private immutable nebulaContract;
    IERC20 private immutable govTokenContract;
    ISwapRouter private immutable uniswapRouter;

    constructor(
        address usdc,
        address nebula,
        address balancerVault_,
        address uniswapRouter_,
        address govToken
    ) Ownable(msg.sender) {
        usdcContract = IERC20(usdc);
        nebulaContract = INEBULA(payable(nebula));
        balancerVault = IVault(balancerVault_);
        uniswapRouter = ISwapRouter(uniswapRouter_); //uniswapV3
        govTokenContract = IERC20(govToken);
    }

    function liquidate(address account) external onlyOwner {
        if (nebulaContract.isLiquidatable(account)) {
            require(
                govTokenContract.balanceOf(address(this)) >= 20_000 ether,
                "ERR_INSUFFIENT_LIQUIDATOR_PRIVILEDGE"
            );

            uint256 debt = nebulaContract.getAccruedDebt(account);
            uint256 liquidationFee = debt / 100;
            IERC20[] memory array = new IERC20[](1);
            array[0] = usdcContract;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = debt + liquidationFee;

            makeFlashLoan(array, amounts, abi.encodePacked(account));
        }
    }

    function makeFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) internal {
        balancerVault.flashLoan(this, tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(balancerVault));
        address target = address(uint160(bytes20(userData)));
        address[] memory assets = nebulaContract.getUserCollateralAssets(
            target
        );
        uint256 len = assets.length;

        uint256[] memory tokenAmounts = new uint256[](len);
        for (uint256 i = 0; i < len; ++i) {
            uint256 amount = nebulaContract.getCollateral(target, assets[i]);
            if (amount > 0) {
                tokenAmounts[i] = amount;
            }
        }

        SafeERC20.forceApprove(
            usdcContract,
            address(nebulaContract),
            amounts[0]
        );
        nebulaContract.liquidate(target); // 🚩 🚩 🚩 🚩 🚩 //

        uint256 recievedBase;
        for (uint256 i = 0; i < len; ++i) {
            if (tokenAmounts[i] > 0) {
                INEBULA.Asset memory assetInfo = nebulaContract.getAssetInfo(
                    assets[i]
                );
                uint256 assetPrice = nebulaContract.getAssetPrice(
                    assetInfo.oracleUSD
                );
                uint256 amountOutMin = (tokenAmounts[i] * assetPrice * 99) /
                    10 ** assetInfo.oracleDecimals /
                    100;
                uint256 outAmount = uniswapV3(
                    assets[i],
                    tokenAmounts[i],
                    amountOutMin
                );
                recievedBase += outAmount;
            }
        }

        require(recievedBase > amounts[0] + feeAmounts[0]);
        SafeERC20.safeTransfer(
            tokens[0],
            address(balancerVault),
            amounts[0] + feeAmounts[0]
        );
    }

    function uniswapV3(
        address asset,
        uint256 swapAmount,
        uint256 amountOutMin
    ) internal returns (uint256) {
        uint24 poolFee = 3000;
        address usdc = address(usdcContract);

        SafeERC20.forceApprove(
            IERC20(asset),
            address(uniswapRouter),
            swapAmount
        );

        uint256 amountOut = uniswapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: asset,
                tokenOut: usdc,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: swapAmount,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );

        require(amountOut >= amountOutMin, "ERR_AMOUNT_OUT_MIN");

        return amountOut;
    }

    function withdraw() external onlyOwner {
        uint256 profit = usdcContract.balanceOf(address(this));
        uint256 govBalance = govTokenContract.balanceOf(address(this));
        SafeERC20.safeTransfer(usdcContract, msg.sender, profit);
        SafeERC20.safeTransfer(govTokenContract, msg.sender, govBalance);
    }
}