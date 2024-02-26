// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

interface IYODA is IERC20, IERC20Metadata {
    event TGE(uint256 amount);
    event BridgeMint(address to, uint256 amount);

    receive() external payable;

    /**
     * @dev UUPS deploy proxy initializer.
     */
    function initializeUUPS(address admin) external;

    /**
     * @dev Performs TGE.
     *
     * Emits a {TGE} event.
     */
    function initializeTGE(address ecosystem, address treasury) external;

    /**
     * @dev ERC20 pause contract.
     */
    function pause() external;

    /**
     * @dev ERC20 unpause contract.
     */
    function unpause() external;

    /**
     * @dev ERC20 burn.
     */
    function burn(uint256 value) external;

    /**
     * @dev ERC20 burn from.
     */
    function burnFrom(address account, uint256 value) external;

    /**
     * @dev Getter for the Initial supply.
     */
    function initialSupply() external view returns (uint256);

    /**
     * @dev Getter for the maximum amount alowed to pass through bridge in a single transaction.
     */
    function maxBridge() external view returns (uint256);

    /**
     * @dev Getter for the UUPS version, incremented with every upgrade.
     */
    function version() external view returns (uint8);

    /**
     * @dev Facilitates Bridge BnM functionality.
     */
    function bridgeMint(address to, uint256 amount) external;
}
