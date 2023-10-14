// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { CoreTest, CometHelpers, CometWrapper, ERC20, ICometRewards } from "./CoreTest.sol";

abstract contract EncumberTest is CoreTest {
    event Encumber(address indexed owner, address indexed taker, uint amount);
    event Release(address indexed owner, address indexed taker, uint amount);

    function setUpAliceCometBalance() public {
        deal(address(underlyingToken), address(cometHolder), 20_000 * decimalScale);
        vm.startPrank(cometHolder);
        underlyingToken.approve(address(comet), 20_000 * decimalScale);
        comet.supply(address(underlyingToken), 20_000 * decimalScale);

        comet.transfer(alice, 10_000 * decimalScale);
        assertGt(comet.balanceOf(alice), 9999 * decimalScale);
        vm.stopPrank();
    }

    function test_availableBalanceOf() public {
        vm.startPrank(alice);

        // availableBalanceOf is 0 by default
        assertEq(cometWrapper.availableBalanceOf(alice), 0);

        // reflects balance when there are no encumbrances
        deal(address(cometWrapper), alice, 100e18);
        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 100e18);

        // is reduced by encumbrances
        cometWrapper.encumber(bob, 20e18);
        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 80e18);

        // is reduced by transfers
        cometWrapper.transfer(bob, 20e18);
        assertEq(cometWrapper.balanceOf(alice), 80e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 60e18);

        vm.stopPrank();

        vm.startPrank(bob);

        // is NOT reduced by transferFrom (from an encumbered address)
        cometWrapper.transferFrom(alice, charlie, 10e18);
        assertEq(cometWrapper.balanceOf(alice), 70e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 60e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 10e18);
        assertEq(cometWrapper.balanceOf(charlie), 10e18);

        // is increased by a release
        cometWrapper.release(alice, 5e18);
        assertEq(cometWrapper.balanceOf(alice), 70e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 65e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 5e18);

        vm.stopPrank();
    }

    function test_transfer_revertsOnInsufficentAvailableBalance() public {
        deal(address(cometWrapper), alice, 100e18);
        vm.startPrank(alice);

        // alice encumbers half her balance to bob
        cometWrapper.encumber(bob, 50e18);

        // alice attempts to transfer her entire balance
        vm.expectRevert(CometWrapper.InsufficientAvailableBalance.selector);
        cometWrapper.transfer(charlie, 100e18);

        vm.stopPrank();
    }

    function test_encumber_revertsOnInsufficientAvailableBalance() public {
        deal(address(cometWrapper), alice, 100e18);
        vm.startPrank(alice);

        // alice encumbers half her balance to bob
        cometWrapper.encumber(bob, 50e18);

        // alice attempts to encumber more than her remaining available balance
        vm.expectRevert(CometWrapper.InsufficientAvailableBalance.selector);
        cometWrapper.encumber(charlie, 60e18);

        vm.stopPrank();
    }

    function test_encumber() public {
        deal(address(cometWrapper), alice, 100e18);
        vm.startPrank(alice);

        // emits Encumber event
        vm.expectEmit(true, true, true, true);
        emit Encumber(alice, bob, 60e18);

        // alice encumbers some of her balance to bob
        cometWrapper.encumber(bob, 60e18);

        // balance is unchanged
        assertEq(cometWrapper.balanceOf(alice), 100e18);
        // available balance is reduced
        assertEq(cometWrapper.availableBalanceOf(alice), 40e18);

        // creates encumbrance for taker
        assertEq(cometWrapper.encumbrances(alice, bob), 60e18);

        // updates encumbered balance of owner
        assertEq(cometWrapper.encumberedBalanceOf(alice), 60e18);
    }

    function test_transferFromWithSufficientEncumbrance() public {
        deal(address(cometWrapper), alice, 100e18);
        vm.prank(alice);

        // alice encumbers some of her balance to bob
        cometWrapper.encumber(bob, 60e18);

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 40e18);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 60e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 60e18);
        assertEq(cometWrapper.balanceOf(charlie), 0);

        // bob calls transfers from alice to charlie
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Release(alice, bob, 40e18);
        cometWrapper.transferFrom(alice, charlie, 40e18);

        // alice balance is reduced
        assertEq(cometWrapper.balanceOf(alice), 60e18);
        // alice encumbrance to bob is reduced
        assertEq(cometWrapper.availableBalanceOf(alice), 40e18);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 20e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 20e18);
        // transfer is completed
        assertEq(cometWrapper.balanceOf(charlie), 40e18);
    }

    function test_transferFromUsesEncumbranceAndAllowance() public {
        deal(address(cometWrapper), alice, 100e18);
        vm.startPrank(alice);

        // alice encumbers some of her balance to bob
        cometWrapper.encumber(bob, 20e18);

        // she also grants him an approval
        cometWrapper.approve(bob, 30e18);

        vm.stopPrank();

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 80e18);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 20e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 20e18);
        assertEq(cometWrapper.allowance(alice, bob), 30e18);
        assertEq(cometWrapper.balanceOf(charlie), 0);

        // bob calls transfers from alice to charlie
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Release(alice, bob, 20e18);
        cometWrapper.transferFrom(alice, charlie, 40e18);

        // alice balance is reduced
        assertEq(cometWrapper.balanceOf(alice), 60e18);

        // her encumbrance to bob has been fully spent
        assertEq(cometWrapper.availableBalanceOf(alice), 60e18);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // her allowance to bob has been partially spent
        assertEq(cometWrapper.allowance(alice, bob), 10e18);

        // the dst receives the transfer
        assertEq(cometWrapper.balanceOf(charlie), 40e18);
    }

    function test_transferFrom_revertsIfSpendingTokensEncumberedToOthers() public {
        deal(address(cometWrapper), alice, 200e18);
        vm.startPrank(alice);

        // alice encumbers some of her balance to bob
        cometWrapper.encumber(bob, 50e18);

        // she also grants him an approval
        cometWrapper.approve(bob, type(uint256).max);

        // alice encumbers the remainder of her balance to charlie
        cometWrapper.encumber(charlie, 150e18);

        vm.stopPrank();

        assertEq(cometWrapper.balanceOf(alice), 200e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 0);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 200e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 50e18);
        assertEq(cometWrapper.encumbrances(alice, charlie), 150e18);
        assertEq(cometWrapper.allowance(alice, bob), type(uint256).max);

        // bob calls transfers from alice, attempting to transfer his encumbered
        // tokens and also transfer tokens encumbered to charlie
        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAvailableBalance.selector);
        cometWrapper.transferFrom(alice, bob, 100e18);
    }

    function test_transferFrom_revertsIfInsufficientAllowance() public {
        deal(address(cometWrapper), alice, 100e18);

        vm.startPrank(alice);

        // alice encumbers some of her balance to bob
        cometWrapper.encumber(bob, 10e18);

        // she also grants him an approval
        cometWrapper.approve(bob, 20e18);

        vm.stopPrank();

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 90e18);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 10e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 10e18);
        assertEq(cometWrapper.allowance(alice, bob), 20e18);
        assertEq(cometWrapper.balanceOf(charlie), 0);

        // bob tries to transfer more than his encumbered and allowed balances
        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, charlie, 40e18);
    }

    function test_encumberFrom_revertsOnInsufficientAllowance() public {
        deal(address(cometWrapper), alice, 100e18);

        // alice grants bob an approval
        vm.prank(alice);
        cometWrapper.approve(bob, 50e18);

        // but bob tries to encumber more than his allowance
        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.encumberFrom(alice, charlie, 60e18);
    }

    function test_encumberFrom() public {
        deal(address(cometWrapper), alice, 100e18);

        // alice grants bob an approval
        vm.prank(alice);
        cometWrapper.approve(bob, 100e18);

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 100e18);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 0e18);
        assertEq(cometWrapper.allowance(alice, bob), 100e18);
        assertEq(cometWrapper.balanceOf(charlie), 0);

        // bob encumbers part of his allowance from alice to charlie
        vm.prank(bob);
        // emits an Encumber event
        vm.expectEmit(true, true, true, true);
        emit Encumber(alice, charlie, 60e18);
        cometWrapper.encumberFrom(alice, charlie, 60e18);

        // no balance is transferred
        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.balanceOf(charlie), 0);
        // but available balance is reduced
        assertEq(cometWrapper.availableBalanceOf(alice), 40e18);
        // encumbrance to charlie is created
        assertEq(cometWrapper.encumberedBalanceOf(alice), 60e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 0e18);
        assertEq(cometWrapper.encumbrances(alice, charlie), 60e18);
        // allowance is partially spent
        assertEq(cometWrapper.allowance(alice, bob), 40e18);
    }

    function test_release() public {
        deal(address(cometWrapper), alice, 100e18);

        vm.prank(alice);

        // alice encumbers her balance to bob
        cometWrapper.encumber(bob, 100e18);

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 0);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 100e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 100e18);

        // bob releases part of the encumbrance
        vm.prank(bob);
        // emits Release event
        vm.expectEmit(true, true, true, true);
        emit Release(alice, bob, 40e18);
        cometWrapper.release(alice, 40e18);

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 40e18);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 60e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 60e18);
    }

    function test_release_revertsOnInsufficientEncumbrance() public {
        deal(address(cometWrapper), alice, 100e18);

        vm.prank(alice);

        // alice encumbers her balance to bob
        cometWrapper.encumber(bob, 100e18);

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 0);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 100e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 100e18);

        // bob releases a greater amount than is encumbered to him
        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientEncumbrance.selector);
        cometWrapper.release(alice, 200e18);

        assertEq(cometWrapper.balanceOf(alice), 100e18);
        assertEq(cometWrapper.availableBalanceOf(alice), 0);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 100e18);
        assertEq(cometWrapper.encumbrances(alice, bob), 100e18);
    }

    /* ===== ERC4626 + Encumbrance Tests ===== */

    function test_withdrawFromUsesOnlyEncumbrance() public {
        setUpAliceCometBalance();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        uint256 sharesToEncumber = 2_700 * decimalScale;
        uint256 sharesToRedeem = 2_500 * decimalScale;
        uint256 assetsToWithdraw = cometWrapper.previewRedeem(sharesToRedeem);

        vm.prank(alice);
        cometWrapper.encumber(bob, sharesToEncumber);

        vm.startPrank(bob);
        // Encumbrance should be updated when withdraw is done
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber - sharesToRedeem);
        assertEq(cometWrapper.balanceOf(alice), 5_000 * decimalScale - sharesToRedeem);

        // Reverts if trying to withdraw again now that encumbrance is used up
        assetsToWithdraw = cometWrapper.previewRedeem(sharesToRedeem);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        vm.stopPrank();
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber - sharesToRedeem);
    }

    function test_withdrawFromUsesEncumbranceAndAllowance() public {
        setUpAliceCometBalance();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        uint256 sharesToEncumber = 1_000 * decimalScale;
        uint256 sharesToApprove = 1_700 * decimalScale;
        uint256 sharesToRedeem = 2_500 * decimalScale;
        uint256 assetsToWithdraw = cometWrapper.previewRedeem(sharesToRedeem);

        vm.startPrank(alice);
        cometWrapper.encumber(bob, sharesToEncumber);
        cometWrapper.approve(bob, sharesToApprove);
        vm.stopPrank();

        vm.startPrank(bob);
        // Encumbrance and allowance should be updated when withdraw is done
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber);
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);
        assertEq(cometWrapper.allowance(alice, bob), sharesToEncumber + sharesToApprove - sharesToRedeem);
        assertEq(cometWrapper.balanceOf(alice), 5_000 * decimalScale - sharesToRedeem);

        // Reverts if trying to withdraw again now that encumbrance and allowance is used up
        assetsToWithdraw = cometWrapper.previewRedeem(sharesToRedeem);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        vm.stopPrank();
        assertEq(cometWrapper.encumbrances(alice, bob), 0);
        assertEq(cometWrapper.allowance(alice, bob), sharesToEncumber + sharesToApprove - sharesToRedeem);
    }

    function test_withdrawFrom_revertsOnInsufficientAvailableBalance() public {
        setUpAliceCometBalance();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(1_000 * decimalScale, alice);
        // Encumber to Charlie so Alice's available balance is only 100
        cometWrapper.encumber(charlie, 900 * decimalScale);
        cometWrapper.approve(bob, 200 * decimalScale);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAvailableBalance.selector);
        cometWrapper.withdraw(200 * decimalScale, bob, alice);
    }

    function test_redeemFromUsesOnlyEncumbrance() public {
        setUpAliceCometBalance();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        uint256 sharesToEncumber = 2_700 * decimalScale;
        uint256 sharesToRedeem = 2_500 * decimalScale;

        vm.prank(alice);
        cometWrapper.encumber(bob, sharesToEncumber);

        vm.startPrank(bob);
        // Encumbrances should be updated when redeem is done
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber);
        cometWrapper.redeem(sharesToRedeem, bob, alice);
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber - sharesToRedeem);
        assertEq(cometWrapper.balanceOf(alice), 5_000 * decimalScale - sharesToRedeem);

        // Reverts if trying to redeem again now that encumbrance is used up
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.redeem(sharesToRedeem, bob, alice);
        vm.stopPrank();
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber - sharesToRedeem);
    }

    function test_redeemFromUsesEncumbranceAndAllowance() public {
        setUpAliceCometBalance();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        uint256 sharesToEncumber = 1_000 * decimalScale;
        uint256 sharesToApprove = 1_700 * decimalScale;
        uint256 sharesToRedeem = 2_500 * decimalScale;

        vm.startPrank(alice);
        cometWrapper.encumber(bob, sharesToEncumber);
        cometWrapper.approve(bob, sharesToApprove);
        vm.stopPrank();

        vm.startPrank(bob);
        // Encumbrances and allowances should be updated when redeem is done
        assertEq(cometWrapper.encumbrances(alice, bob), sharesToEncumber);
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove);
        cometWrapper.redeem(sharesToRedeem, bob, alice);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);
        assertEq(cometWrapper.allowance(alice, bob), sharesToEncumber + sharesToApprove - sharesToRedeem);
        assertEq(cometWrapper.balanceOf(alice), 5_000 * decimalScale - sharesToRedeem);

        // Reverts if trying to redeem again now that encumbrance and allowance is used up
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.redeem(sharesToRedeem, bob, alice);
        vm.stopPrank();
        assertEq(cometWrapper.encumbrances(alice, bob), 0);
        assertEq(cometWrapper.allowance(alice, bob), sharesToEncumber + sharesToApprove - sharesToRedeem);
    }

    function test_redeemFrom_revertsOnInsufficientAvailableBalance() public {
        setUpAliceCometBalance();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(1_000 * decimalScale, alice);
        // Encumber to Charlie so Alice's available balance is only 100
        cometWrapper.encumber(charlie, 900 * decimalScale);
        cometWrapper.approve(bob, 200 * decimalScale);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAvailableBalance.selector);
        cometWrapper.redeem(200 * decimalScale, bob, alice);
    }
}
