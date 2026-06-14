// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BotPass} from "../src/BotPass.sol";

/// @title Tests de BotPass v1
/// @notice Cada test arranca con un setUp() limpio. Usamos los "cheatcodes"
///         de Foundry (vm.*) para simular usuarios, plata y el paso del tiempo.
contract BotPassTest is Test {
    BotPass internal pass;

    // Parámetros del contrato bajo prueba (los mismos del README).
    uint256 internal constant PRICE = 0.01 ether;   // 0.01 ETH en wei
    uint256 internal constant PERIOD = 30 days;      // 2592000 segundos

    // Wallets de prueba. `owner` es address(this): quien despliega en setUp().
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        // address(this) (este contrato de test) será el owner del BotPass.
        pass = new BotPass(PRICE, PERIOD);

        // Le damos ETH falso a las wallets para que puedan pagar.
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    // ---- subscribe ----

    function test_Subscribe_ActivatesAccess() public {
        vm.prank(alice);                       // la próxima llamada la hace alice
        pass.subscribe{value: PRICE}();

        assertTrue(pass.isActive(alice), "alice deberia estar activa");
        assertEq(
            pass.expiresAt(alice),
            block.timestamp + PERIOD,
            "expiry = ahora + period"
        );
    }

    function test_Subscribe_RevertsIfInsufficient() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: pago insuficiente"));
        pass.subscribe{value: PRICE - 1}();
    }

    function test_Subscribe_AcceptsOverpayment() public {
        // Pagar de más no revierte; el acceso se otorga igual.
        vm.prank(alice);
        pass.subscribe{value: PRICE * 2}();
        assertTrue(pass.isActive(alice));
    }

    // ---- renovación ----

    function test_Renewal_StacksWhileActive() public {
        vm.startPrank(alice);
        pass.subscribe{value: PRICE}();
        uint256 firstExpiry = pass.expiresAt(alice);

        // Avanzamos 10 días (sigue vigente) y renueva: debe sumar sobre el expiry.
        vm.warp(block.timestamp + 10 days);
        pass.subscribe{value: PRICE}();
        vm.stopPrank();

        assertEq(
            pass.expiresAt(alice),
            firstExpiry + PERIOD,
            "renovacion vigente debe apilar"
        );
    }

    function test_Renewal_FromNowIfExpired() public {
        vm.startPrank(alice);
        pass.subscribe{value: PRICE}();

        // Pasamos MÁS allá del vencimiento: ya expiró.
        vm.warp(block.timestamp + PERIOD + 1 days);
        assertFalse(pass.isActive(alice), "deberia haber expirado");

        pass.subscribe{value: PRICE}();
        vm.stopPrank();

        // Como expiró, arranca desde ahora, no desde el viejo expiry.
        assertEq(pass.expiresAt(alice), block.timestamp + PERIOD);
    }

    // ---- isActive / timeLeft ----

    function test_IsActive_FalseForStranger() public view {
        assertFalse(pass.isActive(bob), "bob nunca pago");
    }

    function test_TimeLeft() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();
        assertEq(pass.timeLeft(alice), PERIOD, "recien suscripto: period completo");

        vm.warp(block.timestamp + 10 days);
        assertEq(pass.timeLeft(alice), PERIOD - 10 days);

        vm.warp(block.timestamp + PERIOD); // muy pasado el vencimiento
        assertEq(pass.timeLeft(alice), 0, "expirado: 0");
    }

    // ---- withdraw ----

    function test_Withdraw_OnlyOwner() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();

        vm.prank(bob); // bob no es owner
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.withdraw();
    }

    function test_Withdraw_TransfersBalance() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();

        // El owner es address(this). Medimos su balance antes/después.
        uint256 before = address(this).balance;
        pass.withdraw(); // llamado por address(this) = owner
        assertEq(address(this).balance, before + PRICE, "owner cobra lo recaudado");
        assertEq(address(pass).balance, 0, "contrato queda en 0");
    }

    // ---- setPrice ----

    function test_SetPrice_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.setPrice(0.02 ether);
    }

    function test_SetPrice_Updates() public {
        pass.setPrice(0.02 ether); // address(this) = owner
        assertEq(pass.price(), 0.02 ether);
    }

    // Necesario para que test_Withdraw_TransfersBalance reciba el ETH del withdraw.
    receive() external payable {}
}
