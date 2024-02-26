// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Bridgable is IERC20 {
    function burn(uint256 value) external;

    function bridgeMint(address to, uint256 amount) external;
}
