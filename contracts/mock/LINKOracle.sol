// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../vendor/@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LINKPriceConsumerV3 {
    constructor() {}

    int256 public price = 14e8;

    function setPrice(int256 newPrice) external {
        price = newPrice;
    }

    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, price, 1, 1, 1);
    }
}
