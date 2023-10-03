// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest} from "./BaseTest.sol";
import {Deployable, ICometConfigurator, ICometProxyAdmin} from "../src/vendor/ICometConfigurator.sol";
import "forge-std/console.sol";

contract RewardsTest is BaseTest {
    address constant configuratorAddress = 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3;
    address constant proxyAdminAddress = 0x1EC63B5883C3481134FD50D5DAebc83Ecd2E8779;

    function test_getRewardOwed(uint256 aliceAmount, uint256 bobAmount) public {
        /* ===== Setup ===== */

        vm.assume(aliceAmount <= 2**48);
        vm.assume(bobAmount <= 2**48);
        vm.assume(aliceAmount + bobAmount < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin
        vm.assume(aliceAmount >= 2e6 && bobAmount >= 2e6);

        enableRewardsAccrual();

        // Alice and Bob have same amount of funds in both CometWrapper and Comet
        vm.startPrank(cusdcHolder);
        comet.transfer(alice, aliceAmount);
        comet.transfer(bob, bobAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(aliceAmount / 2, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(bobAmount / 2, bob);
        vm.stopPrank();

        /* ===== Start test ===== */

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        // Rewards accrual will not be applied retroactively
        assertEq(cometWrapper.getRewardOwed(alice), 0);
        assertEq(cometWrapper.getRewardOwed(alice), cometRewards.getRewardOwed(cometAddress, alice).owed);

        skip(7 days);

        // Rewards accrual in CometWrapper matches rewards accrual in Comet
        assertGt(cometWrapper.getRewardOwed(alice), 0);
        assertEq(cometWrapper.getRewardOwed(alice), cometRewards.getRewardOwed(cometAddress, alice).owed);

        assertGt(cometWrapper.getRewardOwed(bob), 0);
        assertEq(cometWrapper.getRewardOwed(bob), cometRewards.getRewardOwed(cometAddress, bob).owed);

        // The wrapper should always be owed the same or more rewards from Comet
        // than the sum of rewards owed to its depositors
        assertGe(
            cometRewards.getRewardOwed(cometAddress, wrapperAddress).owed,
            cometWrapper.getRewardOwed(bob) + cometWrapper.getRewardOwed(alice)
        );
    }

    function test_claimTo(uint256 aliceAmount, uint256 bobAmount) public {
        /* ===== Setup ===== */

        vm.assume(aliceAmount <= 2**48);
        vm.assume(bobAmount <= 2**48);
        vm.assume(aliceAmount + bobAmount < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin
        vm.assume(aliceAmount >= 2e6 && bobAmount >= 2e6);

        enableRewardsAccrual();
        // Make sure CometRewards has ample COMP to claim
        deal(address(comp), address(cometRewards), 10_000_000 ether);

        // Make amount an even number so it can be divided equally by 2
        if (aliceAmount % 2 != 0) aliceAmount -= 1;
        if (bobAmount % 2 != 0) bobAmount -= 1;

        vm.startPrank(cusdcHolder);
        comet.transfer(alice, aliceAmount);
        comet.transfer(bob, bobAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(aliceAmount / 2, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(bobAmount / 2, bob);
        vm.stopPrank();

        // Make sure that Alice and Bob have the same amount of shares in Comet and the CometWrapper
        // We do this because `comet.transfer` can burn 1 extra principal from the sender
        uint256 diffInShares = cometWrapper.balanceOf(alice) - uint256(int256(comet.userBasic(alice).principal));
        if (diffInShares > 0) {
            vm.prank(alice);
            cometWrapper.redeem(diffInShares, address(0), alice);
        }
        diffInShares = cometWrapper.balanceOf(bob) - uint256(int256(comet.userBasic(bob).principal));
        if (diffInShares > 0) {
            vm.prank(bob);
            cometWrapper.redeem(diffInShares, address(0), bob);
        }

        /* ===== Start test ===== */

        skip(30 days);

        // Accrued rewards in CometWrapper matches accrued rewards in Comet
        uint256 rewardsFromComet;
        uint256 wrapperRewards;
        vm.startPrank(alice);
        cometRewards.claim(cometAddress, alice, true);
        rewardsFromComet = comp.balanceOf(alice);
        cometWrapper.claimTo(alice);
        wrapperRewards = comp.balanceOf(alice) - rewardsFromComet;
        vm.stopPrank();

        assertEq(wrapperRewards, rewardsFromComet);

        skip(2188 days);

        vm.startPrank(bob);
        cometRewards.claim(cometAddress, bob, true);
        rewardsFromComet = comp.balanceOf(bob);
        cometWrapper.claimTo(bob);
        wrapperRewards = comp.balanceOf(bob) - rewardsFromComet;
        vm.stopPrank();

        assertEq(wrapperRewards, rewardsFromComet);
    }

    function test_accrueRewards(uint256 aliceAmount) public {
        /* ===== Setup ===== */

        vm.assume(aliceAmount <= 2**48);
        vm.assume(aliceAmount < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin
        vm.assume(aliceAmount >= 2e6);

        enableRewardsAccrual();

        // Make amount an even number so it can be divided equally by 2
        if (aliceAmount % 2 != 0) aliceAmount -= 1;

        vm.startPrank(cusdcHolder);
        comet.transfer(alice, aliceAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(aliceAmount / 2, alice);
        vm.stopPrank();

        // Make sure that Alice has the same amount of shares in Comet and the CometWrapper
        // We do this because `comet.transfer` can burn 1 extra principal from the sender
        uint256 diffInShares = cometWrapper.balanceOf(alice) - uint256(int256(comet.userBasic(alice).principal));
        if (diffInShares > 0) {
            vm.prank(alice);
            cometWrapper.redeem(diffInShares, address(0), alice);
        }

        /* ===== Start test ===== */

        skip(30 days);
        (uint64 baseTrackingAccrued,) = cometWrapper.userBasic(alice);
        assertEq(baseTrackingAccrued, 0);

        cometWrapper.accrueRewards(alice);
        (baseTrackingAccrued,) = cometWrapper.userBasic(alice);
        assertGt(baseTrackingAccrued, 0);
        assertEq(baseTrackingAccrued, comet.baseTrackingAccrued(address(cometWrapper)));
    }

    // Tests that previously accrued rewards persist even after a user's Comet Wrapper balance changes
    function test_accrueRewardsBeforeBalanceChanges() public {
        enableRewardsAccrual();
        uint256 snapshot = vm.snapshot();

        setupAliceBalance();
        skip(30 days);
        vm.prank(alice);
        cometWrapper.transfer(bob, 5_000e6);

        // Alice should have 30 days worth of accrued rewards for her 10K WcUSDC
        assertEq(cometWrapper.getRewardOwed(alice), cometRewards.getRewardOwed(cometAddress, alice).owed);
        // Bob should have no rewards accrued yet since his balance prior to the transfer was 0
        assertEq(cometWrapper.getRewardOwed(bob), 0);

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        setupAliceBalance();
        skip(30 days);
        vm.prank(alice);
        cometWrapper.redeem(5_000e6, alice, alice);

        // Alice should have 30 days worth of accrued rewards for her 10K WcUSDC and not for 5K WcUSDC
        assertEq(cometWrapper.getRewardOwed(alice), cometRewards.getRewardOwed(cometAddress, alice).owed);

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        setupAliceBalance();
        skip(30 days);
        vm.prank(alice);
        cometWrapper.withdraw(5_000e6, alice, alice);

        // Alice should have 30 days worth of accrued rewards for her 10K WcUSDC and not for 5K WcUSDC
        assertEq(cometWrapper.getRewardOwed(alice), cometRewards.getRewardOwed(cometAddress, alice).owed);

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        setupAliceBalance();
        skip(30 days);
        vm.prank(alice);
        cometWrapper.mint(5_000e6, alice);

        // Alice should have 30 days worth of accrued rewards for her 10K WcUSDC and not for 5K WcUSDC
        assertEq(cometWrapper.getRewardOwed(alice), cometRewards.getRewardOwed(cometAddress, alice).owed);

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        setupAliceBalance();
        skip(30 days);
        vm.prank(alice);
        cometWrapper.deposit(5_000e6, alice);

        // Alice should have 30 days worth of accrued rewards for her 10K WcUSDC and not for 5K WcUSDC
        assertEq(cometWrapper.getRewardOwed(alice), cometRewards.getRewardOwed(cometAddress, alice).owed);
    }

    function setupAliceBalance() internal {
        vm.prank(cusdcHolder);
        comet.transfer(alice, 20_000e6);
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(10_000e6, alice);
        vm.stopPrank();
    }

    function enableRewardsAccrual() internal {
        address governor = comet.governor();
        ICometConfigurator configurator = ICometConfigurator(configuratorAddress);
        ICometProxyAdmin proxyAdmin = ICometProxyAdmin(proxyAdminAddress);

        vm.startPrank(governor);
        configurator.setBaseTrackingSupplySpeed(cometAddress, 2e14); // 0.2 COMP/second
        proxyAdmin.deployAndUpgradeTo(Deployable(configuratorAddress), cometAddress);
        vm.stopPrank();
    }
}

// TODO: test cWETHv3
// TODO: test L2 reward contracts that use multipliers
// TODO: claimTo on behalf of someone else
// TODO: multiple reward contracts?