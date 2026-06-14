// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BotPassTiers} from "../src/BotPassTiers.sol";

contract BotPassTiersTest is Test {
    BotPassTiers internal pass;

    // Precios y duraciones por plan.
    uint256 internal constant BASIC_PRICE = 0.01 ether;
    uint256 internal constant PRO_PRICE   = 0.05 ether;
    uint256 internal constant VIP_PRICE   = 0.1 ether;
    uint256 internal constant MONTH = 30 days;
    uint256 internal constant QUARTER = 90 days;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        pass = new BotPassTiers(); // address(this) = owner

        // El owner configura los tres planes.
        pass.setPlan(BotPassTiers.Plan.Basic, BASIC_PRICE, MONTH, true);
        pass.setPlan(BotPassTiers.Plan.Pro, PRO_PRICE, MONTH, true);
        pass.setPlan(BotPassTiers.Plan.Vip, VIP_PRICE, QUARTER, true);

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    // ---- setPlan ----

    function test_SetPlan_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.setPlan(BotPassTiers.Plan.Basic, 1 ether, MONTH, true);
    }

    function test_SetPlan_StoresStruct() public view {
        (uint256 price, uint256 period, bool enabled) = pass.plans(BotPassTiers.Plan.Vip);
        assertEq(price, VIP_PRICE);
        assertEq(period, QUARTER);
        assertTrue(enabled);
    }

    // ---- subscribe ----

    function test_Subscribe_Basic() public {
        vm.prank(alice);
        pass.subscribe{value: BASIC_PRICE}(BotPassTiers.Plan.Basic);

        assertTrue(pass.isActive(alice));
        assertEq(pass.expiresAt(alice), block.timestamp + MONTH);
        assertEq(uint256(pass.planOf(alice)), uint256(BotPassTiers.Plan.Basic));
    }

    function test_Subscribe_VipUsesItsOwnPriceAndPeriod() public {
        vm.prank(alice);
        pass.subscribe{value: VIP_PRICE}(BotPassTiers.Plan.Vip);

        assertEq(pass.expiresAt(alice), block.timestamp + QUARTER);
        assertEq(uint256(pass.planOf(alice)), uint256(BotPassTiers.Plan.Vip));
    }

    function test_Subscribe_RevertsIfUnderpaysForPlan() public {
        // El precio de basic NO alcanza para vip.
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: pago insuficiente"));
        pass.subscribe{value: BASIC_PRICE}(BotPassTiers.Plan.Vip);
    }

    function test_Subscribe_RevertsIfPlanDisabled() public {
        // El owner apaga el plan Pro.
        pass.setPlan(BotPassTiers.Plan.Pro, PRO_PRICE, MONTH, false);

        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: plan no disponible"));
        pass.subscribe{value: PRO_PRICE}(BotPassTiers.Plan.Pro);
    }

    // ---- renovación / cambio de plan ----

    function test_ChangePlan_StacksTimeAndUpdatesPlan() public {
        vm.startPrank(alice);
        pass.subscribe{value: BASIC_PRICE}(BotPassTiers.Plan.Basic);
        uint256 firstExpiry = pass.expiresAt(alice);

        // Antes de vencer, sube a Vip: suma el período de Vip y queda como Vip.
        vm.warp(block.timestamp + 5 days);
        pass.subscribe{value: VIP_PRICE}(BotPassTiers.Plan.Vip);
        vm.stopPrank();

        assertEq(pass.expiresAt(alice), firstExpiry + QUARTER, "apila con periodo del nuevo plan");
        assertEq(uint256(pass.planOf(alice)), uint256(BotPassTiers.Plan.Vip));
    }

    // ---- lecturas ----

    function test_IsActive_FalseForStranger() public view {
        assertFalse(pass.isActive(bob));
    }

    function test_TimeLeft() public {
        vm.prank(alice);
        pass.subscribe{value: VIP_PRICE}(BotPassTiers.Plan.Vip);
        assertEq(pass.timeLeft(alice), QUARTER);

        vm.warp(block.timestamp + 30 days);
        assertEq(pass.timeLeft(alice), QUARTER - 30 days);

        vm.warp(block.timestamp + QUARTER);
        assertEq(pass.timeLeft(alice), 0);
    }

    // ---- withdraw ----

    function test_Withdraw_OnlyOwner() public {
        vm.prank(alice);
        pass.subscribe{value: VIP_PRICE}(BotPassTiers.Plan.Vip);

        vm.prank(bob);
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.withdraw();
    }

    function test_Withdraw_TransfersBalance() public {
        vm.prank(alice);
        pass.subscribe{value: VIP_PRICE}(BotPassTiers.Plan.Vip);

        uint256 before = address(this).balance;
        pass.withdraw();
        assertEq(address(this).balance, before + VIP_PRICE);
        assertEq(address(pass).balance, 0);
    }

    receive() external payable {}
}
