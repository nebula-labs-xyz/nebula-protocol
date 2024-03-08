// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

interface IBRIDGE {
    struct Token {
        string name;
        string symbol;
        address tokenAddress;
    }

    struct Chain {
        string name;
        uint256 chainId;
    }

    struct Transaction {
        address sender;
        address receiver;
        address token;
        uint256 amount;
        uint256 time;
        uint256 destChainId;
    }
    
    event Upgrade(address indexed src, address indexed implementation);
    event ListToken(address indexed token);
    event DelistToken(address indexed token);
    event AddChain(uint256 chainId);
    event RemoveChain(uint256 chainId);
    event Bridged(uint256 transactionID, address from, address to, address token, uint256 amount, uint256 destChainId);

    error CustomError(string msg);

    function pause() external;

    function unpause() external;

    function listToken(string calldata name, string calldata symbol, address token) external;

    function removeToken(address token) external;

    function bridgeTokens(address token, address to, uint256 amount, uint256 destChainId) external returns (uint256);

    function addChain(string calldata name, uint256 chainId) external;

    function removeChain(uint256 chainId) external;

    function transactionId() external view returns (uint256);

    function chainCount(uint256 chainId) external view returns (uint256);

    function getToken(address token) external view returns (Token memory);

    function getListings() external view returns (address[] memory array);

    function isListed(address token) external view returns (bool);

    function getListedCount() external view returns (uint256);

    function getChainTransactionCount(uint256 chainId) external view returns (uint256);

    function getTransaction(uint256 tranId) external view returns (Transaction memory);

    function getChain(uint256 chainId) external view returns (Chain memory);

    function getTokenInfo(address token) external view returns (Token memory);
}
