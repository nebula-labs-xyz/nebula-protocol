// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Mock.sol";

contract USDC is ERC20Mock("USD Coin", "USDC") {
    constructor() {}

    function drip(address to) public {
        _mint(to, 20000e6);
    }

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }
}
