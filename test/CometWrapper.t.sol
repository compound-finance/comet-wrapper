// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest, CometHelpers, CometWrapper, ERC20, ICometRewards} from "./BaseTest.sol";
import {CometMath} from "../src/vendor/CometMath.sol";

contract CometWrapperTest is BaseTest, CometMath {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function setUp() public override {
        super.setUp();

        vm.prank(cusdcHolder);
        comet.transfer(alice, 10_000e6);
        assertGt(comet.balanceOf(alice), 9999e6);

        vm.prank(cusdcHolder);
        comet.transfer(bob, 10_000e6);
        assertGt(comet.balanceOf(bob), 9999e6);
    }

    function test_constructor() public {
        assertEq(cometWrapper.trackingIndexScale(), comet.trackingIndexScale());
        assertEq(address(cometWrapper.comet()), address(comet));
        assertEq(address(cometWrapper.cometRewards()), address(cometRewards));
        assertEq(address(cometWrapper.asset()), address(comet));
        assertEq(cometWrapper.decimals(), comet.decimals());
        assertEq(cometWrapper.name(), "Wrapped Comet USDC");
        assertEq(cometWrapper.symbol(), "WcUSDCv3");
        assertEq(cometWrapper.totalSupply(), 0);
        assertEq(cometWrapper.totalAssets(), 0);
    }

    function test_constructorRevertsOnInvalidComet() public {
        // reverts on zero address
        vm.expectRevert();
        new CometWrapper(ERC20(address(0)), cometRewards, "Name", "Symbol");

        // reverts on non-zero address that isn't ERC20 and Comet
        vm.expectRevert();
        new CometWrapper(ERC20(address(1)), cometRewards, "Name", "Symbol");

        // reverts on ERC20-only contract
        vm.expectRevert();
        new CometWrapper(usdc, cometRewards, "Name", "Symbol");
    }

    function test_constructorRevertsOnInvalidCometRewards() public {
        // reverts on zero address
        vm.expectRevert(CometHelpers.ZeroAddress.selector);
        new CometWrapper(ERC20(address(comet)), ICometRewards(address(0)), "Name", "Symbol");

        // reverts on non-zero address that isn't CometRewards
        vm.expectRevert();
        new CometWrapper(ERC20(address(comet)), ICometRewards(address(1)), "Name", "Symbol");
    }

    function test_totalAssets() public {
        assertEq(cometWrapper.totalAssets(), 0);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000e6, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
    }

    function test_underlyingBalance() public {
        assertEq(cometWrapper.underlyingBalance(alice), 0);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000e6, alice);
        vm.stopPrank();

        assertApproxEqAbs(cometWrapper.underlyingBalance(alice), 5_000e6, 1);
        skip(14 days);
        assertGe(cometWrapper.underlyingBalance(alice), 5_000e6);
    }

    function test_previewDeposit() public {
        assertEq(cometWrapper.balanceOf(alice), 0e6);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 alicePreviewedSharesReceived = cometWrapper.previewDeposit(5_000e6);
        uint256 aliceSharesFromAssets = cometWrapper.convertToShares(5_000e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualSharesReceived = cometWrapper.deposit(5_000e6, alice);
        vm.stopPrank();

        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance - 5_000e6, 1);
        assertEq(cometWrapper.balanceOf(alice), alicePreviewedSharesReceived);
        assertEq(alicePreviewedSharesReceived, aliceActualSharesReceived);
        assertEq(alicePreviewedSharesReceived, aliceSharesFromAssets);

        assertEq(cometWrapper.balanceOf(bob), 0e6);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobPreviewedSharesReceived = cometWrapper.previewDeposit(5_000e6);
        uint256 bobSharesFromAssets = cometWrapper.convertToShares(5_000e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualSharesReceived = cometWrapper.deposit(5_000e6, bob);
        vm.stopPrank();

        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance - 5_000e6, 1);
        // TODO: investigate rounding
        assertApproxEqAbs(cometWrapper.balanceOf(bob), bobPreviewedSharesReceived, 1);
        assertApproxEqAbs(bobPreviewedSharesReceived, bobActualSharesReceived, 1);
        assertGe(bobPreviewedSharesReceived, bobActualSharesReceived);
        assertEq(bobPreviewedSharesReceived, bobSharesFromAssets);
    }

    function test_previewMint() public {
        assertEq(cometWrapper.balanceOf(alice), 0e6);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 alicePreviewedAssetsUsed = cometWrapper.previewMint(5_000e6);
        uint256 aliceAssetsFromShares = cometWrapper.convertToAssets(5_000e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualAssetsUsed = cometWrapper.mint(5_000e6, alice);
        vm.stopPrank();

        // TODO: investigate rounding
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance - alicePreviewedAssetsUsed, 1);
        assertEq(alicePreviewedAssetsUsed, aliceActualAssetsUsed);
        assertEq(alicePreviewedAssetsUsed, aliceAssetsFromShares);
        assertApproxEqAbs(cometWrapper.balanceOf(alice), 5_000e6, 1);

        assertEq(cometWrapper.balanceOf(bob), 0e6);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobPreviewedAssetsUsed = cometWrapper.previewMint(5_000e6);
        uint256 bobAssetsFromShares = cometWrapper.convertToAssets(5_000e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualAssetsUsed = cometWrapper.mint(5_000e6, bob);
        vm.stopPrank();

        // TODO: investigate rounding
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance - bobPreviewedAssetsUsed, 1);
        assertEq(bobPreviewedAssetsUsed, bobActualAssetsUsed);
        assertEq(bobPreviewedAssetsUsed, bobAssetsFromShares);
        // TODO: rounded down by 2 instead of 1
        assertApproxEqAbs(cometWrapper.balanceOf(bob), 5_000e6, 2);
    }

    function test_previewWithdraw() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000e6, bob);
        vm.stopPrank();

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 aliceWrapperBalance = cometWrapper.balanceOf(alice);
        uint256 alicePreviewedSharesUsed = cometWrapper.previewWithdraw(2_500e6);
        uint256 aliceSharesFromAssets = cometWrapper.convertToShares(2_500e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualSharesUsed = cometWrapper.withdraw(2_500e6, alice, alice);
        vm.stopPrank();

        // TODO: investigate rounding
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + 2_500e6, 1);
        assertApproxEqAbs(cometWrapper.balanceOf(alice), aliceWrapperBalance - alicePreviewedSharesUsed, 1);
        assertApproxEqAbs(alicePreviewedSharesUsed, aliceActualSharesUsed, 1);
        assertLe(alicePreviewedSharesUsed, aliceActualSharesUsed);
        assertEq(alicePreviewedSharesUsed, aliceSharesFromAssets);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 bobPreviewedSharesUsed = cometWrapper.previewWithdraw(2_500e6);
        uint256 bobSharesFromAssets = cometWrapper.convertToShares(2_500e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualSharesUsed = cometWrapper.withdraw(2_500e6, bob, bob);
        vm.stopPrank();

        // TODO: investigate rounding
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + 2_500e6, 1);
        assertApproxEqAbs(cometWrapper.balanceOf(bob), bobWrapperBalance - bobPreviewedSharesUsed, 1);
        assertApproxEqAbs(bobPreviewedSharesUsed, bobActualSharesUsed, 1);
        assertLe(bobPreviewedSharesUsed, bobActualSharesUsed);
        assertEq(bobPreviewedSharesUsed, bobSharesFromAssets);
    }

    function test_previewRedeem() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, bob);
        vm.stopPrank();

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 aliceWrapperBalance = cometWrapper.balanceOf(alice);
        uint256 alicePreviewedAssetsReceived = cometWrapper.previewRedeem(2_500e6);
        uint256 aliceAssetsFromShares = cometWrapper.convertToAssets(2_500e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualAssetsReceived = cometWrapper.redeem(2_500e6, alice, alice);
        vm.stopPrank();

        // TODO: investigate rounding
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + alicePreviewedAssetsReceived, 2);
        assertApproxEqAbs(cometWrapper.balanceOf(alice), aliceWrapperBalance - 2_500e6, 1);
        assertApproxEqAbs(alicePreviewedAssetsReceived, aliceActualAssetsReceived, 1);
        assertGe(alicePreviewedAssetsReceived, aliceActualAssetsReceived);
        assertEq(alicePreviewedAssetsReceived, aliceAssetsFromShares);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 bobPreviewedAssetsReceived = cometWrapper.previewRedeem(2_500e6);
        uint256 bobAssetsFromShares = cometWrapper.convertToAssets(2_500e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualAssetsReceived = cometWrapper.redeem(2_500e6, bob, bob);
        vm.stopPrank();

        // TODO: investigate rounding
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + bobPreviewedAssetsReceived, 2);
        assertApproxEqAbs(cometWrapper.balanceOf(bob), bobWrapperBalance - 2_500e6, 1);
        assertApproxEqAbs(bobPreviewedAssetsReceived, bobActualAssetsReceived, 1);
        assertGe(bobPreviewedAssetsReceived, bobActualAssetsReceived);
        assertEq(bobPreviewedAssetsReceived, bobAssetsFromShares);
    }

    function test_nullifyInflationAttacks() public {
        assertEq(cometWrapper.totalAssets(), 0);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000e6, alice);
        vm.stopPrank();

        uint256 oldTotalAssets = cometWrapper.totalAssets();
        assertEq(oldTotalAssets, comet.balanceOf(wrapperAddress));

        // totalAssets can not be manipulated, effectively nullifying inflation attacks
        vm.prank(bob);
        comet.transfer(wrapperAddress, 5_000e6);
        // totalAssets does not change when doing a direct transfer
        assertEq(cometWrapper.totalAssets(), oldTotalAssets);
        assertLt(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
    }

    function test_deposit() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, alice, 5_000e6, cometWrapper.convertToShares(5_000e6));
        cometWrapper.deposit(5_000e6, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, bob, 7_777e6, cometWrapper.convertToShares(7_777e6));
        cometWrapper.deposit(7_777e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        uint256 totalAssets = cometWrapper.maxWithdraw(alice) + cometWrapper.maxWithdraw(bob);
        // Alice and Bob should be able to withdraw all their assets without issue
        assertLe(totalAssets, cometWrapper.totalAssets());
    }

    // TODO: test deposit to

    function test_withdraw() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(9_101e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(2_555e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.prank(alice);
        cometWrapper.withdraw(173e6, alice, alice);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(500 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        uint256 aliceAssets = cometWrapper.maxWithdraw(alice);
        uint256 bobAssets = cometWrapper.maxWithdraw(bob);
        uint256 totalAssets = aliceAssets + bobAssets;
        assertLe(totalAssets, cometWrapper.totalAssets());

        vm.startPrank(alice);
        // TODO: investigate!
        // Due to rounding errors when updating principal, sometimes maxWithdraw may be off by 1
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, aliceAssets, cometWrapper.convertToShares(aliceAssets) + 1);
        cometWrapper.withdraw(cometWrapper.maxWithdraw(alice), alice, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        // Due to rounding errors when updating principal, sometimes maxWithdraw may be off by 1
        // This edge case appears when zeroing out the assets from the Wrapper contract
        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, bob, bobAssets, cometWrapper.convertToShares(bobAssets) + 1);
        cometWrapper.withdraw(cometWrapper.maxWithdraw(bob), bob, bob);
        vm.stopPrank();
    }

    // TODO: test withdraw from and to
    // TODO: test withdrawing not a max amount

    // TODO: turn into fuzz, like test_redeem
    function test_mint() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        // TODO: fix
        emit Deposit(alice, alice, cometWrapper.convertToAssets(9_000e6), 9_000e6 - 1);
        cometWrapper.mint(9_000e6, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        // TODO: fix so it's always equal!
        assertApproxEqAbs(cometWrapper.balanceOf(alice), 9_000e6, 1);
        // Make sure Alice never receives more shares than intended
        assertLe(cometWrapper.balanceOf(alice), 9_000e6);
        assertEq(cometWrapper.maxRedeem(alice), cometWrapper.balanceOf(alice));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        // TODO: fix
        emit Deposit(bob, bob, cometWrapper.convertToAssets(7_777e6), 7_777e6 - 1);
        cometWrapper.mint(7_777e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        // TODO: fix so it's always equal!
        assertApproxEqAbs(cometWrapper.balanceOf(bob), 7_777e6, 1);
        // Make sure Bob never receives more shares than intended
        assertLe(cometWrapper.balanceOf(bob), 7_777e6);

        uint256 totalAssets = cometWrapper.maxWithdraw(bob) + cometWrapper.maxWithdraw(alice);
        assertEq(totalAssets, cometWrapper.totalAssets());
    }

    // TODO: test mint to

    function test_redeem(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 5, 10_000e6);
        amount2 = bound(amount2, 5, 10_000e6);

        vm.prank(cusdcHolder);
        comet.transfer(alice, 10_000e6);

        vm.prank(cusdcHolder);
        comet.transfer(bob, 10_000e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(amount1, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(amount2, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(500 days);

        uint256 aliceShares = cometWrapper.maxRedeem(alice);
        uint256 bobShares = cometWrapper.maxRedeem(bob);

        // All users can fully redeem shares
        vm.expectEmit(true, true, true, true);
        // TODO: investigate round down
        emit Withdraw(alice, alice, alice, cometWrapper.convertToAssets(aliceShares) - 1, aliceShares);
        vm.prank(alice);
        cometWrapper.redeem(aliceShares, alice, alice);

        vm.expectEmit(true, true, true, true);
        // TODO: investigate round down of shares... this should not happen
        emit Withdraw(bob, bob, bob, cometWrapper.convertToAssets(bobShares) - 1, bobShares);
        vm.prank(bob);
        cometWrapper.redeem(bobShares, bob, bob);

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
    }

    // TODO: test redeem from and to
    // TODO: test redeeming not a max amount

    // TODO: can remove? is there a need for these checks?
    // TODO: maybe to prevent 0 shares minting non-zero values? add fuzz tests to verify this can't happen
    function test_disallowZeroSharesOrAssets() public {
        vm.expectRevert(CometHelpers.ZeroShares.selector);
        cometWrapper.mint(0, alice);
        vm.expectRevert(CometHelpers.ZeroShares.selector);
        cometWrapper.redeem(0, alice, alice);
        vm.expectRevert(CometHelpers.ZeroAssets.selector);
        cometWrapper.withdraw(0, alice, alice);
        vm.expectRevert(CometHelpers.ZeroAssets.selector);
        cometWrapper.deposit(0, alice);
    }

    function test_transfer() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(9_000e6, alice);
        cometWrapper.transferFrom(alice, bob, 1_337e6);
        vm.stopPrank();

        assertApproxEqAbs(cometWrapper.balanceOf(alice), 7_663e6, 1);
        assertApproxEqAbs(cometWrapper.balanceOf(bob), 1_337e6, 1);
        assertApproxEqAbs(cometWrapper.totalSupply(), 9_000e6, 1);

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(30 days);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, 777e6);
        cometWrapper.transfer(alice, 777e6);
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, 111e6);
        cometWrapper.transfer(alice, 111e6);
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, 99e6);
        cometWrapper.transfer(alice, 99e6);
        vm.stopPrank();

        assertApproxEqAbs(cometWrapper.balanceOf(alice), 7_663e6 + 777e6 + 111e6 + 99e6, 1);
        assertApproxEqAbs(cometWrapper.balanceOf(bob), 1_337e6 - 777e6 - 111e6 - 99e6, 1);

        skip(30 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertApproxEqAbs(cometWrapper.totalSupply(), 9_000e6, 1);
        uint256 totalPrincipal = unsigned256(comet.userBasic(address(cometWrapper)).principal);
        assertEq(cometWrapper.totalSupply(), totalPrincipal);
    }

    function test_transferFromWorksForSender() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, alice);

        cometWrapper.transferFrom(alice, bob, 2_500e6);
        vm.stopPrank();

        // TODO: investigate why this gets rounded down...i think because mint is rounded down. need to verify
        assertApproxEqAbs(cometWrapper.balanceOf(alice), 2_500e6, 1);
        assertEq(cometWrapper.balanceOf(bob), 2_500e6);
    }

    function test_transferFromUsesAllowances() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, alice);
        vm.stopPrank();

        // Need approvals to transferFrom alice to bob
        vm.prank(bob);
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 5_000e6);

        vm.prank(alice);
        cometWrapper.approve(bob, 2_700e6);

        vm.startPrank(bob);
        // Allowances should be updated when transferFrom is done
        assertEq(cometWrapper.allowance(alice, bob), 2_700e6);
        cometWrapper.transferFrom(alice, bob, 2_500e6);
        assertApproxEqAbs(cometWrapper.balanceOf(alice), 2_500e6, 1);
        assertEq(cometWrapper.balanceOf(bob), 2_500e6);

        // Reverts if trying to transferFrom again now that allowance is used up
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 2_500e6);
        vm.stopPrank();
        assertEq(cometWrapper.allowance(alice, bob), 200e6);

        // Infinite allowance does not decrease allowance
        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);

        vm.startPrank(alice);
        cometWrapper.transferFrom(bob, alice, 1_000e6);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);
        vm.stopPrank();
    }

    function test_transferFrom_revertInsufficientAllowance() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(1_000e6, alice);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 900e6);

        vm.prank(alice);
        cometWrapper.approve(bob, 500e6);

        vm.startPrank(bob);
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 800e6); // larger than allowance

        cometWrapper.transferFrom(alice, bob, 400e6); // less than allowance

        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 200e6); // larger than remaining allowance

        assertEq(cometWrapper.balanceOf(bob), 400e6);
        assertEq(cometWrapper.allowance(alice, bob), 100e6);
        vm.stopPrank();
    }
}

// TODO: add fuzz testing
// TODO: allow tests
// TODO: add tests for cWETHv3 decimals