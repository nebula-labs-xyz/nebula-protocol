// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../BasicDeploy.sol";
import {USDC} from "../../contracts/mock/USDC.sol";
import {IPROTOCOL} from "../../contracts/interfaces/IProtocol.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WETH9} from "../../contracts/vendor/canonical-weth/contracts/WETH9.sol";
import {WETHPriceConsumerV3} from "../../contracts/mock/WETHOracle.sol";

contract ProtocolTest is BasicDeploy {
    event Borrow(address indexed src, uint256 amount);

    function setUp() public {
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

        usdcInstance = new USDC();
        wethInstance = new WETH9();
        oracleInstance = new WETHPriceConsumerV3();
        bytes memory data = abi.encodeCall(
            Lendefi.initialize,
            (
                address(usdcInstance),
                address(tokenInstance),
                address(ecoInstance),
                address(treasuryInstance),
                address(timelockInstance),
                guardian
            )
        );
        address payable proxy = payable(Upgrades.deployUUPSProxy("Lendefi.sol", data));
        LendefiInstance = Lendefi(proxy);
        address implementation = Upgrades.getImplementationAddress(proxy);
        assertFalse(address(LendefiInstance) == implementation);

        vm.prank(guardian);
        ecoInstance.grantRole(REWARDER_ROLE, address(LendefiInstance));
    }

    function test_Revert_Receive() public returns (bool success) {
        vm.expectRevert(); // contract does not receive ether
        (success,) = payable(address(LendefiInstance)).call{value: 100 ether}("");
    }

    function test_Revert_Initialization() public {
        bytes memory expError = abi.encodeWithSignature("InvalidInitialization()");
        vm.expectRevert(expError); // contract already initialized
        LendefiInstance.initialize(
            address(usdcInstance),
            address(tokenInstance),
            address(ecoInstance),
            address(treasuryInstance),
            address(timelockInstance),
            guardian
        );
    }

    function test_Pause() public {
        assertEq(LendefiInstance.paused(), false);
        vm.startPrank(guardian);
        LendefiInstance.pause();
        assertEq(LendefiInstance.paused(), true);
        LendefiInstance.unpause();
        assertEq(LendefiInstance.paused(), false);
        vm.stopPrank();
    }

    function test_Revert_Pause_Branch1() public {
        assertEq(LendefiInstance.paused(), false);

        bytes memory expError =
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", managerAdmin, PAUSER_ROLE);
        vm.prank(managerAdmin);
        vm.expectRevert(expError);
        LendefiInstance.pause();
    }

    function test_UpdateCollateralConfig() public {
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);
        IPROTOCOL.Asset memory item = LendefiInstance.getCollateralInfo(address(wethInstance));
        assertTrue(item.oracleUSD == address(oracleInstance));
        assertTrue(item.oracleDecimals == 8);
        assertTrue(item.decimals == 18);
        assertTrue(item.active == 1);
        assertTrue(item.borrowThreshold == 870);
        assertTrue(item.liquidationThreshold == 920);
        assertTrue(item.maxSupplyThreshold == 10_000 ether);
    }

    function test_Revert_UpdateCollateralConfig_Branch1() public {
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        bytes memory expError =
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", managerAdmin, MANAGER_ROLE);
        vm.prank(managerAdmin);
        vm.expectRevert(expError); // access control
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
    }

    function test_SupplyLiquidity() public {
        usdcInstance.mint(alice, 100_000e6);
        vm.startPrank(alice);
        usdcInstance.approve(address(LendefiInstance), 100_000e6);
        LendefiInstance.supplyLiquidity(100_000e6);
        vm.stopPrank();
        assertEq(usdcInstance.balanceOf(address(LendefiInstance)), 100_000e6);
        assertEq(LendefiInstance.totalBase(), 100_000e6);
        assertEq(LendefiInstance.balanceOf(alice), 100_000e6);
    }

    function test_Revert_SupplyCollateral_Branch1() public {
        assertEq(LendefiInstance.paused(), false);
        vm.prank(guardian);
        LendefiInstance.pause();
        assertEq(LendefiInstance.paused(), true);
        vm.deal(bob, 10 ether);

        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        bytes memory expError = abi.encodeWithSignature("EnforcedPause()");
        vm.expectRevert(expError); // contract paused
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);
        vm.stopPrank();
    }

    function test_Revert_SupplyCollateral_Branch2() public {
        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        vm.expectRevert("ERR_UNSUPPORTED_ASSET");
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);
        vm.stopPrank();
    }

    function test_Revert_SupplyCollateral_Branch3() public {
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance),
            address(oracleInstance),
            8,
            18,
            0, // zero means disabled
            870,
            920,
            10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        vm.expectRevert("ERR_DISABLED_ASSET");
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);
        vm.stopPrank();
    }

    function test_Revert_SupplyCollateral_Branch4() public {
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 10_001 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10_001 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10_001 ether);
        wethInstance.approve(address(LendefiInstance), 10_001 ether);
        vm.expectRevert("ERR_ASSET_MAX_THRESHOLD");
        LendefiInstance.supplyCollateral(address(wethInstance), 10_001 ether);
        vm.stopPrank();
    }

    function test_Revert_SupplyCollateral_Branch5() public {
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 1000 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 1000 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 1000 ether);
        wethInstance.approve(address(LendefiInstance), 1001 ether);
        vm.expectRevert("ERR_INSUFFICIENT_BALANCE");
        LendefiInstance.supplyCollateral(address(wethInstance), 1001 ether);
        vm.stopPrank();
    }

    function test_SupplyCollateral() public {
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);
        vm.stopPrank();
        assertEq(LendefiInstance.getCollateral(bob, address(wethInstance)), 10 ether);
        assertEq(LendefiInstance.getTotalCollateral(address(wethInstance)), 10 ether);
    }

    function test_WithdrawCollateral() public {
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);

        assertEq(LendefiInstance.getCollateral(bob, address(wethInstance)), 10 ether);
        assertEq(LendefiInstance.getTotalCollateral(address(wethInstance)), 10 ether);

        LendefiInstance.withdrawCollateral(address(wethInstance), 10 ether);
        vm.stopPrank();

        assertEq(LendefiInstance.getCollateral(bob, address(wethInstance)), 0);
        assertEq(LendefiInstance.getTotalCollateral(address(wethInstance)), 0);
        assertEq(wethInstance.balanceOf(bob), 10 ether);
    }

    function test_Revert_Borrow_Branch1() public {
        supplyLiquidity(alice, 100_000e6);

        assertEq(LendefiInstance.paused(), false);
        vm.prank(guardian);
        LendefiInstance.pause();
        assertEq(LendefiInstance.paused(), true);
        bytes memory expError = abi.encodeWithSignature("EnforcedPause()");

        vm.prank(bob);
        vm.expectRevert(expError); // contract paused
        LendefiInstance.borrow(10 ether);
    }

    function test_Revert_Borrow_Branch2() public {
        vm.prank(bob);
        vm.expectRevert("ERR_NO_LIQUIDITY");
        LendefiInstance.borrow(10 ether);
    }

    function test_Revert_Borrow_Branch3() public {
        supplyLiquidity(alice, 100_000e6);
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);

        assertEq(LendefiInstance.getCollateral(bob, address(wethInstance)), 10 ether);
        assertEq(LendefiInstance.getTotalCollateral(address(wethInstance)), 10 ether);
        LendefiInstance.borrow(10_000e6);
        vm.expectRevert("ERR_TIMESPAN"); //can't borrow twice on the same block
        LendefiInstance.borrow(10_000e6);

        vm.stopPrank();
    }

    function test_Revert_Borrow_Branch4() public {
        supplyLiquidity(alice, 100_000e6);
        vm.prank(bob);
        vm.expectRevert("ERR_UNCOLLATERALIZED");
        LendefiInstance.borrow(10_000e6);
    }

    function test_Borrow() public {
        supplyLiquidity(alice, 100_000e6);
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);

        assertEq(LendefiInstance.getCollateral(bob, address(wethInstance)), 10 ether);
        assertEq(LendefiInstance.getTotalCollateral(address(wethInstance)), 10 ether);

        vm.expectEmit();
        emit Borrow(bob, 10_000e6);
        LendefiInstance.borrow(10_000e6);
        vm.stopPrank();
        assertEq(usdcInstance.balanceOf(bob), 10_000e6);
    }

    function test_HealthFactor() public {
        supplyLiquidity(alice, 100_000e6);
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(
            address(wethInstance), address(oracleInstance), 8, 18, 1, 870, 920, 10_000 ether
        );
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);

        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool success,) = payable(address(wethInstance)).call{value: 10 ether}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(bob), 10 ether);
        wethInstance.approve(address(LendefiInstance), 10 ether);
        LendefiInstance.supplyCollateral(address(wethInstance), 10 ether);

        assertEq(LendefiInstance.getCollateral(bob, address(wethInstance)), 10 ether);
        assertEq(LendefiInstance.getTotalCollateral(address(wethInstance)), 10 ether);

        vm.expectEmit();
        emit Borrow(bob, 10_000e6);
        LendefiInstance.borrow(10_000e6);
        vm.stopPrank();
        assertEq(usdcInstance.balanceOf(bob), 10_000e6);

        vm.warp(367 days);
        vm.roll(367 days);
        uint256 healthFactor = LendefiInstance.healthFactor(bob);
        // collateral value times liquidation threshold divided by accrued debt (25000*0.92 / loan)
        assertTrue(healthFactor > 2e6);
    }

    function test_BorrowTwice() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 10 ether);
        supplyCollateral(bob, 10 ether);
        borrow(bob, 10_000e6);
        vm.warp(367 days);
        vm.roll(367 days);
        borrow(bob, 10_000e6);
        assertEq(usdcInstance.balanceOf(bob), 20_000e6);
        vm.warp(368 days);
        vm.roll(368 days);
        assertTrue(LendefiInstance.getAccruedDebt(bob) > 20_000e6);
        uint256 healthFactor = LendefiInstance.healthFactor(bob);
        assertTrue(healthFactor > 1e6 && healthFactor < 1.3e6);
    }

    function test_Revert_Repay_Branch1() public {
        assertEq(LendefiInstance.paused(), false);
        vm.prank(guardian);
        LendefiInstance.pause();
        assertEq(LendefiInstance.paused(), true);
        bytes memory expError = abi.encodeWithSignature("EnforcedPause()");

        vm.prank(bob);
        vm.expectRevert(expError); // contract paused
        LendefiInstance.repay(10_000e6);
    }

    function test_Revert_Repay_Branch2() public {
        vm.prank(bob);
        vm.expectRevert("ERR_NO_EXISTING_LOAN"); // contract paused
        LendefiInstance.repay(10_000e6);
    }

    function test_Revert_Repay_Branch3() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 10 ether);
        supplyCollateral(bob, 10 ether);
        borrow(bob, 10_000e6);
        vm.warp(367 days);
        vm.roll(367 days);
        uint256 amount = LendefiInstance.getAccruedDebt(bob);
        vm.startPrank(bob);
        usdcInstance.approve(address(LendefiInstance), amount);
        bytes memory expError =
            abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", bob, 10_000e6, amount);
        // ERC20InsufficientBalance(0x0000000000000000000000000000000009999992, 10000000000 [1e10], 10003288212 [1e10])
        vm.expectRevert(expError);
        LendefiInstance.repay(11_000e6);
    }

    function test_Repay() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 10 ether);
        supplyCollateral(bob, 10 ether);
        borrow(bob, 10_000e6);
        uint256 principal = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principal == 10_000e6);
        vm.warp(367 days);
        vm.roll(367 days);
        usdcInstance.drip(bob);
        uint256 amount = LendefiInstance.getAccruedDebt(bob);
        vm.startPrank(bob);
        usdcInstance.approve(address(LendefiInstance), amount);
        LendefiInstance.repay(amount);
        uint256 principalAfter = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principalAfter == 0);
    }

    function test_RepayTwice() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 10 ether);
        supplyCollateral(bob, 10 ether);
        borrow(bob, 10_000e6);
        uint256 principal = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principal == 10_000e6);
        vm.warp(367 days);
        vm.roll(367 days);
        usdcInstance.drip(bob);
        uint256 amount = LendefiInstance.getAccruedDebt(bob);
        vm.startPrank(bob);
        usdcInstance.approve(address(LendefiInstance), amount);

        LendefiInstance.repay(amount / 2);
        uint256 principalAfter = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principalAfter == amount / 2);
        vm.warp(368 days);
        vm.roll(368 days);

        uint256 amount2 = LendefiInstance.getAccruedDebt(bob);
        usdcInstance.approve(address(LendefiInstance), amount2);

        LendefiInstance.repay(amount2);
        uint256 principalAfter2 = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principalAfter2 == 0);
        uint256 totalBorrow = LendefiInstance.totalBorrow();
        assertEq(totalBorrow, 0);
    }

    function test_RepayMax() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 10 ether);
        supplyCollateral(bob, 10 ether);
        borrow(bob, 10_000e6);
        uint256 principal = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principal == 10_000e6);
        vm.warp(367 days);
        vm.roll(367 days);
        usdcInstance.drip(bob);
        uint256 amount = LendefiInstance.getAccruedDebt(bob);
        vm.startPrank(bob);
        usdcInstance.approve(address(LendefiInstance), amount);
        LendefiInstance.repayMax();
        uint256 principalAfter = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principalAfter == 0);
    }

    function test_Revert_RepayMax_Branch1() public {
        assertEq(LendefiInstance.paused(), false);
        vm.prank(guardian);
        LendefiInstance.pause();
        assertEq(LendefiInstance.paused(), true);
        bytes memory expError = abi.encodeWithSignature("EnforcedPause()");

        vm.prank(bob);
        vm.expectRevert(expError); // contract paused
        LendefiInstance.repayMax();
    }

    function test_Revert_RepayMax_Branch2() public {
        vm.prank(bob);
        vm.expectRevert("ERR_NO_EXISTING_LOAN"); // contract paused
        LendefiInstance.repayMax();
    }

    function test_Revert_RepayMax_Branch3() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 10 ether);
        supplyCollateral(bob, 10 ether);
        borrow(bob, 10_000e6);
        vm.warp(367 days);
        vm.roll(367 days);
        uint256 amount = LendefiInstance.getAccruedDebt(bob);
        bytes memory expError =
            abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", bob, 10_000e6, amount);
        vm.startPrank(bob);
        usdcInstance.approve(address(LendefiInstance), amount);
        vm.expectRevert(expError);
        LendefiInstance.repayMax();
        vm.stopPrank();
    }

    function test_ExitAll() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 10 ether);
        supplyCollateral(bob, 10 ether);
        borrow(bob, 10_000e6);
        uint256 principal = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principal == 10_000e6);
        vm.warp(367 days);
        vm.roll(367 days);
        usdcInstance.drip(bob);
        uint256 amount = LendefiInstance.getAccruedDebt(bob);
        vm.startPrank(bob);
        usdcInstance.approve(address(LendefiInstance), amount);
        LendefiInstance.exitAll();
        uint256 principalAfter = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principalAfter == 0);
    }

    function test_Exchange() public {
        listAsset(address(wethInstance), address(oracleInstance));
        supplyLiquidity(alice, 100_000e6);
        vm.deal(bob, 50 ether);
        supplyCollateral(bob, 50 ether);
        borrow(bob, 50_000e6);
        uint256 principal = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principal == 50_000e6);
        vm.warp(730 days);
        vm.roll(730 days);
        usdcInstance.drip(bob);
        uint256 amount = LendefiInstance.getAccruedDebt(bob);
        vm.startPrank(bob);
        usdcInstance.approve(address(LendefiInstance), amount);
        LendefiInstance.repay(amount);
        uint256 principalAfter = LendefiInstance.getLoanPrincipal(bob);
        assertTrue(principalAfter == 0);
        uint256 totalBorrow = LendefiInstance.totalBorrow();
        assertEq(totalBorrow, 0);
        vm.stopPrank();

        uint256 supplyRate = LendefiInstance.getSupplyRate();
        vm.prank(alice);
        LendefiInstance.exchange(100_000e6);

        uint256 balanceAfter = usdcInstance.balanceOf(alice);
        uint256 expBal = 100_000e6 + (100_000e6 * supplyRate) / 1e6;
        assertEq(balanceAfter / 1e6, expBal / 1e6);
    }

    function supplyLiquidity(address src, uint256 amount) internal {
        usdcInstance.mint(src, amount);
        vm.startPrank(src);
        usdcInstance.approve(address(LendefiInstance), amount);
        LendefiInstance.supplyLiquidity(amount);
        vm.stopPrank();
        assertEq(usdcInstance.balanceOf(address(LendefiInstance)), amount);
        assertEq(LendefiInstance.totalBase(), amount);
        assertEq(LendefiInstance.balanceOf(src), amount);
    }

    function supplyCollateral(address src, uint256 amount) internal {
        vm.startPrank(src);
        (bool success,) = payable(address(wethInstance)).call{value: amount}("");
        require(success, "ERR_ETH_TRANSFER_FAILED");
        assertEq(wethInstance.balanceOf(src), amount);
        wethInstance.approve(address(LendefiInstance), amount);
        LendefiInstance.supplyCollateral(address(wethInstance), amount);
        vm.stopPrank();

        assertEq(LendefiInstance.getCollateral(src, address(wethInstance)), amount);
        assertEq(LendefiInstance.getTotalCollateral(address(wethInstance)), amount);
    }

    function borrow(address src, uint256 amount) internal {
        vm.prank(src);
        vm.expectEmit();
        emit Borrow(src, amount);
        LendefiInstance.borrow(amount);
    }

    function listAsset(address asset, address oracle) internal {
        assertTrue(LendefiInstance.isListed(asset) == false);
        vm.prank(address(timelockInstance));
        LendefiInstance.updateCollateralConfig(asset, oracle, 8, 18, 1, 870, 920, 10_000 ether);
        assertTrue(LendefiInstance.isListed(address(wethInstance)) == true);
    }
}
