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
        vm.assume(amount1 + amount2 < comet.balanceOf(cusdcHolder));
        vm.assume(amount1 > 1000e6 && amount2 > 1000e6);

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