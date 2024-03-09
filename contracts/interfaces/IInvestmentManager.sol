// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;
/**
 * @title IInvestor Interface
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

interface IINVESTOR {
    /**
     * @dev Investment Struct.
     * @param etherAmount
     * @param tokenAmount,
     */
    struct Investment {
        uint256 etherAmount;
        uint256 tokenAmount;
    }

    /**
     * @dev Round Struct.
     * @param etherTarget, amount
     * @param etherInvested, amount
     * @param tokenAllocation, amount
     * @param participants, number
     * @param start, timestamp
     * @param end, timestamp
     * @param closed, number (0,1)
     */
    struct Round {
        uint256 etherTarget;
        uint256 etherInvested;
        uint256 tokenAllocation;
        uint256 participants;
        uint64 start;
        uint64 end;
        uint8 closed;
    }

    /**
     * @dev RoundClosed Event.
     * @param round, number
     */
    event RoundClosed(uint8 round);

    /**
     * @dev Invest Event
     * @param round, number
     * @param src, address
     * @param amount, amount
     */
    event Invest(uint8 round, address indexed src, uint256 amount);

    /**
     * @dev Upgrade Event.
     * @param src sender address
     * @param implementation address
     */
    event Upgrade(address indexed src, address indexed implementation);

    /**
     * @dev Custom Error.
     * @param msg error desription
     */
    error CustomError(string msg);

    /// @dev triggers the investEther function on receive
    receive() external payable;

    /**
     * @dev Pause contract.
     */
    function pause() external;

    /**
     * @dev Unpause contract.
     */
    function unpause() external;

    /**
     * @dev Creates an investment round.
     * @param start round start timestamp
     * @param duration seconds
     * @param ethTarget round target amount in ETH
     * @param tokenAlloc number of ecosystem tokens allocated to the round
     */
    function createRound(uint64 start, uint64 duration, uint256 ethTarget, uint256 tokenAlloc) external;

    /**
     * @dev Processes ETH investment into a round.
     * @param round round number in question
     */
    function investEther(uint8 round) external payable;

    /**
     * @dev Processes WETH investment into a round.
     * @param round round number in question
     * @param amount amount of ETH to invest
     */
    function investWETH(uint8 round, uint256 amount) external;

    /**
     * @dev Allows investor to get a rufund from an open round.
     * @param round round number in question
     */
    function cancelInvestment(uint8 round) external;

    /**
     * @dev Closes an investment round after the round target has been reached.
     * @param round number in question
     */
    function closeRound(uint8 round) external;

    /**
     * @dev Allows manager to cancel a round if need be, and issues refunds (WETH) to investors.
     * @param round round number in question
     */
    function cancelRound(uint8 round) external;

    /**
     * @dev Getter ruturns the curretly active round.
     * @return current round number
     */
    function getCurrentRound() external view returns (uint8);

    /**
     * @dev Getter ruturns the curretly active round details: Round object.
     * @param round round number in question
     * @return returns Round object
     */
    function getRoundInfo(uint8 round) external view returns (Round memory);

    /**
     * @dev Getter ruturns the round's min invest amount.
     * @param round round number in question
     * @return returns min invest amount (ETH)
     */
    function getMinInvestAmount(uint8 round) external view returns (uint256);
}
