// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol"; // solhint-disable-line
import {IYODA} from "../contracts/interfaces/IYODA.sol";
import {USDC} from "../contracts/mock/USDC.sol";
import {WETHPriceConsumerV3} from "../contracts/mock/WETHOracle.sol";
import {WETH9} from "../contracts/vendor/canonical-weth/contracts/WETH9.sol";
import {ITREASURY} from "../contracts/interfaces/ITreasury.sol";
import {IECOSYSTEM} from "../contracts/interfaces/IEcosystem.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Treasury} from "../contracts/ecosystem/Treasury.sol";
import {TreasuryV2} from "../contracts/upgrades/TreasuryV2.sol";
import {Nebula} from "../contracts/lender/Nebula.sol";
import {NebulaV2} from "../contracts/upgrades/NebulaV2.sol";
import {Ecosystem} from "../contracts/ecosystem/Ecosystem.sol";
import {EcosystemV2} from "../contracts/upgrades/EcosystemV2.sol";
import {GovernanceToken} from "../contracts/ecosystem/GovernanceToken.sol";
import {GovernanceTokenV2} from "../contracts/upgrades/GovernanceTokenV2.sol";
import {YodaGovernor} from "../contracts/ecosystem/YodaGovernor.sol";
import {YodaGovernorV2} from "../contracts/upgrades/YodaGovernorV2.sol";
import {YodaTimelock} from "../contracts/ecosystem/YodaTimelock.sol";
import {YodaTimelockV2} from "../contracts/upgrades/YodaTimelockV2.sol";
import {TimelockControllerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BasicDeploy is Test {
    event Upgrade(address indexed src, address indexed implementation);

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 internal constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 internal constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 internal constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 internal constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    uint256 constant INIT_BALANCE_USDC = 100_000_000e6;
    uint256 constant INITIAL_SUPPLY = 50_000_000 ether;
    address constant ethereum = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant usdcWhale = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;
    address constant bridge = address(0x9999988);
    address constant partner = address(0x9999989);
    address constant guardian = address(0x9999990);
    address constant alice = address(0x9999991);
    address constant bob = address(0x9999992);
    address constant charlie = address(0x9999993);
    address constant registryAdmin = address(0x9999994);
    address constant managerAdmin = address(0x9999995);
    address constant pauser = address(0x9999996);
    address constant assetSender = address(0x9999997);
    address constant assetRecipient = address(0x9999998);
    address constant feeRecipient = address(0x9999999);
    address[] users;

    GovernanceToken internal tokenInstance;
    Ecosystem internal ecoInstance;
    YodaTimelock internal timelockInstance;
    YodaGovernor internal govInstance;
    Treasury internal treasuryInstance;
    USDC internal usdcInstance; // mock usdc
    WETH9 internal wethInstance;
    Nebula internal nebulaInstance;
    WETHPriceConsumerV3 internal oracleInstance;
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function deployTokenUpgrade() internal {
        // token deploy
        bytes memory data = abi.encodeCall(GovernanceToken.initializeUUPS, (guardian));
        address payable proxy = payable(Upgrades.deployUUPSProxy("GovernanceToken.sol", data));
        tokenInstance = GovernanceToken(proxy);
        address tokenImplementation = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(tokenInstance) == tokenImplementation);
        // upgrade token
        vm.prank(guardian);
        tokenInstance.grantRole(UPGRADER_ROLE, managerAdmin);

        vm.startPrank(managerAdmin);
        Upgrades.upgradeProxy(proxy, "GovernanceTokenV2.sol", "", guardian);
        vm.stopPrank();

        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        GovernanceTokenV2 instanceV2 = GovernanceTokenV2(proxy);
        assertEq(instanceV2.version(), 2);
        assertFalse(implAddressV2 == tokenImplementation);

        bool isUpgrader = instanceV2.hasRole(UPGRADER_ROLE, managerAdmin);
        assertTrue(isUpgrader == true);

        vm.prank(guardian);
        instanceV2.revokeRole(UPGRADER_ROLE, managerAdmin);
        assertFalse(instanceV2.hasRole(UPGRADER_ROLE, managerAdmin) == true);
    }

    function deployEcosystemUpgrade() internal {
        // token deploy
        bytes memory data = abi.encodeCall(GovernanceToken.initializeUUPS, (guardian));
        address payable proxy = payable(Upgrades.deployUUPSProxy("GovernanceToken.sol", data));
        tokenInstance = GovernanceToken(proxy);
        address tokenImplementation = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(tokenInstance) == tokenImplementation);

        // ecosystem deploy
        bytes memory data1 = abi.encodeCall(Ecosystem.initialize, (address(tokenInstance), guardian, pauser));
        address payable proxy1 = payable(Upgrades.deployUUPSProxy("Ecosystem.sol", data1));
        ecoInstance = Ecosystem(proxy1);
        address ecoImplementation = Upgrades.getImplementationAddress(proxy1);
        assertFalse(address(ecoInstance) == ecoImplementation);

        // upgrade Ecosystem
        vm.prank(guardian);
        ecoInstance.grantRole(UPGRADER_ROLE, managerAdmin);

        vm.startPrank(managerAdmin);
        Upgrades.upgradeProxy(proxy1, "EcosystemV2.sol", "", guardian);
        vm.stopPrank();

        address implAddressV2 = Upgrades.getImplementationAddress(proxy1);
        EcosystemV2 ecoInstanceV2 = EcosystemV2(proxy1);
        assertEq(ecoInstanceV2.version(), 2);
        assertFalse(implAddressV2 == ecoImplementation);

        bool isUpgrader = ecoInstanceV2.hasRole(UPGRADER_ROLE, managerAdmin);
        assertTrue(isUpgrader == true);

        vm.prank(guardian);
        ecoInstanceV2.revokeRole(UPGRADER_ROLE, managerAdmin);
        assertFalse(ecoInstanceV2.hasRole(UPGRADER_ROLE, managerAdmin) == true);
    }

    function deployTreasuryUpgrade() internal {
        vm.warp(365 days);
        // token deploy
        bytes memory data = abi.encodeCall(GovernanceToken.initializeUUPS, (guardian));
        address payable proxy = payable(Upgrades.deployUUPSProxy("GovernanceToken.sol", data));
        tokenInstance = GovernanceToken(proxy);
        address tokenImplementation = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(tokenInstance) == tokenImplementation);
        // timelock deploy
        uint256 timelockDelay = 24 * 60 * 60;
        address[] memory temp = new address[](1);
        temp[0] = ethereum;
        bytes memory data2 = abi.encodeCall(YodaTimelock.initialize, (timelockDelay, temp, temp, guardian));
        address payable proxy2 = payable(Upgrades.deployUUPSProxy("YodaTimelock.sol", data2));
        timelockInstance = YodaTimelock(proxy2);
        address tlImplementation = Upgrades.getImplementationAddress(proxy2);
        assertFalse(address(timelockInstance) == tlImplementation);
        //deploy Treasury
        bytes memory data1 = abi.encodeCall(Treasury.initialize, (guardian, address(timelockInstance)));
        address payable proxy1 = payable(Upgrades.deployUUPSProxy("Treasury.sol", data1));
        treasuryInstance = Treasury(proxy1);
        address implAddressV1 = Upgrades.getImplementationAddress(proxy1);
        assertFalse(address(treasuryInstance) == implAddressV1);
        // upgrade Treasury
        vm.prank(guardian);
        treasuryInstance.grantRole(UPGRADER_ROLE, managerAdmin);

        vm.startPrank(managerAdmin);
        Upgrades.upgradeProxy(proxy1, "TreasuryV2.sol", "", guardian);
        vm.stopPrank();

        address implAddressV2 = Upgrades.getImplementationAddress(proxy1);
        TreasuryV2 treasuryInstanceV2 = TreasuryV2(proxy1);
        assertEq(treasuryInstanceV2.version(), 2);
        assertFalse(implAddressV2 == implAddressV1);

        bool isUpgrader = treasuryInstanceV2.hasRole(UPGRADER_ROLE, managerAdmin);
        assertTrue(isUpgrader == true);

        vm.prank(guardian);
        treasuryInstanceV2.revokeRole(UPGRADER_ROLE, managerAdmin);
        assertFalse(treasuryInstanceV2.hasRole(UPGRADER_ROLE, managerAdmin) == true);
    }

    function deployTimelockUpgrade() internal {
        // deploy Timelock
        uint256 timelockDelay = 24 * 60 * 60;
        address[] memory temp = new address[](1);
        temp[0] = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        bytes memory data = abi.encodeCall(YodaTimelock.initialize, (timelockDelay, temp, temp, guardian));
        address payable proxy = payable(Upgrades.deployUUPSProxy("YodaTimelock.sol", data));
        YodaTimelock instance = YodaTimelock(proxy);
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(instance) == implAddressV1);
        // upgrade Timelock
        vm.prank(guardian);
        instance.grantRole(UPGRADER_ROLE, managerAdmin);

        vm.startPrank(managerAdmin);
        Upgrades.upgradeProxy(proxy, "YodaTimelockV2.sol", "", guardian);
        vm.stopPrank();

        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        YodaTimelockV2 ecoInstanceV2 = YodaTimelockV2(proxy);
        assertEq(ecoInstanceV2.version(), 2);
        assertFalse(implAddressV2 == implAddressV1);

        bool isUpgrader = ecoInstanceV2.hasRole(UPGRADER_ROLE, managerAdmin);
        assertTrue(isUpgrader == true);

        vm.prank(guardian);
        ecoInstanceV2.revokeRole(UPGRADER_ROLE, managerAdmin);
        assertFalse(ecoInstanceV2.hasRole(UPGRADER_ROLE, managerAdmin) == true);
    }

    function deployGovernorUpgrade() internal {
        // deploy Token
        bytes memory data = abi.encodeCall(GovernanceToken.initializeUUPS, (guardian));
        address payable proxy = payable(Upgrades.deployUUPSProxy("GovernanceToken.sol", data));
        tokenInstance = GovernanceToken(proxy);
        address tokenImplementation = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(tokenInstance) == tokenImplementation);

        // deploy Timelock
        uint256 timelockDelay = 24 * 60 * 60;
        address[] memory temp = new address[](1);
        temp[0] = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        bytes memory data1 = abi.encodeCall(YodaTimelock.initialize, (timelockDelay, temp, temp, guardian));
        address payable proxy1 = payable(Upgrades.deployUUPSProxy("YodaTimelock.sol", data1));
        YodaTimelock instance = YodaTimelock(proxy1);
        address implAddressV1 = Upgrades.getImplementationAddress(proxy1);
        assertFalse(address(instance) == implAddressV1);

        // deploy Governor
        bytes memory data2 = abi.encodeCall(
            YodaGovernor.initialize, (tokenInstance, TimelockControllerUpgradeable(payable(proxy1)), guardian)
        );
        address payable proxy2 = payable(Upgrades.deployUUPSProxy("YodaGovernor.sol", data2));
        YodaGovernor govInstanceV1 = YodaGovernor(proxy2);
        address govImplAddressV1 = Upgrades.getImplementationAddress(proxy2);
        assertFalse(address(govInstanceV1) == govImplAddressV1);
        assertEq(govInstanceV1.uupsVersion(), 1);

        // upgrade Governor
        Upgrades.upgradeProxy(proxy2, "YodaGovernorV2.sol", "", guardian);
        address govImplAddressV2 = Upgrades.getImplementationAddress(proxy2);

        YodaGovernorV2 govInstanceV2 = YodaGovernorV2(proxy2);
        assertEq(govInstanceV2.uupsVersion(), 2);
        assertFalse(govImplAddressV2 == govImplAddressV1);
    }

    function deployNebulaUpgrade() public {
        deployComplete();
        assertEq(tokenInstance.totalSupply(), 0);
        // this is the TGE
        vm.prank(guardian);
        tokenInstance.initializeTGE(address(ecoInstance), address(treasuryInstance));
        uint256 ecoBal = tokenInstance.balanceOf(address(ecoInstance));
        uint256 treasuryBal = tokenInstance.balanceOf(address(treasuryInstance));

        assertEq(ecoBal, 22_000_000 ether);
        assertEq(treasuryBal, 28_000_000 ether);
        assertEq(tokenInstance.totalSupply(), ecoBal + treasuryBal);

        // Nebula deploy
        usdcInstance = new USDC();

        bytes memory data = abi.encodeCall(
            Nebula.initialize,
            (
                address(usdcInstance),
                address(tokenInstance),
                address(ecoInstance),
                address(treasuryInstance),
                address(timelockInstance),
                guardian
            )
        );
        address payable proxy = payable(Upgrades.deployUUPSProxy("Nebula.sol", data));
        nebulaInstance = Nebula(proxy);
        address implementationV1 = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(nebulaInstance) == implementationV1);

        // upgrade Nebula
        assertEq(nebulaInstance.version(), 1);
        vm.prank(guardian);
        nebulaInstance.grantRole(UPGRADER_ROLE, managerAdmin);

        vm.startPrank(managerAdmin);
        Upgrades.upgradeProxy(proxy, "NebulaV2.sol", "", guardian);
        vm.stopPrank();

        address implementationV2 = Upgrades.getImplementationAddress(proxy);

        NebulaV2 nebulaInstanceV2 = NebulaV2(proxy);
        assertEq(nebulaInstanceV2.version(), 2);
        assertFalse(implementationV2 == implementationV1);

        vm.prank(guardian);
        nebulaInstance.revokeRole(UPGRADER_ROLE, managerAdmin);
        assertTrue(nebulaInstance.hasRole(UPGRADER_ROLE, managerAdmin) == false);
    }

    function deployComplete() internal {
        vm.warp(365 days);
        // token deploy
        bytes memory data = abi.encodeCall(GovernanceToken.initializeUUPS, (guardian));
        address payable proxy = payable(Upgrades.deployUUPSProxy("GovernanceToken.sol", data));
        tokenInstance = GovernanceToken(proxy);
        address tokenImplementation = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(tokenInstance) == tokenImplementation);

        // ecosystem deploy
        bytes memory data1 = abi.encodeCall(Ecosystem.initialize, (address(tokenInstance), guardian, pauser));
        address payable proxy1 = payable(Upgrades.deployUUPSProxy("Ecosystem.sol", data1));
        ecoInstance = Ecosystem(proxy1);
        address ecoImplementation = Upgrades.getImplementationAddress(proxy1);
        assertFalse(address(ecoInstance) == ecoImplementation);

        // timelock deploy
        uint256 timelockDelay = 24 * 60 * 60;
        address[] memory temp = new address[](1);
        temp[0] = ethereum;
        bytes memory data2 = abi.encodeCall(YodaTimelock.initialize, (timelockDelay, temp, temp, guardian));
        address payable proxy2 = payable(Upgrades.deployUUPSProxy("YodaTimelock.sol", data2));
        timelockInstance = YodaTimelock(proxy2);
        address tlImplementation = Upgrades.getImplementationAddress(proxy2);
        assertFalse(address(timelockInstance) == tlImplementation);

        // governor deploy
        bytes memory data3 = abi.encodeCall(
            YodaGovernor.initialize, (tokenInstance, TimelockControllerUpgradeable(payable(proxy2)), guardian)
        );
        address payable proxy3 = payable(Upgrades.deployUUPSProxy("YodaGovernor.sol", data3));
        govInstance = YodaGovernor(proxy3);
        address govImplementation = Upgrades.getImplementationAddress(proxy3);
        assertFalse(address(govInstance) == govImplementation);

        // reset timelock proposers and executors
        vm.startPrank(guardian);
        timelockInstance.revokeRole(PROPOSER_ROLE, ethereum);
        timelockInstance.revokeRole(EXECUTOR_ROLE, ethereum);
        timelockInstance.revokeRole(CANCELLER_ROLE, ethereum);
        timelockInstance.grantRole(PROPOSER_ROLE, address(govInstance));
        timelockInstance.grantRole(EXECUTOR_ROLE, address(govInstance));
        timelockInstance.grantRole(CANCELLER_ROLE, address(govInstance));
        vm.stopPrank();

        //deploy Treasury
        bytes memory data4 = abi.encodeCall(Treasury.initialize, (guardian, address(timelockInstance)));
        address payable proxy4 = payable(Upgrades.deployUUPSProxy("Treasury.sol", data4));
        treasuryInstance = Treasury(proxy4);
        address tImplementation = Upgrades.getImplementationAddress(proxy4);
        assertFalse(address(treasuryInstance) == tImplementation);
    }
}
