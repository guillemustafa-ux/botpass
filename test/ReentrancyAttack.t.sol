// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BotPassReferral} from "../src/BotPassReferral.sol";

// ===========================================================================
// PARTE 1 — Un vault VULNERABLE, para demostrar que el reentrancy es real.
// Hace lo prohibido: manda la plata ANTES de poner el saldo en 0 (viola CEI).
// ===========================================================================
contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nada");

        // ⚠️ INTERACTION antes que EFFECT: este es el bug.
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "fallo");

        balances[msg.sender] = 0; // el saldo se limpia DESPUÉS (tarde)
    }
}

/// @notice Atacante del vault vulnerable. Su receive() re-entra a withdraw()
///         mientras su saldo sigue cargado, drenando todo el contrato.
contract VaultAttacker {
    VulnerableVault public vault;
    uint256 public stake;

    constructor(VulnerableVault _vault) {
        vault = _vault;
    }

    function attack() external payable {
        stake = msg.value;
        vault.deposit{value: msg.value}();
        vault.withdraw(); // dispara el primer retiro → cae en receive()
    }

    receive() external payable {
        // Mientras el vault tenga con qué pagar, seguimos re-entrando.
        if (address(vault).balance >= stake) {
            vault.withdraw();
        }
    }
}

// ===========================================================================
// PARTE 2 — Atacante de NUESTRO contrato (BotPassReferral), que SÍ está
// protegido (CEI + nonReentrant). Su receive() intenta re-entrar a claim().
// ===========================================================================
contract ClaimAttacker {
    BotPassReferral public pass;

    constructor(BotPassReferral _pass) {
        pass = _pass;
    }

    function attack() external {
        pass.claim();
    }

    receive() external payable {
        // Intento de re-entrada: con el candado puesto, esto revierte.
        pass.claim();
    }
}

// ===========================================================================
// Tests
// ===========================================================================
contract ReentrancyAttackTest is Test {
    function test_Reentrancy_IsARealThreat() public {
        VulnerableVault vault = new VulnerableVault();

        // Una víctima deposita 3 ETH legítimamente.
        address victim = makeAddr("victim");
        vm.deal(victim, 3 ether);
        vm.prank(victim);
        vault.deposit{value: 3 ether}();

        // El atacante deposita solo 1 ETH y drena TODO con reentrancy.
        VaultAttacker attacker = new VaultAttacker(vault);
        vm.deal(address(this), 1 ether);
        attacker.attack{value: 1 ether}();

        // Robó su 1 ETH + los 3 de la víctima.
        assertEq(address(vault).balance, 0, "vault vaciado");
        assertEq(address(attacker).balance, 4 ether, "atacante se llevo todo");
    }

    function test_BotPassReferral_BlocksReentrancy() public {
        // Desplegamos nuestro contrato protegido (precio 0.01, 30d, comision 10%).
        BotPassReferral pass = new BotPassReferral(0.01 ether, 30 days, 1000);

        // El atacante figura como referidor → acumula comisión en su `pending`.
        ClaimAttacker attacker = new ClaimAttacker(pass);
        address alice = makeAddr("alice");
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        pass.subscribe{value: 0.01 ether}(address(attacker));

        uint256 balBefore = address(pass).balance;          // = 0.01 ETH
        uint256 owedToAttacker = pass.pending(address(attacker));
        assertGt(owedToAttacker, 0, "el atacante tiene saldo a cobrar");

        // El ataque falla: la re-entrada choca con el candado, todo revierte.
        vm.expectRevert();
        attacker.attack();

        // Nada se movió: fondos del contrato intactos, saldo del atacante igual.
        assertEq(address(pass).balance, balBefore, "fondos intactos");
        assertEq(pass.pending(address(attacker)), owedToAttacker, "saldo sin tocar");
    }

    receive() external payable {}
}
