// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { CoreTest, CometHelpers, CometWrapper, ICometRewards } from "./CoreTest.sol";

// Tests for `permit` and `encumberBySig`
abstract contract BySigTest is CoreTest {
    bytes32 internal constant AUTHORIZATION_TYPEHASH = keccak256("Authorization(address owner,address spender,uint256 amount,uint256 nonce,uint256 expiry)");
    bytes32 internal constant ENCUMBER_TYPEHASH = keccak256("Encumber(address owner,address taker,uint256 amount,uint256 nonce,uint256 expiry)");

    function aliceAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(AUTHORIZATION_TYPEHASH, alice, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", cometWrapper.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    function aliceContractAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(AUTHORIZATION_TYPEHASH, aliceContract, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", cometWrapper.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    function aliceEncumberAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(ENCUMBER_TYPEHASH, alice, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", cometWrapper.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    function aliceContractEncumberAuthorization(uint256 amount, uint256 nonce, uint256 expiry) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(abi.encode(ENCUMBER_TYPEHASH, aliceContract, bob, amount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", cometWrapper.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(alicePrivateKey, digest);
    }

    /* ===== Permit ===== */

    function test_permit() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature
        vm.prank(bob);
        cometWrapper.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice equals allowance
        assertEq(cometWrapper.allowance(alice, bob), allowance);

        // alice's nonce is incremented
        assertEq(cometWrapper.nonces(alice), nonce + 1);
    }

    function test_permit_revertsForBadOwner() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the owner
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(charlie, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_permit_revertsForBadSpender() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the spender
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(alice, charlie, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_permit_revertsForBadAmount() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the allowance
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(alice, bob, allowance + 1 wei, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_permit_revertsForBadExpiry() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(alice, bob, allowance, expiry + 1, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_permit_revertsForBadNonce() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 badNonce = nonce + 1;
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, badNonce, expiry);

        // bob calls permit with the signature with an invalid nonce
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_permit_revertsOnRepeatedCall() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature
        vm.prank(bob);
        cometWrapper.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice equals allowance
        assertEq(cometWrapper.allowance(alice, bob), allowance);

        // alice's nonce is incremented
        assertEq(cometWrapper.nonces(alice), nonce + 1);

        // alice revokes bob's allowance
        vm.prank(alice);
        cometWrapper.approve(bob, 0);
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // bob tries to reuse the same signature twice
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce + 1);
    }

    function test_permit_revertsForExpiredSignature() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceAuthorization(allowance, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls permit with the signature after the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.SignatureExpired.selector);
        cometWrapper.permit(alice, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_permit_revertsInvalidS() public {
        // bob's allowance from alice is 0
        assertEq(cometWrapper.allowance(alice, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceAuthorization(allowance, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls permit with the signature with invalid `s` value
        vm.prank(bob);
        vm.expectRevert(CometWrapper.InvalidSignatureS.selector);
        cometWrapper.permit(alice, bob, allowance, expiry, v, r, invalidS);

        // bob's allowance from alice is unchanged
        assertEq(cometWrapper.allowance(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    /* ===== EncumberBySig ===== */

    function test_encumberBySig() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.prank(bob);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(alice), encumbranceAmount);
        assertEq(cometWrapper.encumbrances(alice, bob), encumbranceAmount);

        // alice's nonce is incremented
        assertEq(cometWrapper.nonces(alice), nonce + 1);
    }

    function test_encumberBySig_revertsForBadOwner() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the owner
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(charlie, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_encumberBySig_revertsForBadSpender() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the spender
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(alice, charlie, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_encumberBySig_revertsForBadAmount() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the encumbranceAmount
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount + 1 wei, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_encumberBySig_revertsForBadExpiry() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount, expiry + 1, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_encumberBySig_revertsForBadNonce() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 nonce = cometWrapper.nonces(alice);
        uint256 badNonce = nonce + 1;
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, badNonce, expiry);

        // bob calls encumberBySig with the signature with an invalid nonce
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_encumberBySig_revertsOnRepeatedCall() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;
        uint256 transferAmount = 30e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.startPrank(bob);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // the encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(alice), encumbranceAmount);
        assertEq(cometWrapper.encumbrances(alice, bob), encumbranceAmount);

        // alice's nonce is incremented
        assertEq(cometWrapper.nonces(alice), nonce + 1);

        // bob uses some of the encumbrance to transfer to himself
        cometWrapper.transferFrom(alice, bob, transferAmount);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance - transferAmount);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(alice), encumbranceAmount - transferAmount);
        assertEq(cometWrapper.encumbrances(alice, bob), encumbranceAmount - transferAmount);

        // bob tries to reuse the same signature twice
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // no new encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance - transferAmount);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(alice), encumbranceAmount - transferAmount);
        assertEq(cometWrapper.encumbrances(alice, bob), encumbranceAmount - transferAmount);

        // alice's nonce is not incremented a second time
        assertEq(cometWrapper.nonces(alice), nonce + 1);

        vm.stopPrank();
    }

    function test_encumberBySig_revertsForExpiredSignature() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        // Fix for via-IR issue: https://github.com/foundry-rs/foundry/issues/3312#issuecomment-1255264273
        uint256 expiry = uint248(block.timestamp + 1000);

        (uint8 v, bytes32 r, bytes32 s) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls encumberBySig with the signature after the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.SignatureExpired.selector);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_encumberBySig_revertsInvalidS() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice has 100 wrapped tokens
        deal(address(cometWrapper), alice, aliceBalance);

        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.InvalidSignatureS.selector);
        cometWrapper.encumberBySig(alice, bob, encumbranceAmount, expiry, v, r, invalidS);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(alice), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(alice), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(alice), 0);
        assertEq(cometWrapper.encumbrances(alice, bob), 0);

        // alice's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    /* ===== EIP1271 Tests ===== */

    function test_permitEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature
        vm.prank(bob);
        cometWrapper.permit(aliceContract, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice's contract equals allowance
        assertEq(cometWrapper.allowance(aliceContract, bob), allowance);

        // alice's contract's nonce is incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce + 1);
    }

    function test_permit_revertsForBadOwnerEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the owner
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(charlie, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_permit_revertsForBadSpenderEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the spender
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(aliceContract, charlie, allowance, expiry, v, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_permit_revertsForBadAmountEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the allowance
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(aliceContract, bob, allowance + 1 wei, expiry, v, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_permit_revertsForBadExpiryEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(aliceContract, bob, allowance, expiry + 1, v, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(alice), nonce);
    }

    function test_permit_revertsForBadNonceEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 badNonce = nonce + 1;
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, badNonce, expiry);

        // bob calls permit with the signature with an invalid nonce
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(aliceContract, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_permit_revertsOnRepeatedCallEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);

        // bob calls permit with the signature
        vm.prank(bob);
        cometWrapper.permit(aliceContract, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice's contract equals allowance
        assertEq(cometWrapper.allowance(aliceContract, bob), allowance);

        // alice's contract's nonce is incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce + 1);

        // alice revokes bob's allowance
        vm.prank(aliceContract);
        cometWrapper.approve(bob, 0);
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // bob tries to reuse the same signature twice
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.permit(aliceContract, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce + 1);
    }

    function test_permit_revertsForExpiredSignatureEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls permit with the signature after the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.SignatureExpired.selector);
        cometWrapper.permit(aliceContract, bob, allowance, expiry, v, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_permit_revertsInvalidVEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (, bytes32 r, bytes32 s) = aliceContractAuthorization(allowance, nonce, expiry);
        uint8 invalidV = 26;

        // bob calls permit with the signature with invalid `v` value
        vm.prank(bob);
        vm.expectRevert(CometWrapper.EIP1271VerificationFailed.selector);
        cometWrapper.permit(aliceContract, bob, allowance, expiry, invalidV, r, s);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_permit_revertsInvalidSEIP1271() public {
        // bob's allowance from alice's contract is 0
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        uint256 allowance = 123e18;
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceContractAuthorization(allowance, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls permit with the signature with invalid `s` value
        vm.prank(bob);
        vm.expectRevert(CometWrapper.EIP1271VerificationFailed.selector);
        cometWrapper.permit(aliceContract, bob, allowance, expiry, v, r, invalidS);

        // bob's allowance from alice's contract is unchanged
        assertEq(cometWrapper.allowance(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_encumberBySigEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.prank(bob);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), encumbranceAmount);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), encumbranceAmount);

        // alice's contract's nonce is incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce + 1);
    }

    function test_encumberBySig_revertsForBadSpenderEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the spender
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(aliceContract, charlie, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_encumberBySig_revertsForBadAmountEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the encumbranceAmount
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount + 1 wei, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_encumberBySig_revertsForBadExpiryEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry + 1, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_encumberBySig_revertsForBadNonceEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice signs an authorization with an invalid nonce
        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 badNonce = nonce + 1;
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, badNonce, expiry);

        // bob calls encumberBySig with the signature with an invalid nonce
        vm.prank(bob);
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_encumberBySig_revertsOnRepeatedCallEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;
        uint256 transferAmount = 30e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(alice);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // bob calls encumberBySig with the signature
        vm.startPrank(bob);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // the encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), encumbranceAmount);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), encumbranceAmount);

        // alice's contract's nonce is incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce + 1);

        // bob uses some of the encumbrance to transfer to himself
        cometWrapper.transferFrom(aliceContract, bob, transferAmount);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance - transferAmount);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), encumbranceAmount - transferAmount);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), encumbranceAmount - transferAmount);

        // bob tries to reuse the same signature twice
        vm.expectRevert(CometWrapper.BadSignatory.selector);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // no new encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance - transferAmount);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance - encumbranceAmount);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), encumbranceAmount - transferAmount);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), encumbranceAmount - transferAmount);

        // alice's contract's nonce is not incremented a second time
        assertEq(cometWrapper.nonces(aliceContract), nonce + 1);

        vm.stopPrank();
    }

    function test_encumberBySig_revertsForExpiredSignatureEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(aliceContract);
        // Fix for via-IR issue: https://github.com/foundry-rs/foundry/issues/3312#issuecomment-1255264273
        uint256 expiry = uint248(block.timestamp + 1000);

        (uint8 v, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // the expiry block arrives
        vm.warp(expiry);

        // bob calls encumberBySig with the signature after the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.SignatureExpired.selector);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_encumberBySig_revertsInvalidVEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (, bytes32 r, bytes32 s) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);
        uint8 invalidV = 26;

        // bob calls encumberBySig with the signature with an invalid `v` value
        vm.prank(bob);
        vm.expectRevert(CometWrapper.EIP1271VerificationFailed.selector);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, invalidV, r, s);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }

    function test_encumberBySig_revertsInvalidSEIP1271() public {
        uint256 aliceBalance = 100e18;
        uint256 encumbranceAmount = 60e18;

        // alice's contract has 100 wrapped tokens
        deal(address(cometWrapper), aliceContract, aliceBalance);

        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        uint256 nonce = cometWrapper.nonces(aliceContract);
        uint256 expiry = block.timestamp + 1000;

        (uint8 v, bytes32 r, ) = aliceContractEncumberAuthorization(encumbranceAmount, nonce, expiry);

        // 1 greater than the max value of s
        bytes32 invalidS = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1;

        // bob calls encumberBySig with the signature, but he manipulates the expiry
        vm.prank(bob);
        vm.expectRevert(CometWrapper.EIP1271VerificationFailed.selector);
        cometWrapper.encumberBySig(aliceContract, bob, encumbranceAmount, expiry, v, r, invalidS);

        // no encumbrance is created
        assertEq(cometWrapper.balanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.availableBalanceOf(aliceContract), aliceBalance);
        assertEq(cometWrapper.encumberedBalanceOf(aliceContract), 0);
        assertEq(cometWrapper.encumbrances(aliceContract, bob), 0);

        // alice's contract's nonce is not incremented
        assertEq(cometWrapper.nonces(aliceContract), nonce);
    }
}
