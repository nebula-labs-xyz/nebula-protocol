// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LINK is ERC20 {
    constructor() ERC20("Chainlink", "LINK") {}

    function drip(address to) public {
        _mint(to, 20000e6);
    }

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }
}
