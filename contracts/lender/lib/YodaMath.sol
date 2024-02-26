// SPDX-License-Identifier: GPL-v3.0
// Derived from https://github.com/dapphub/dsmath
pragma solidity ^0.8.20;
import {IYODAMATH} from "../../interfaces/IYodaMath.sol";

contract YodaMath is IYODAMATH {
    uint256 public constant WAD = 1e6;
    uint256 public constant RAY = 1e27;
    uint256 public constant SECONDS_PER_YEAR_RAY = 365 * 86400 * RAY;

    constructor() {}

    function rmul(uint256 x, uint256 y) public pure returns (uint256 z) {
        z = ((x * y) + RAY / 2) / RAY;
    }

    function rdiv(uint256 x, uint256 y) public pure returns (uint256 z) {
        z = ((x * RAY) + y / 2) / y;
    }

    function rpow(uint256 x, uint256 n) public pure returns (uint256 r) {
        r = n % 2 == 1 ? x : RAY;
        while (n > 0) {
            if (n % 2 == 1) {
                r = rmul(r, x);
                n -= 1;
            } else {
                x = rmul(x, x);
                n /= 2;
            }
        }
    }

    function annualRateToRay(uint256 rate) public pure returns (uint256 r) {
        r = RAY + rdiv((rate * RAY) / WAD, SECONDS_PER_YEAR_RAY);
    }

    function accrueInterest(
        uint256 principal,
        uint256 rateRay,
        uint256 time
    ) public pure returns (uint256) {
        return rmul(principal, rpow(rateRay, time));
    }

    function getInterest(
        uint256 principal,
        uint256 rateRay,
        uint256 time
    ) public pure returns (uint256) {
        return rmul(principal, rpow(rateRay, time)) - principal;
    }

    function breakEvenRate(
        uint256 loan,
        uint256 supplyInterest
    ) public pure returns (uint256) {
        return ((WAD * (loan + supplyInterest)) / loan) - WAD;
    }
}
