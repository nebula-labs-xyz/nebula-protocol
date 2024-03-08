// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;
/**
 * @title Yoda BnM-Bridge Contract
 * @notice Creates BnM-Bridge
 * @author Nebula Labs Inc
 * @custom:security-contact security@nebula-labs.xyz
 */

import {IBRIDGE} from "../interfaces/IBridge.sol";
import {IERC20Bridgable} from "../interfaces/IERC20Bridgable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20 as TH} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @custom:oz-upgrades
contract Bridge is IBRIDGE, Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    /// @dev AccessControl Pauser Role

    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @dev AccessControl Manager Role
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    /// @dev AccessControl Upgrader Role
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @dev EnumerableSet of supported tokens
    EnumerableSet.AddressSet internal tokenSet;
    /// @dev EnumerableSet of supported chains
    EnumerableSet.UintSet internal chainSet;
    /// @dev stores last transaction ID
    uint256 public transactionId;
    /// @dev chain transcation count, by chainId
    mapping(uint256 => uint256) public chainCount;
    /// @dev Chain object by chainId mapping
    mapping(uint256 => Chain) public chains;
    /// @dev supported tokens mapping
    mapping(address => Token) public tokens;
    /// @dev Transaction by ID mapping
    mapping(uint256 => Transaction) private transactions;
    /// @dev number of UUPS upgrades
    uint8 public version;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the UUPS contract
     * @param guardian admin address
     * @param timelock address
     */
    function initialize(address guardian, address timelock) external initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, guardian);
        _grantRole(MANAGER_ROLE, timelock);
        _grantRole(PAUSER_ROLE, guardian);

        ++version;
    }

    /**
     * @dev Adds token to listed tokens.
     * @param name token name
     * @param symbol token symbol
     * @param token address
     */
    function listToken(string calldata name, string calldata symbol, address token)
        external
        whenNotPaused
        onlyRole(MANAGER_ROLE)
    {
        require(tokenSet.contains(token) != true, "ERR_TOKEN_EXISTS");

        Token storage item = tokens[token];
        item.name = name;
        item.symbol = symbol;
        item.tokenAddress = token;

        require(tokenSet.add(token), "ERR_LISTING_TOKEN");

        emit ListToken(token);
    }

    /**
     * @dev Removes token from listed tokens.
     * @param token address
     */
    function removeToken(address token) external whenNotPaused onlyRole(MANAGER_ROLE) {
        require(tokenSet.contains(token), "ERR_NOT_LISTED");
        delete tokens[token];
        require(tokenSet.remove(token), "ERR_TOKEN_REMOVE FAILED");
        emit DelistToken(token);
    }

    /**
     * @dev Bridge function BnM.
     * @param token address
     * @param to address
     * @param amount to mint
     * @param destChainId chianID where to mint
     * @return transactionId
     */
    function bridgeTokens(address token, address to, uint256 amount, uint256 destChainId)
        external
        whenNotPaused
        returns (uint256)
    {
        require(tokenSet.contains(token) == true, "ERR_UNLISTED_TOKEN");
        require(chainSet.contains(destChainId) == true, "ERR_UNKNOWN_CHAIN");
        IERC20Bridgable tokenContract = IERC20Bridgable(payable(token));
        require(tokenContract.balanceOf(msg.sender) >= amount, "ERR_INSUFFICIENT_BALANCE");
        transactionId++;
        chainCount[destChainId]++;

        transactions[transactionId] = Transaction(msg.sender, to, token, amount, block.timestamp, destChainId);

        emit Bridged(transactionId, msg.sender, to, token, amount, destChainId);
        TH.safeTransferFrom(tokenContract, msg.sender, address(this), amount);
        tokenContract.burn(amount);

        return transactionId;
    }

    /**
     * @dev Pause contract.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Add supported chain.
     * @param name chain name
     * @param chainId chain ID
     */
    function addChain(string calldata name, uint256 chainId) external whenNotPaused onlyRole(MANAGER_ROLE) {
        require(chainSet.contains(chainId) != true, "ERR_CHAIN_EXISTS");

        Chain storage item = chains[chainId];
        item.name = name;
        item.chainId = chainId;

        require(chainSet.add(chainId), "ERR_ADDING_CHAIN");

        emit AddChain(chainId);
    }

    /**
     * @dev Remove supported chain.
     * @param chainId chain ID
     */
    function removeChain(uint256 chainId) external whenNotPaused onlyRole(MANAGER_ROLE) {
        require(chainSet.contains(chainId), "ERR_NOT_LISTED");
        delete chains[chainId];
        require(chainSet.remove(chainId), "ERR_REMOVING_CHAIN");
        emit RemoveChain(chainId);
    }

    /**
     * @dev Getter for the Token object.
     * @param token address
     * @return Token info object
     */
    function getToken(address token) external view returns (Token memory) {
        return tokens[token];
    }

    /**
     * @dev Getter for the supported token listings.
     * @return array of listed token addresses
     */
    function getListings() external view returns (address[] memory array) {
        array = tokenSet.values();
    }

    /**
     * @dev Getter returns true if token is listed.
     * @param token address
     * @return boolean value
     */
    function isListed(address token) external view returns (bool) {
        return tokenSet.contains(token);
    }

    /**
     * @dev Getter returns listed token count.
     * @return number of listed tokens
     */
    function getListedCount() external view returns (uint256) {
        return tokenSet.length();
    }

    /**
     * @dev Getter returns chain transaction count.
     * @param chainId chain ID
     * @return number of transaction for this chain
     */
    function getChainTransactionCount(uint256 chainId) external view returns (uint256) {
        return chainCount[chainId];
    }

    /**
     * @dev Getter returns Chain object.
     * @param chainId chain ID
     * @return Chain struct (IBRIDGE)
     */
    function getChain(uint256 chainId) external view returns (Chain memory) {
        return chains[chainId];
    }

    /**
     * @dev Getter returns Token object.
     * @param token address
     * @return Token struct (IBRIDGE)
     */
    function getTokenInfo(address token) external view returns (Token memory) {
        return tokens[token];
    }

    /**
     * @dev Getter returns transaction object.
     * @param tranId address
     * @return Transaction struct (IBRIDGE)
     */
    function getTransaction(uint256 tranId) external view returns (Transaction memory) {
        return transactions[tranId];
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        ++version;
        emit Upgrade(msg.sender, newImplementation);
    }
}
