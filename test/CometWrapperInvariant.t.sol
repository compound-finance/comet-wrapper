// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseTest, CometHelpers, CometWrapper, ERC20, ICometRewards} from "./BaseTest.sol";
import {CometMath} from "../src/vendor/CometMath.sol";

contract CometWrapperInvariantTest is BaseTest, CometMath {
    // Invariants:
    // - totalAssets must always be <= comet.balanceOf(address(cometWrapper))
    // - sum of all underlyingBalances of accounts <= totalAssets
    // - sum of user balances == cometWrapper's principal in comet
    function test_contractBalanceInvariants(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= 2**48);
        vm.assume(amount2 <= 2**48);
        vm.assume(amount1 + amount2 < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin
        vm.assume(amount1 > 100e6 && amount2 > 100e6);

        vm.prank(cusdcHolder);
        comet.transfer(alice, amount1);
        vm.prank(cusdcHolder);
        comet.transfer(bob, amount2);

        uint256 aliceBalance = comet.balanceOf(alice);
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(aliceBalance/5, alice);
        vm.stopPrank();
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        uint256 bobBalance = comet.balanceOf(bob);
        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(bobBalance/5, bob);
        vm.stopPrank();
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        skip(10000 days);

        vm.prank(alice);
        cometWrapper.mint(aliceBalance/3, alice);
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        vm.prank(bob);
        cometWrapper.mint(bobBalance/3, bob);
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        assertEq(cometWrapper.balanceOf(alice) + cometWrapper.balanceOf(bob), unsigned256(comet.userBasic(address(cometWrapper)).principal));

        vm.prank(alice);
        cometWrapper.withdraw(aliceBalance/4, alice, alice);
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        vm.prank(bob);
        cometWrapper.withdraw(bobBalance/4, bob, bob);
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        assertEq(cometWrapper.balanceOf(alice) + cometWrapper.balanceOf(bob), unsigned256(comet.userBasic(address(cometWrapper)).principal));

        vm.prank(alice);
        cometWrapper.redeem(aliceBalance/5, alice, alice);
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        vm.prank(bob);
        cometWrapper.redeem(bobBalance/5, bob, bob);
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        assertEq(cometWrapper.balanceOf(alice) + cometWrapper.balanceOf(bob), unsigned256(comet.userBasic(address(cometWrapper)).principal));

        vm.startPrank(alice);
        cometWrapper.redeem(cometWrapper.maxRedeem(alice), alice, alice);
        vm.stopPrank();
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        vm.startPrank(bob);
        cometWrapper.redeem(cometWrapper.maxRedeem(bob), bob, bob);
        vm.stopPrank();
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());

        assertEq(cometWrapper.balanceOf(alice) + cometWrapper.balanceOf(bob), unsigned256(comet.userBasic(address(cometWrapper)).principal));
    }

    // Invariants:
    // - on redeem, decrease in wrapper's Comet principal == burnt user shares == change in total supply
    function test_redeemInvariants(uint256 amount1) public {
        vm.assume(amount1 <= 2**48);
        vm.assume(amount1 > 1000e6);
        vm.assume(amount1 < comet.balanceOf(cusdcHolder) - 100e6); // to account for borrowMin

        vm.prank(cusdcHolder);
        comet.transfer(alice, amount1);

        skip(30000 days);

        uint256 aliceBalance = comet.balanceOf(alice);
        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.mint(aliceBalance/3, alice);
        assertEq(comet.balanceOf(address(cometWrapper)), cometWrapper.totalAssets());
        vm.stopPrank();


        vm.startPrank(alice);
        int256 preWrapperCometPrincipal = comet.userBasic(address(cometWrapper)).principal;
        uint256 preAliceShares = cometWrapper.balanceOf(alice);
        uint256 preTotalSupply = cometWrapper.totalSupply();
        cometWrapper.redeem(aliceBalance/5, alice, alice);
        uint256 decreaseInWrapperCometPrincipal = uint256(preWrapperCometPrincipal - comet.userBasic(address(cometWrapper)).principal);
        uint256 aliceSharesBurnt = preAliceShares - cometWrapper.balanceOf(alice);
        uint256 decreaseInTotalSupply = preTotalSupply - cometWrapper.totalSupply();
        // Check that principal is decreased by the amount of shares burnt
        assertEq(decreaseInWrapperCometPrincipal, aliceSharesBurnt);
        // Check that principal is decreased by that total supply has decreased
        assertEq(decreaseInWrapperCometPrincipal, decreaseInTotalSupply);
        // Check that the wrapper is still fully backed by the underlying Comet asset
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(address(cometWrapper)));
        vm.stopPrank();

        vm.startPrank(alice);
        preWrapperCometPrincipal = comet.userBasic(address(cometWrapper)).principal;
        preAliceShares = cometWrapper.balanceOf(alice);
        preTotalSupply = cometWrapper.totalSupply();
        cometWrapper.redeem(cometWrapper.maxRedeem(alice), alice, alice);
        decreaseInWrapperCometPrincipal = uint256(preWrapperCometPrincipal - comet.userBasic(address(cometWrapper)).principal);
        aliceSharesBurnt = preAliceShares - cometWrapper.balanceOf(alice);
        decreaseInTotalSupply = preTotalSupply - cometWrapper.totalSupply();
        // Check that principal is decreased by the amount of shares burnt
        assertEq(decreaseInWrapperCometPrincipal, aliceSharesBurnt);
        // Check that principal is decreased by that total supply has decreased
        assertEq(decreaseInWrapperCometPrincipal, decreaseInTotalSupply);
        // Check that the wrapper is still fully backed by the underlying Comet asset
        assertEq(cometWrapper.totalAssets(), comet.balanceOf(address(cometWrapper)));
        vm.stopPrank();
    }

    // Invariants:
    // - transfers must not change totalSupply
    // - transfers must not change totalAssets
    function test_transferInvariants(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= 2**48);
        vm.assume(amount2 <= 2**48);
        vm.assume(amount1 + amount2 < comet.balanceOf(cusdcHolder));
        vm.assume(amount1 > 1000e6 && amount2 > 1000e6);

        vm.prank(cusdcHolder);
        comet.transfer(alice, amount1);
        vm.prank(cusdcHolder);
        comet.transfer(bob, amount2);

        vm.startPrank(alice);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(comet.balanceOf(alice), alice);
        vm.stopPrank();

        vm.startPrank(bob);
        comet.allow(wrapperAddress, true);
        cometWrapper.deposit(comet.balanceOf(bob), bob);
        vm.stopPrank();

        uint256 totalAssets = cometWrapper.totalAssets();
        uint256 totalSupply = cometWrapper.totalSupply();
        assertEq(totalAssets, comet.balanceOf(address(cometWrapper)));

        for (uint256 i; i < 5; i++) {
            vm.startPrank(alice);
            cometWrapper.transferFrom(alice, bob, cometWrapper.balanceOf(alice)/5);
            assertEq(cometWrapper.totalAssets(), totalAssets);
            assertEq(cometWrapper.totalSupply(), totalSupply);
            vm.stopPrank();

            vm.startPrank(bob);
            cometWrapper.transferFrom(bob, alice, cometWrapper.balanceOf(bob)/5);
            assertEq(cometWrapper.totalAssets(), totalAssets);
            assertEq(cometWrapper.totalSupply(), totalSupply);
            vm.stopPrank();

            vm.startPrank(bob);
            cometWrapper.transferFrom(bob, alice, cometWrapper.balanceOf(bob)/5);
            assertEq(cometWrapper.totalAssets(), totalAssets);
            assertEq(cometWrapper.totalSupply(), totalSupply);
            vm.stopPrank();

            vm.startPrank(alice);
            cometWrapper.transferFrom(alice, bob, cometWrapper.balanceOf(alice)/5);
            assertEq(cometWrapper.totalAssets(), totalAssets);
            assertEq(cometWrapper.totalSupply(), totalSupply);
            vm.stopPrank();
        }
    }
}