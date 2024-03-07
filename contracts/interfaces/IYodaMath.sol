// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IYODAMATH {
    function rmul(uint256 x, uint256 y) external pure returns (uint256);

    function rdiv(uint256 x, uint256 y) external pure returns (uint256);

    function rpow(uint256 x, uint256 n) external pure returns (uint256);

    function annualRateToRay(uint256 rate) external pure returns (uint256);

    function accrueInterest(uint256 principal, uint256 rateRay, uint256 time) external pure returns (uint256);

    function getInterest(uint256 principal, uint256 rateRay, uint256 time) external pure returns (uint256);

    function breakEvenRate(uint256 loan, uint256 supplyInterest) external pure returns (uint256);
}
