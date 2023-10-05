// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { CoreTest, CometHelpers, CometWrapper, ERC20, ICometRewards } from "./CoreTest.sol";
import { CometMath } from "../src/vendor/CometMath.sol";

abstract contract CometWrapperTest is CoreTest, CometMath {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function setUpAliceAndBobCometBalances() public {
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

    function test_constructor_revertsOnInvalidComet() public {
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

    function test_constructor_revertsOnInvalidCometRewards() public {
        // reverts on zero address
        vm.expectRevert(CometHelpers.ZeroAddress.selector);
        new CometWrapper(ERC20(address(comet)), ICometRewards(address(0)), "Name", "Symbol");

        // reverts on non-zero address that isn't CometRewards
        vm.expectRevert();
        new CometWrapper(ERC20(address(comet)), ICometRewards(address(1)), "Name", "Symbol");
    }

    function test_totalAssets() public {
        setUpAliceAndBobCometBalances();

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
        setUpAliceAndBobCometBalances();

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
        setUpAliceAndBobCometBalances();

        assertEq(cometWrapper.balanceOf(alice), 0);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 alicePreviewedSharesReceived = cometWrapper.previewDeposit(5_000e6);
        uint256 aliceConvertToShares = cometWrapper.convertToShares(5_000e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualSharesReceived = cometWrapper.deposit(5_000e6, alice);
        vm.stopPrank();

        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance - 5_000e6, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance - 5_000e6);
        assertEq(cometWrapper.balanceOf(alice), alicePreviewedSharesReceived);
        assertEq(alicePreviewedSharesReceived, aliceActualSharesReceived);
        // previewDeposit should be <= convertToShares to account
        // for "slippage" that occurs during integer math rounding
        assertLe(alicePreviewedSharesReceived, aliceConvertToShares);

        assertEq(cometWrapper.balanceOf(bob), 0);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobPreviewedSharesReceived = cometWrapper.previewDeposit(5_000e6);
        uint256 bobConvertToShares = cometWrapper.convertToShares(5_000e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualSharesReceived = cometWrapper.deposit(5_000e6, bob);
        vm.stopPrank();

        // Bob loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance - 5_000e6, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance - 5_000e6);
        assertEq(cometWrapper.balanceOf(bob), bobPreviewedSharesReceived);
        assertEq(bobPreviewedSharesReceived, bobActualSharesReceived);
        // previewDeposit should be <= convertToShares to account
        // for "slippage" that occurs during integer math rounding
        assertLe(bobPreviewedSharesReceived, bobConvertToShares);
    }

    function test_previewMint() public {
        setUpAliceAndBobCometBalances();

        assertEq(cometWrapper.balanceOf(alice), 0);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 alicePreviewedAssetsUsed = cometWrapper.previewMint(5_000e6);
        uint256 aliceConvertToAssets = cometWrapper.convertToAssets(5_000e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualAssetsUsed = cometWrapper.mint(5_000e6, alice);
        vm.stopPrank();

        // Mints exact shares
        assertEq(cometWrapper.balanceOf(alice), 5_000e6);
        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance - alicePreviewedAssetsUsed, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance - alicePreviewedAssetsUsed);
        assertEq(alicePreviewedAssetsUsed, aliceActualAssetsUsed);
        // previewMint should be >= convertToShares to account for
        // "slippage" that occurs during integer math rounding
        assertGe(alicePreviewedAssetsUsed, aliceConvertToAssets);

        assertEq(cometWrapper.balanceOf(bob), 0);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobPreviewedAssetsUsed = cometWrapper.previewMint(5_000e6);
        uint256 bobConvertToAssets = cometWrapper.convertToAssets(5_000e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualAssetsUsed = cometWrapper.mint(5_000e6, bob);
        vm.stopPrank();

        // Mints exact shares
        assertEq(cometWrapper.balanceOf(bob), 5_000e6);
        // Bob loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance - bobPreviewedAssetsUsed, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance - bobPreviewedAssetsUsed);
        assertEq(bobPreviewedAssetsUsed, bobActualAssetsUsed);
        // previewMint should be >= convertToShares to account for
        // "slippage" that occurs during integer math rounding
        assertGe(bobPreviewedAssetsUsed, bobConvertToAssets);
    }

    function test_previewWithdraw() public {
        setUpAliceAndBobCometBalances();

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
        uint256 aliceConvertToShares = cometWrapper.convertToShares(2_500e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualSharesUsed = cometWrapper.withdraw(2_500e6, alice, alice);
        vm.stopPrank();

        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + 2_500e6, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance + 2_500e6);
        assertEq(cometWrapper.balanceOf(alice), aliceWrapperBalance - alicePreviewedSharesUsed);
        assertEq(alicePreviewedSharesUsed, aliceActualSharesUsed);
        // The value from convertToShares is <= the value from previewRedeem because it doesn't account
        // for "slippage" that occurs during integer math rounding
        assertGe(alicePreviewedSharesUsed, aliceConvertToShares);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 bobPreviewedSharesUsed = cometWrapper.previewWithdraw(2_500e6);
        uint256 bobConvertToShares = cometWrapper.convertToShares(2_500e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualSharesUsed = cometWrapper.withdraw(2_500e6, bob, bob);
        vm.stopPrank();

        // Bob loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + 2_500e6, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance + 2_500e6);
        assertEq(cometWrapper.balanceOf(bob), bobWrapperBalance - bobPreviewedSharesUsed);
        assertEq(bobPreviewedSharesUsed, bobActualSharesUsed);
        // The value from convertToShares is <= the value from previewRedeem because it doesn't account
        // for "slippage" that occurs during integer math rounding
        assertGe(bobPreviewedSharesUsed, bobConvertToShares);
    }

    function test_previewRedeem() public {
        setUpAliceAndBobCometBalances();

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
        uint256 aliceConvertToAssets = cometWrapper.convertToAssets(2_500e6);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualAssetsReceived = cometWrapper.redeem(2_500e6, alice, alice);
        vm.stopPrank();

        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + alicePreviewedAssetsReceived, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance + alicePreviewedAssetsReceived);
        assertEq(cometWrapper.balanceOf(alice), aliceWrapperBalance - 2_500e6);
        assertEq(alicePreviewedAssetsReceived, aliceActualAssetsReceived);
        // The value from convertToAssets is >= the value from previewRedeem because it doesn't account
        // for "slippage" that occurs during integer math rounding
        assertLe(alicePreviewedAssetsReceived, aliceConvertToAssets);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 bobPreviewedAssetsReceived = cometWrapper.previewRedeem(2_500e6);
        uint256 bobConvertToAssets = cometWrapper.convertToAssets(2_500e6);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualAssetsReceived = cometWrapper.redeem(2_500e6, bob, bob);
        vm.stopPrank();

        // Bob loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + bobPreviewedAssetsReceived, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance + bobPreviewedAssetsReceived);
        assertEq(cometWrapper.balanceOf(bob), bobWrapperBalance - 2_500e6);
        assertEq(bobPreviewedAssetsReceived, bobActualAssetsReceived);
        // The value from convertToAssets is >= the value from previewRedeem because it doesn't account
        // for "slippage" that occurs during integer math rounding
        assertLe(bobPreviewedAssetsReceived, bobConvertToAssets);
    }

    function test_nullifyInflationAttacks() public {
        setUpAliceAndBobCometBalances();

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

    function test_deposit(uint256 amount1, uint256 amount2) public {
        setUpAliceAndBobCometBalances();

        vm.assume(amount1 <= 2**48);
        vm.assume(amount2 <= 2**48);
        vm.assume(amount1 + amount2 < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin
        vm.assume(amount1 > 100e6 && amount2 > 100e6);

        vm.prank(cusdcHolder);
        comet.transfer(alice, amount1);

        vm.prank(cusdcHolder);
        comet.transfer(bob, amount2);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, alice, amount1, cometWrapper.previewDeposit(amount1));
        cometWrapper.deposit(amount1, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, bob, amount2, cometWrapper.previewDeposit(amount2));
        cometWrapper.deposit(amount2, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        uint256 totalAssets = cometWrapper.maxWithdraw(alice) + cometWrapper.maxWithdraw(bob);
        // Alice and Bob should be able to withdraw all their assets without issue
        assertLe(totalAssets, cometWrapper.totalAssets());
    }

    function test_depositTo() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, bob, 5_000e6, cometWrapper.convertToShares(5_000e6));
        cometWrapper.deposit(5_000e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, alice, 7_777e6, cometWrapper.convertToShares(7_777e6));
        cometWrapper.deposit(7_777e6, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        uint256 totalAssets = cometWrapper.maxWithdraw(alice) + cometWrapper.maxWithdraw(bob);
        // Alice and Bob should be able to withdraw all their assets without issue
        assertLe(totalAssets, cometWrapper.totalAssets());
    }

    function test_withdraw() public {
        setUpAliceAndBobCometBalances();

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

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 bobCometBalance = comet.balanceOf(bob);

        vm.startPrank(alice);
        // TODO: investigate!
        // Due to rounding errors when updating principal, sometimes maxWithdraw may be off by 1
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, aliceAssets, cometWrapper.convertToShares(aliceAssets) + 1);
        cometWrapper.withdraw(cometWrapper.maxWithdraw(alice), alice, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.underlyingBalance(alice), 0);
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + aliceAssets, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance + aliceAssets);

        vm.startPrank(bob);
        // Due to rounding errors when updating principal, sometimes maxWithdraw may be off by 1
        // This edge case appears when zeroing out the assets from the Wrapper contract
        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, bob, bobAssets, cometWrapper.convertToShares(bobAssets) + 1);
        cometWrapper.withdraw(cometWrapper.maxWithdraw(bob), bob, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.underlyingBalance(bob), 0);
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + bobAssets, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance + bobAssets);
    }

    function test_withdrawTo() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(9_101e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(2_555e6, bob);
        vm.stopPrank();

        uint256 aliceAssets = cometWrapper.maxWithdraw(alice);
        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 assetsToWithdraw = 333e6;
        uint256 expectedAliceWrapperAssets = aliceAssets - assetsToWithdraw;
        uint256 expectedBobCometBalance = bobCometBalance + assetsToWithdraw;

        // Alice withdraws from herself to Bob
        vm.startPrank(alice);
        // TODO: investigate rounding by 2???
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, bob, alice, assetsToWithdraw, cometWrapper.convertToShares(assetsToWithdraw) + 2);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertApproxEqAbs(cometWrapper.underlyingBalance(alice), expectedAliceWrapperAssets, 2);
        assertLe(cometWrapper.underlyingBalance(alice), expectedAliceWrapperAssets);
        // TODO: investigate rounding by 2???
        assertApproxEqAbs(comet.balanceOf(bob), expectedBobCometBalance, 1);
        assertLe(comet.balanceOf(bob), expectedBobCometBalance);
    }

    function test_withdrawFrom() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(9_101e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(2_555e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 bobAssets = cometWrapper.maxWithdraw(bob);
        uint256 assetsToWithdraw = 987e6;
        uint256 expectedBobWrapperAssets = bobAssets - assetsToWithdraw;
        uint256 expectedAliceCometBalance = aliceCometBalance + assetsToWithdraw;

        // Alice withdraws from Bob to herself
        vm.startPrank(alice);
        // TODO: investigate rounding by 2???
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, bob, assetsToWithdraw, cometWrapper.convertToShares(assetsToWithdraw) + 2);
        cometWrapper.withdraw(assetsToWithdraw, alice, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        // TODO: investigate rounding by 2???
        assertApproxEqAbs(cometWrapper.underlyingBalance(bob), expectedBobWrapperAssets, 2);
        assertLe(cometWrapper.underlyingBalance(bob), expectedBobWrapperAssets);
        assertApproxEqAbs(comet.balanceOf(alice), expectedAliceCometBalance, 1);
        assertLe(comet.balanceOf(alice), expectedAliceCometBalance);
    }

    function test_withdrawUsesAllowances() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, bob);
        vm.stopPrank();

        uint256 sharesToApprove = 2_700e6;
        uint256 sharesToWithdraw = 2_500e6;
        uint256 assetsToWithdraw = cometWrapper.convertToAssets(sharesToWithdraw);

        vm.prank(alice);
        cometWrapper.approve(bob, sharesToApprove);

        vm.startPrank(bob);
        // Allowances should be updated when withdraw is done
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        // TODO: investigate why balance is lower by 2
        assertApproxEqAbs(cometWrapper.balanceOf(alice), 5_000e6 - sharesToWithdraw, 2);

        // Reverts if trying to withdraw again now that allowance is used up
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        vm.stopPrank();
        // TODO: not exact, used 1 less. should be fixed if we subtract from approvals after recomputing shares
        assertApproxEqAbs(cometWrapper.allowance(alice, bob), sharesToApprove - sharesToWithdraw, 1);

        // Infinite allowance does not decrease allowance
        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);

        vm.startPrank(alice);
        cometWrapper.withdraw(assetsToWithdraw, alice, bob);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);
        vm.stopPrank();
    }

    function test_withdraw_revertsOnInsufficientAllowance() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(1_000e6, alice);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.withdraw(900e6, bob, alice);
    }

    function test_mint(uint256 amount1, uint256 amount2) public {
        setUpAliceAndBobCometBalances();

        vm.assume(amount1 <= 2**48);
        vm.assume(amount2 <= 2**48);
        vm.assume(amount1 + amount2 < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin
        vm.assume(amount1 > 100e6 && amount2 > 100e6);

        vm.prank(cusdcHolder);
        comet.transfer(alice, amount1);

        vm.prank(cusdcHolder);
        comet.transfer(bob, amount2);

        uint256 aliceMintAmount = amount1 / 2;
        uint256 bobMintAmount = amount2 / 2;

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, alice, cometWrapper.previewMint(aliceMintAmount), aliceMintAmount);
        cometWrapper.mint(aliceMintAmount, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.balanceOf(alice), aliceMintAmount);
        assertEq(cometWrapper.maxRedeem(alice), cometWrapper.balanceOf(alice));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, bob, cometWrapper.previewMint(bobMintAmount), bobMintAmount);
        cometWrapper.mint(bobMintAmount, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.balanceOf(bob), bobMintAmount);
        assertEq(cometWrapper.maxRedeem(bob), cometWrapper.balanceOf(bob));

        uint256 totalAssets = cometWrapper.maxWithdraw(bob) + cometWrapper.maxWithdraw(alice);
        // TODO: FIx this. totalAssets is less than cometWrapper.totalAssets, but should be equals.
        // maybe maxWithdraw is not correct
        assertLe(totalAssets, cometWrapper.totalAssets());
    }

    function test_mintTo() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, bob, cometWrapper.previewMint(9_000e6), 9_000e6);
        cometWrapper.mint(9_000e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.balanceOf(bob), 9_000e6);
        assertEq(cometWrapper.maxRedeem(bob), cometWrapper.balanceOf(bob));
    }

    function test_redeem(uint256 amount1, uint256 amount2) public {
        setUpAliceAndBobCometBalances();

        vm.assume(amount1 <= 2**48);
        vm.assume(amount2 <= 2**48);
        vm.assume(amount1 + amount2 < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin
        vm.assume(amount1 > 100e6 && amount2 > 100e6);

        vm.prank(cusdcHolder);
        comet.transfer(alice, amount1);

        vm.prank(cusdcHolder);
        comet.transfer(bob, amount2);

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
        uint256 aliceSharesToAssets = cometWrapper.convertToAssets(aliceShares);
        uint256 aliceAssetsWithdrawn = cometWrapper.previewRedeem(aliceShares);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, aliceAssetsWithdrawn, aliceShares);
        vm.prank(alice);
        cometWrapper.redeem(aliceShares, alice, alice);

        uint256 bobSharesToAssets = cometWrapper.convertToAssets(bobShares);
        uint256 bobAssetsWithdrawn = cometWrapper.previewRedeem(bobShares);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, bob, bobAssetsWithdrawn, bobShares);
        vm.prank(bob);
        cometWrapper.redeem(bobShares, bob, bob);

        // Ensure that actual assets withdrawn is <= the asset value of the shares burnt
        assertLe(aliceAssetsWithdrawn, aliceSharesToAssets);
        assertLe(bobAssetsWithdrawn, bobSharesToAssets);

        // Ensure that the wrapper is fully backed by the underlying Comet asset
        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
    }

    function test_redeemTo() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(8_098e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(3_555e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(500 days);

        uint256 aliceWrapperBalance = cometWrapper.balanceOf(alice);
        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 sharesToRedeem = 777e6;
        uint256 expectedAliceWrapperBalance = aliceWrapperBalance - sharesToRedeem;
        uint256 expectedBobCometBalance = bobCometBalance + cometWrapper.convertToAssets(sharesToRedeem);

        // Alice redeems from herself to Bob
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, bob, alice, cometWrapper.convertToAssets(sharesToRedeem), sharesToRedeem);
        cometWrapper.redeem(sharesToRedeem, bob, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.balanceOf(alice), expectedAliceWrapperBalance);
        // Bob receives 1 wei less due to rounding down behavior in Comet transfer logic
        assertApproxEqAbs(comet.balanceOf(bob), expectedBobCometBalance, 1);
        assertLe(comet.balanceOf(bob), expectedBobCometBalance);
    }

    function test_redeemFrom() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(8_098e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(3_555e6, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(250 days);

        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 sharesToRedeem = 1_322e6;
        uint256 expectedAliceCometBalance = aliceCometBalance + cometWrapper.convertToAssets(sharesToRedeem);
        uint256 expectedBobWrapperBalance = bobWrapperBalance - sharesToRedeem;

        // Alice redeems from Bob to herself
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, bob, cometWrapper.convertToAssets(sharesToRedeem), sharesToRedeem);
        cometWrapper.redeem(sharesToRedeem, alice, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.balanceOf(bob), expectedBobWrapperBalance);
        // Alice receives 1 wei less due to rounding down behavior in Comet transfer logic
        assertApproxEqAbs(comet.balanceOf(alice), expectedAliceCometBalance, 1);
        assertLe(comet.balanceOf(alice), expectedAliceCometBalance);
    }

    function test_redeemUsesAllowances() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000e6, bob);
        vm.stopPrank();

        uint256 sharesToApprove = 2_700e6;
        uint256 sharesToWithdraw = 2_500e6;

        vm.prank(alice);
        cometWrapper.approve(bob, sharesToApprove);

        vm.startPrank(bob);
        // Allowances should be updated when redeem is done
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove);
        cometWrapper.redeem(sharesToWithdraw, bob, alice);
        assertApproxEqAbs(cometWrapper.balanceOf(alice), 5_000e6 - sharesToWithdraw, 1);

        // Reverts if trying to redeem again now that allowance is used up
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.redeem(sharesToWithdraw, bob, alice);
        vm.stopPrank();
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove - sharesToWithdraw);

        // Infinite allowance does not decrease allowance
        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);

        vm.startPrank(alice);
        cometWrapper.redeem(sharesToWithdraw, alice, bob);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);
        vm.stopPrank();
    }

    function test_redeem_revertsOnInsufficientAllowance() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(1_000e6, alice);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometHelpers.InsufficientAllowance.selector);
        cometWrapper.redeem(900e6, bob, alice);
    }

    function test_revertsOnZeroShares() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectRevert(CometHelpers.ZeroShares.selector);
        cometWrapper.mint(0, alice);
        vm.expectRevert(CometHelpers.ZeroShares.selector);
        cometWrapper.redeem(0, alice, alice);
        vm.expectRevert(CometHelpers.ZeroShares.selector);
        cometWrapper.withdraw(0, alice, alice);
        vm.expectRevert(CometHelpers.ZeroShares.selector);
        cometWrapper.deposit(0, alice);
        vm.stopPrank();
    }

    function test_transfer() public {
        setUpAliceAndBobCometBalances();

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
        setUpAliceAndBobCometBalances();

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
        setUpAliceAndBobCometBalances();

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

    function test_transferFrom_revertsOnInsufficientAllowance() public {
        setUpAliceAndBobCometBalances();

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

// TODO: add fuzz testing for withdraw
// TODO: add tests for cWETHv3 decimals
// TODO: add tests for max withdraw/redeem
