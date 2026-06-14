// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BotPassReferral} from "../src/BotPassReferral.sol";

contract BotPassReferralTest is Test {
    BotPassReferral internal pass;

    uint256 internal constant PRICE = 0.01 ether;
    uint256 internal constant PERIOD = 30 days;
    uint256 internal constant BPS = 1000;            // 10%
    uint256 internal constant COMMISSION = PRICE * BPS / 10000; // 0.001 ether

    address internal alice = makeAddr("alice");   // cliente
    address internal bob = makeAddr("bob");       // referidor
    address internal carol = makeAddr("carol");   // otro cliente

    function setUp() public {
        pass = new BotPassReferral(PRICE, PERIOD, BPS); // address(this) = owner
        vm.deal(alice, 1 ether);
        vm.deal(carol, 1 ether);
    }

    // ---- subscribe + split ----

    function test_Subscribe_NoReferrer_AllToOwner() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}(address(0));

        assertTrue(pass.isActive(alice));
        assertEq(pass.pending(address(this)), PRICE, "todo al owner");
        assertEq(pass.pending(bob), 0);
    }

    function test_Subscribe_WithReferrer_SplitsCommission() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}(bob);

        assertEq(pass.pending(bob), COMMISSION, "bob cobra 10%");
        assertEq(pass.pending(address(this)), PRICE - COMMISSION, "owner cobra el resto");
    }

    function test_Subscribe_SelfReferral_NoCommission() public {
        // alice se pone a sí misma de referidor: no debe cobrar comisión.
        vm.prank(alice);
        pass.subscribe{value: PRICE}(alice);

        assertEq(pass.pending(alice), 0, "sin auto-comision");
        assertEq(pass.pending(address(this)), PRICE, "todo al owner");
    }

    function test_Subscribe_RevertsIfInsufficient() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: pago insuficiente"));
        pass.subscribe{value: PRICE - 1}(bob);
    }

    function test_Commission_AccumulatesAcrossReferrals() public {
        // bob refiere a alice y a carol: su saldo suma dos comisiones.
        vm.prank(alice);
        pass.subscribe{value: PRICE}(bob);
        vm.prank(carol);
        pass.subscribe{value: PRICE}(bob);

        assertEq(pass.pending(bob), COMMISSION * 2);
    }

    function test_Renewal_StacksTime() public {
        vm.startPrank(alice);
        pass.subscribe{value: PRICE}(bob);
        uint256 firstExpiry = pass.expiresAt(alice);
        vm.warp(block.timestamp + 10 days);
        pass.subscribe{value: PRICE}(bob);
        vm.stopPrank();

        assertEq(pass.expiresAt(alice), firstExpiry + PERIOD);
    }

    // ---- claim (pull pattern) ----

    function test_Claim_TransfersAndZeroes() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}(bob);

        uint256 before = bob.balance;
        vm.prank(bob);
        pass.claim();

        assertEq(bob.balance, before + COMMISSION, "bob recibe su comision");
        assertEq(pass.pending(bob), 0, "saldo en 0 tras claim");
    }

    function test_Claim_RevertsIfNothing() public {
        vm.prank(bob);
        vm.expectRevert(bytes("BotPass: nada para retirar"));
        pass.claim();
    }

    function test_Claim_OwnerClaimsItsShare() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}(bob);

        uint256 before = address(this).balance;
        pass.claim(); // owner = address(this)
        assertEq(address(this).balance, before + (PRICE - COMMISSION));
        assertEq(pass.pending(address(this)), 0);
    }

    // ---- admin ----

    function test_SetReferralBps_Updates() public {
        pass.setReferralBps(2500);
        assertEq(pass.referralBps(), 2500);
    }

    function test_SetReferralBps_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.setReferralBps(2500);
    }

    function test_SetReferralBps_CapsAt50pct() public {
        vm.expectRevert(bytes("BotPass: comision max 50%"));
        pass.setReferralBps(5001);
    }

    function test_SetPrice_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.setPrice(0.02 ether);
    }

    receive() external payable {}
}
