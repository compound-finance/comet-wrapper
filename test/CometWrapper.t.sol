// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { CoreTest, CometHelpers, CometInterface, CometWrapper, IERC20, ICometRewards } from "./CoreTest.sol";
import { CometMath } from "../src/vendor/CometMath.sol";

abstract contract CometWrapperTest is CoreTest, CometMath {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function setUpAliceAndBobCometBalances() public {
        deal(address(underlyingToken), address(cometHolder), 20_000 * decimalScale);
        vm.startPrank(cometHolder);
        underlyingToken.approve(address(comet), 20_000 * decimalScale);
        comet.supply(address(underlyingToken), 20_000 * decimalScale);

        comet.transfer(alice, 10_000 * decimalScale);
        assertGt(comet.balanceOf(alice), 9999 * decimalScale);

        comet.transfer(bob, 10_000 * decimalScale);
        assertGt(comet.balanceOf(bob), 9999 * decimalScale);
        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(cometWrapper.trackingIndexScale(), comet.trackingIndexScale());
        assertEq(address(cometWrapper.comet()), address(comet));
        assertEq(address(cometWrapper.cometRewards()), address(cometRewards));
        assertEq(address(cometWrapper.asset()), address(comet));
        assertEq(cometWrapper.decimals(), comet.decimals());
        assertEq(cometWrapper.name(), "Wrapped Comet UNDERLYING");
        assertEq(cometWrapper.symbol(), "WcUNDERLYINGv3");
        assertEq(cometWrapper.totalSupply(), 0);
        assertEq(cometWrapper.totalAssets(), 0);
    }

    function test_constructor_revertsOnInvalidComet() public {
        // reverts on zero address
        vm.expectRevert();
        new CometWrapper(CometInterface(address(0)), cometRewards);

        // reverts on non-zero address that isn't ERC20 and Comet
        vm.expectRevert();
        new CometWrapper(CometInterface(address(1)), cometRewards);

        // reverts on ERC20-only contract
        vm.expectRevert();
        new CometWrapper(CometInterface(address(underlyingToken)), cometRewards);
    }

    function test_constructor_revertsOnInvalidCometRewards() public {
        // reverts on zero address
        vm.expectRevert();
        new CometWrapper(comet, ICometRewards(address(0)));

        // reverts on non-zero address that isn't CometRewards
        vm.expectRevert();
        new CometWrapper(comet, ICometRewards(address(1)));
    }

    function test_initialize_revertsIfCalledAgain() public {
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        cometWrapper.initialize("new name", "new symbol");
    }

    function test_initialize_revertsIfCalledOnImplementation() public {
        CometWrapper cometWrapperImpl =
            new CometWrapper(comet, cometRewards);

        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        cometWrapperImpl.initialize("new name", "new symbol");
    }

    function test_totalAssets() public {
        setUpAliceAndBobCometBalances();

        assertEq(cometWrapper.totalAssets(), 0);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000 * decimalScale, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000 * decimalScale, bob);
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
        cometWrapper.deposit(5_000 * decimalScale, alice);
        vm.stopPrank();

        // Rounds down underlying balance in favor of wrapper
        assertApproxEqAbs(cometWrapper.underlyingBalance(alice), 5_000 * decimalScale, 1);
        assertLe(cometWrapper.underlyingBalance(alice), 5_000 * decimalScale);
        skip(14 days);
        assertGe(cometWrapper.underlyingBalance(alice), 5_000 * decimalScale);
    }

    function test_previewDeposit() public {
        setUpAliceAndBobCometBalances();

        assertEq(cometWrapper.balanceOf(alice), 0);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 alicePreviewedSharesReceived = cometWrapper.previewDeposit(5_000 * decimalScale);
        uint256 aliceConvertToShares = cometWrapper.convertToShares(5_000 * decimalScale);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualSharesReceived = cometWrapper.deposit(5_000 * decimalScale, alice);
        vm.stopPrank();

        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance - 5_000 * decimalScale, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance - 5_000 * decimalScale);
        assertEq(cometWrapper.balanceOf(alice), alicePreviewedSharesReceived);
        assertEq(alicePreviewedSharesReceived, aliceActualSharesReceived);
        // previewDeposit should be <= convertToShares to account
        // for "slippage" that occurs during integer math rounding
        assertLe(alicePreviewedSharesReceived, aliceConvertToShares);

        assertEq(cometWrapper.balanceOf(bob), 0);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobPreviewedSharesReceived = cometWrapper.previewDeposit(5_000 * decimalScale);
        uint256 bobConvertToShares = cometWrapper.convertToShares(5_000 * decimalScale);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualSharesReceived = cometWrapper.deposit(5_000 * decimalScale, bob);
        vm.stopPrank();

        // Bob loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance - 5_000 * decimalScale, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance - 5_000 * decimalScale);
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
        uint256 alicePreviewedAssetsUsed = cometWrapper.previewMint(5_000 * decimalScale);
        uint256 aliceConvertToAssets = cometWrapper.convertToAssets(5_000 * decimalScale);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualAssetsUsed = cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        // Mints exact shares
        assertEq(cometWrapper.balanceOf(alice), 5_000 * decimalScale);
        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance - alicePreviewedAssetsUsed, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance - alicePreviewedAssetsUsed);
        assertEq(alicePreviewedAssetsUsed, aliceActualAssetsUsed);
        // previewMint should be >= convertToShares to account for
        // "slippage" that occurs during integer math rounding
        assertGe(alicePreviewedAssetsUsed, aliceConvertToAssets);

        assertEq(cometWrapper.balanceOf(bob), 0);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobPreviewedAssetsUsed = cometWrapper.previewMint(5_000 * decimalScale);
        uint256 bobConvertToAssets = cometWrapper.convertToAssets(5_000 * decimalScale);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualAssetsUsed = cometWrapper.mint(5_000 * decimalScale, bob);
        vm.stopPrank();

        // Mints exact shares
        assertEq(cometWrapper.balanceOf(bob), 5_000 * decimalScale);
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
        cometWrapper.deposit(5_000 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000 * decimalScale, bob);
        vm.stopPrank();

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 aliceWrapperBalance = cometWrapper.balanceOf(alice);
        uint256 alicePreviewedSharesUsed = cometWrapper.previewWithdraw(2_500 * decimalScale);
        uint256 aliceConvertToShares = cometWrapper.convertToShares(2_500 * decimalScale);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualSharesUsed = cometWrapper.withdraw(2_500 * decimalScale, alice, alice);
        vm.stopPrank();

        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + 2_500 * decimalScale, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance + 2_500 * decimalScale);
        assertEq(cometWrapper.balanceOf(alice), aliceWrapperBalance - alicePreviewedSharesUsed);
        assertEq(alicePreviewedSharesUsed, aliceActualSharesUsed);
        // The value from convertToShares is <= the value from previewRedeem because it doesn't account
        // for "slippage" that occurs during integer math rounding
        assertGe(alicePreviewedSharesUsed, aliceConvertToShares);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 bobPreviewedSharesUsed = cometWrapper.previewWithdraw(2_500 * decimalScale);
        uint256 bobConvertToShares = cometWrapper.convertToShares(2_500 * decimalScale);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualSharesUsed = cometWrapper.withdraw(2_500 * decimalScale, bob, bob);
        vm.stopPrank();

        // Bob loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + 2_500 * decimalScale, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance + 2_500 * decimalScale);
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
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, bob);
        vm.stopPrank();

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 aliceWrapperBalance = cometWrapper.balanceOf(alice);
        uint256 alicePreviewedAssetsReceived = cometWrapper.previewRedeem(2_500 * decimalScale);
        uint256 aliceConvertToAssets = cometWrapper.convertToAssets(2_500 * decimalScale);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        uint256 aliceActualAssetsReceived = cometWrapper.redeem(2_500 * decimalScale, alice, alice);
        vm.stopPrank();

        // Alice loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + alicePreviewedAssetsReceived, 1);
        assertLe(comet.balanceOf(alice), aliceCometBalance + alicePreviewedAssetsReceived);
        assertEq(cometWrapper.balanceOf(alice), aliceWrapperBalance - 2_500 * decimalScale);
        assertEq(alicePreviewedAssetsReceived, aliceActualAssetsReceived);
        // The value from convertToAssets is >= the value from previewRedeem because it doesn't account
        // for "slippage" that occurs during integer math rounding
        assertLe(alicePreviewedAssetsReceived, aliceConvertToAssets);

        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 bobPreviewedAssetsReceived = cometWrapper.previewRedeem(2_500 * decimalScale);
        uint256 bobConvertToAssets = cometWrapper.convertToAssets(2_500 * decimalScale);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        uint256 bobActualAssetsReceived = cometWrapper.redeem(2_500 * decimalScale, bob, bob);
        vm.stopPrank();

        // Bob loses 1 gwei of the underlying due to Comet rounding during transfers
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + bobPreviewedAssetsReceived, 1);
        assertLe(comet.balanceOf(bob), bobCometBalance + bobPreviewedAssetsReceived);
        assertEq(cometWrapper.balanceOf(bob), bobWrapperBalance - 2_500 * decimalScale);
        assertEq(bobPreviewedAssetsReceived, bobActualAssetsReceived);
        // The value from convertToAssets is >= the value from previewRedeem because it doesn't account
        // for "slippage" that occurs during integer math rounding
        assertLe(bobPreviewedAssetsReceived, bobConvertToAssets);
    }

    function test_maxWithdraw(uint256 amount) public {
        setUpAliceAndBobCometBalances();

        amount = setUpFuzzTestAssumptions(amount);

        vm.startPrank(cometHolder);
        comet.allow(wrapperAddress, true);
        uint256 sharesMinted = cometWrapper.deposit(amount, alice);
        vm.stopPrank();

        assertEq(cometWrapper.maxWithdraw(alice), cometWrapper.previewRedeem(sharesMinted));
        assertEq(cometWrapper.maxWithdraw(alice), cometWrapper.underlyingBalance(alice));
    }

    function test_maxRedeem(uint256 amount) public {
        setUpAliceAndBobCometBalances();

        amount = setUpFuzzTestAssumptions(amount);

        vm.startPrank(cometHolder);
        comet.allow(wrapperAddress, true);
        uint256 sharesMinted = cometWrapper.deposit(amount, alice);
        vm.stopPrank();

        assertEq(cometWrapper.maxRedeem(alice), sharesMinted);
        assertEq(cometWrapper.maxRedeem(alice), cometWrapper.balanceOf(alice));
    }

    function test_nullifyInflationAttacks() public {
        setUpAliceAndBobCometBalances();

        assertEq(cometWrapper.totalAssets(), 0);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(5_000 * decimalScale, alice);
        vm.stopPrank();

        uint256 oldTotalAssets = cometWrapper.totalAssets();
        assertEq(oldTotalAssets, comet.balanceOf(wrapperAddress));

        // totalAssets can not be manipulated, effectively nullifying inflation attacks
        vm.prank(bob);
        comet.transfer(wrapperAddress, 5_000 * decimalScale);
        // totalAssets does not change when doing a direct transfer
        assertEq(cometWrapper.totalAssets(), oldTotalAssets);
        assertLt(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
    }

    function test_deposit(uint256 amount1, uint256 amount2) public {
        setUpAliceAndBobCometBalances();

        (amount1, amount2) = setUpFuzzTestAssumptions(amount1, amount2);

        vm.prank(cometHolder);
        comet.transfer(alice, amount1);

        vm.prank(cometHolder);
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
        emit Deposit(alice, bob, 5_000 * decimalScale, cometWrapper.previewDeposit(5_000 * decimalScale));
        cometWrapper.deposit(5_000 * decimalScale, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(bob, alice, 7_777 * decimalScale, cometWrapper.previewDeposit(7_777 * decimalScale));
        cometWrapper.deposit(7_777 * decimalScale, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        uint256 totalAssets = cometWrapper.maxWithdraw(alice) + cometWrapper.maxWithdraw(bob);
        // Alice and Bob should be able to withdraw all their assets without issue
        assertLe(totalAssets, cometWrapper.totalAssets());
    }

    function test_withdraw(uint256 amount1, uint256 amount2, uint256 aliceWithdrawAmount) public {
        setUpAliceAndBobCometBalances();

        (amount1, amount2) = setUpFuzzTestAssumptions(amount1, amount2);
        aliceWithdrawAmount = bound(aliceWithdrawAmount, 0, amount1);

        vm.startPrank(cometHolder);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(amount1, alice);
        cometWrapper.deposit(amount2, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(14 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.prank(alice);
        cometWrapper.withdraw(aliceWithdrawAmount, alice, alice);
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
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, aliceAssets, cometWrapper.previewWithdraw(aliceAssets));
        cometWrapper.withdraw(aliceAssets, alice, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.underlyingBalance(alice), 0);
        assertApproxEqAbs(comet.balanceOf(alice), aliceCometBalance + aliceAssets, 2);
        assertLe(comet.balanceOf(alice), aliceCometBalance + aliceAssets);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(bob, bob, bob, bobAssets, cometWrapper.previewWithdraw(bobAssets));
        cometWrapper.withdraw(bobAssets, bob, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.underlyingBalance(bob), 0);
        assertApproxEqAbs(comet.balanceOf(bob), bobCometBalance + bobAssets, 2);
        assertLe(comet.balanceOf(bob), bobCometBalance + bobAssets);
    }

    function test_withdrawTo() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(9_101 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(2_555 * decimalScale, bob);
        vm.stopPrank();

        uint256 aliceAssets = cometWrapper.maxWithdraw(alice);
        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 assetsToWithdraw = 333 * decimalScale;
        uint256 expectedAliceWrapperAssets = aliceAssets - assetsToWithdraw;
        uint256 expectedBobCometBalance = bobCometBalance + assetsToWithdraw;

        // Alice withdraws from herself to Bob
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, bob, alice, assetsToWithdraw, cometWrapper.previewWithdraw(assetsToWithdraw));
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertApproxEqAbs(cometWrapper.underlyingBalance(alice), expectedAliceWrapperAssets, 1);
        assertLe(cometWrapper.underlyingBalance(alice), expectedAliceWrapperAssets);
        assertApproxEqAbs(comet.balanceOf(bob), expectedBobCometBalance, 1);
        assertLe(comet.balanceOf(bob), expectedBobCometBalance);
    }

    function test_withdrawFrom() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(9_101 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(2_555 * decimalScale, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 bobAssets = cometWrapper.maxWithdraw(bob);
        uint256 assetsToWithdraw = 987 * decimalScale;
        uint256 expectedBobWrapperAssets = bobAssets - assetsToWithdraw;
        uint256 expectedAliceCometBalance = aliceCometBalance + assetsToWithdraw;

        // Alice withdraws from Bob to herself
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, bob, assetsToWithdraw, cometWrapper.previewWithdraw(assetsToWithdraw));
        cometWrapper.withdraw(assetsToWithdraw, alice, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertApproxEqAbs(cometWrapper.underlyingBalance(bob), expectedBobWrapperAssets, 1);
        assertLe(cometWrapper.underlyingBalance(bob), expectedBobWrapperAssets);
        assertApproxEqAbs(comet.balanceOf(alice), expectedAliceCometBalance, 1);
        assertLe(comet.balanceOf(alice), expectedAliceCometBalance);
    }

    function test_withdrawFromUsesAllowances() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, bob);
        vm.stopPrank();

        uint256 sharesToApprove = 2_700 * decimalScale;
        uint256 sharesToRedeem = 2_500 * decimalScale;
        uint256 assetsToWithdraw = cometWrapper.previewRedeem(sharesToRedeem);

        vm.prank(alice);
        cometWrapper.approve(bob, sharesToApprove);

        vm.startPrank(bob);
        // Allowances should be updated when withdraw is done
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove - sharesToRedeem);
        assertEq(cometWrapper.balanceOf(alice), 5_000 * decimalScale - sharesToRedeem);

        // Reverts if trying to withdraw again now that allowance is used up
        assetsToWithdraw = cometWrapper.previewRedeem(sharesToRedeem);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.withdraw(assetsToWithdraw, bob, alice);
        vm.stopPrank();
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove - sharesToRedeem);

        // Infinite allowance does not decrease allowance
        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);

        vm.startPrank(alice);
        cometWrapper.withdraw(assetsToWithdraw, alice, bob);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);
        vm.stopPrank();
    }

    function test_withdrawFrom_revertsOnInsufficientAllowance() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(1_000 * decimalScale, alice);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.withdraw(900 * decimalScale, bob, alice);
    }

    function test_mint(uint256 amount1, uint256 amount2) public {
        setUpAliceAndBobCometBalances();

        (amount1, amount2) = setUpFuzzTestAssumptions(amount1, amount2);

        vm.prank(cometHolder);
        comet.transfer(alice, amount1);

        vm.prank(cometHolder);
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
        // Total asset owed to Alice and Bob is less than the total assets stored in the wrapper
        // due to rounding down in favor of the wrapper.
        assertLe(totalAssets, cometWrapper.totalAssets());
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());
    }

    function test_mintTo() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Deposit(alice, bob, cometWrapper.previewMint(9_000 * decimalScale), 9_000 * decimalScale);
        cometWrapper.mint(9_000 * decimalScale, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.balanceOf(bob), 9_000 * decimalScale);
        assertEq(cometWrapper.maxRedeem(bob), cometWrapper.balanceOf(bob));
    }

    function test_redeem(uint256 amount1, uint256 amount2) public {
        setUpAliceAndBobCometBalances();

        (amount1, amount2) = setUpFuzzTestAssumptions(amount1, amount2);

        vm.startPrank(cometHolder);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(amount1, alice);
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
        cometWrapper.deposit(8_098 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(3_555 * decimalScale, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(500 days);

        uint256 aliceWrapperBalance = cometWrapper.balanceOf(alice);
        uint256 bobCometBalance = comet.balanceOf(bob);
        uint256 sharesToRedeem = 777 * decimalScale;
        uint256 expectedAliceWrapperBalance = aliceWrapperBalance - sharesToRedeem;
        uint256 expectedBobCometBalance = bobCometBalance + cometWrapper.previewRedeem(sharesToRedeem);

        // Alice redeems from herself to Bob
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, bob, alice, cometWrapper.previewRedeem(sharesToRedeem), sharesToRedeem);
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
        cometWrapper.deposit(8_098 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(3_555 * decimalScale, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));

        skip(250 days);

        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);

        uint256 aliceCometBalance = comet.balanceOf(alice);
        uint256 bobWrapperBalance = cometWrapper.balanceOf(bob);
        uint256 sharesToRedeem = 1_322 * decimalScale;
        uint256 expectedAliceCometBalance = aliceCometBalance + cometWrapper.previewRedeem(sharesToRedeem);
        uint256 expectedBobWrapperBalance = bobWrapperBalance - sharesToRedeem;

        // Alice redeems from Bob to herself
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, bob, cometWrapper.previewRedeem(sharesToRedeem), sharesToRedeem);
        cometWrapper.redeem(sharesToRedeem, alice, bob);
        vm.stopPrank();

        assertEq(cometWrapper.totalSupply(), unsigned104(comet.userBasic(wrapperAddress).principal));
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.balanceOf(bob), expectedBobWrapperBalance);
        // Alice receives 1 wei less due to rounding down behavior in Comet transfer logic
        assertApproxEqAbs(comet.balanceOf(alice), expectedAliceCometBalance, 1);
        assertLe(comet.balanceOf(alice), expectedAliceCometBalance);
    }

    function test_redeemFromUsesAllowances() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, bob);
        vm.stopPrank();

        uint256 sharesToApprove = 2_700 * decimalScale;
        uint256 sharesToRedeem = 2_500 * decimalScale;

        vm.prank(alice);
        cometWrapper.approve(bob, sharesToApprove);

        vm.startPrank(bob);
        // Allowances should be updated when redeem is done
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove);
        cometWrapper.redeem(sharesToRedeem, bob, alice);
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove - sharesToRedeem);
        assertEq(cometWrapper.balanceOf(alice), 5_000 * decimalScale - sharesToRedeem);

        // Reverts if trying to redeem again now that allowance is used up
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.redeem(sharesToRedeem, bob, alice);
        vm.stopPrank();
        assertEq(cometWrapper.allowance(alice, bob), sharesToApprove - sharesToRedeem);

        // Infinite allowance does not decrease allowance
        vm.prank(bob);
        cometWrapper.approve(alice, type(uint256).max);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);

        vm.startPrank(alice);
        cometWrapper.redeem(sharesToRedeem, alice, bob);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);
        vm.stopPrank();
    }

    function test_redeemFrom_revertsOnInsufficientAllowance() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(1_000 * decimalScale, alice);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.redeem(900 * decimalScale, bob, alice);
    }

    function test_revertsOnZeroShares() public {
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        vm.expectRevert(CometWrapper.ZeroShares.selector);
        cometWrapper.mint(0, alice);
        vm.expectRevert(CometWrapper.ZeroShares.selector);
        cometWrapper.redeem(0, alice, alice);
        vm.expectRevert(CometWrapper.ZeroShares.selector);
        cometWrapper.withdraw(0, alice, alice);
        vm.expectRevert(CometWrapper.ZeroShares.selector);
        cometWrapper.deposit(0, alice);
        vm.stopPrank();
    }

    function test_transfer() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(9_000 * decimalScale, alice);
        cometWrapper.transfer(bob, 1_337 * decimalScale);
        vm.stopPrank();

        assertEq(cometWrapper.balanceOf(alice), 7_663 * decimalScale);
        assertEq(cometWrapper.balanceOf(bob), 1_337 * decimalScale);
        assertEq(cometWrapper.totalSupply(), 9_000 * decimalScale);

        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        skip(30 days);

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, 777 * decimalScale);
        cometWrapper.transfer(alice, 777 * decimalScale);
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, 111 * decimalScale);
        cometWrapper.transfer(alice, 111 * decimalScale);
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, 99 * decimalScale);
        cometWrapper.transfer(alice, 99 * decimalScale);
        vm.stopPrank();

        assertEq(cometWrapper.balanceOf(alice), (7_663 + 777 + 111 + 99) * decimalScale);
        assertEq(cometWrapper.balanceOf(bob), (1_337 - 777 - 111 - 99) * decimalScale);

        skip(30 days);
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(wrapperAddress));
        assertEq(cometWrapper.totalSupply(), 9_000 * decimalScale);
        uint256 totalPrincipal = unsigned256(comet.userBasic(address(cometWrapper)).principal);
        assertEq(cometWrapper.totalSupply(), totalPrincipal);
    }

    function test_transferFromWorksForSender() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        // Alice needs to give approval to herself in order to `transferFrom`
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, alice, 2_500 * decimalScale);
        cometWrapper.approve(alice, 2_500 * decimalScale);

        vm.expectEmit(true, true, true, true);
        emit Approval(alice, alice, 0);
        cometWrapper.transferFrom(alice, bob, 2_500 * decimalScale);
        vm.stopPrank();

        assertEq(cometWrapper.balanceOf(alice), 2_500 * decimalScale);
        assertEq(cometWrapper.balanceOf(bob), 2_500 * decimalScale);
    }

    function test_transferFromUsesAllowances() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(5_000 * decimalScale, alice);
        vm.stopPrank();

        // Need approvals to transferFrom alice to bob
        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 5_000 * decimalScale);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 2_700 * decimalScale);
        cometWrapper.approve(bob, 2_700 * decimalScale);

        vm.startPrank(bob);
        // Allowances should be updated when transferFrom is done
        assertEq(cometWrapper.allowance(alice, bob), 2_700 * decimalScale);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 200 * decimalScale);
        cometWrapper.transferFrom(alice, bob, 2_500 * decimalScale);
        assertEq(cometWrapper.balanceOf(alice), 2_500 * decimalScale);
        assertEq(cometWrapper.balanceOf(bob), 2_500 * decimalScale);

        // Reverts if trying to transferFrom again now that allowance is used up
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 2_500 * decimalScale);
        vm.stopPrank();
        assertEq(cometWrapper.allowance(alice, bob), 200 * decimalScale);

        // Infinite allowance does not decrease allowance
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Approval(bob, alice, type(uint256).max);
        cometWrapper.approve(alice, type(uint256).max);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);

        vm.startPrank(alice);
        cometWrapper.transferFrom(bob, alice, 1_000 * decimalScale);
        assertEq(cometWrapper.allowance(bob, alice), type(uint256).max);
        vm.stopPrank();
    }

    function test_transferFrom_revertsOnInsufficientAllowance() public {
        setUpAliceAndBobCometBalances();

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(1_000 * decimalScale, alice);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 900 * decimalScale);

        vm.prank(alice);
        cometWrapper.approve(bob, 500 * decimalScale);

        vm.startPrank(bob);
        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 800 * decimalScale); // larger than allowance

        cometWrapper.transferFrom(alice, bob, 400 * decimalScale); // less than allowance

        vm.expectRevert(CometWrapper.InsufficientAllowance.selector);
        cometWrapper.transferFrom(alice, bob, 200 * decimalScale); // larger than remaining allowance

        assertEq(cometWrapper.balanceOf(bob), 400 * decimalScale);
        assertEq(cometWrapper.allowance(alice, bob), 100 * decimalScale);
        vm.stopPrank();
    }
}
