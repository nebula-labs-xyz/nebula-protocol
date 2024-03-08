// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

interface IINVESTOR {
    struct Investment {
        uint256 etherAmount;
        uint256 tokenAmount;
    }

    struct Round {
        uint256 etherTarget;
        uint256 etherInvested;
        uint256 tokenAllocation;
        uint256 participants;
        uint64 start;
        uint64 end;
        uint8 closed;
    }

    event RoundClosed(uint8 round);
    event Invest(uint8 round, address indexed src, uint256 amount);
    event Upgrade(address indexed src, address indexed implementation);

    error CustomError(string msg);

    receive() external payable;

    function pause() external;

    function unpause() external;

    function createRound(uint64 start, uint64 duration, uint256 etherTarget, uint256 tokenAlloc) external;

    function investEther(uint8 round) external payable;

    function investWETH(uint8 round, uint256 amount) external;

    function cancelInvestment(uint8 round) external;

    function closeRound(uint8 round) external;

    function cancelRound(uint8 round) external;

    function getCurrentRound() external view returns (uint8);

    function getRoundInfo(uint8 round) external view returns (Round memory);

    function getMinInvestAmount(uint8 round) external view returns (uint256);
}
