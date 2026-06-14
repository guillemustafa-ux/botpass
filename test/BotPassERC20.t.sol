// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BotPassERC20} from "../src/BotPassERC20.sol";

/// @notice ERC20 mínimo y "bien portado" (devuelve bool) para testear.
///         Imita USDT en que usa 6 decimales. Las restas en 0.8 revierten
///         si no alcanza el saldo/allowance, así que no hace falta require.
contract MockERC20 {
    string public name = "Mock USD";
    string public symbol = "mUSDT";
    uint8 public decimals = 6;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount; // revierte si no hay permiso
        balanceOf[from] -= amount;             // revierte si no hay saldo
        balanceOf[to] += amount;
        return true;
    }
}

contract BotPassERC20Test is Test {
    MockERC20 internal usdt;
    BotPassERC20 internal pass;

    uint256 internal constant PRICE = 10_000000;   // 10 USDT (6 decimales)
    uint256 internal constant PERIOD = 30 days;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        usdt = new MockERC20();
        // address(this) (este test) es el owner del BotPass.
        pass = new BotPassERC20(address(usdt), PRICE, PERIOD);

        // Le damos tokens a las wallets de prueba.
        usdt.mint(alice, 100_000000); // 100 USDT
        usdt.mint(bob, 100_000000);
    }

    /// Helper: aprobar + suscribir como `user`.
    function _subscribeAs(address user) internal {
        vm.prank(user);
        usdt.approve(address(pass), PRICE);
        vm.prank(user);
        pass.subscribe();
    }

    // ---- subscribe ----

    function test_Subscribe_RequiresApprove() public {
        // Sin approve previo, transferFrom revierte (allowance en 0).
        vm.prank(alice);
        vm.expectRevert();
        pass.subscribe();
    }

    function test_Subscribe_ActivatesAndPullsTokens() public {
        _subscribeAs(alice);

        assertTrue(pass.isActive(alice), "alice deberia estar activa");
        assertEq(pass.expiresAt(alice), block.timestamp + PERIOD);
        // El contrato cobró exactamente PRICE; a alice le descontaron PRICE.
        assertEq(usdt.balanceOf(address(pass)), PRICE, "contrato cobro price");
        assertEq(usdt.balanceOf(alice), 100_000000 - PRICE, "a alice le sacaron price");
    }

    // ---- renovación ----

    function test_Renewal_StacksWhileActive() public {
        _subscribeAs(alice);
        uint256 firstExpiry = pass.expiresAt(alice);

        vm.warp(block.timestamp + 10 days);
        _subscribeAs(alice);

        assertEq(pass.expiresAt(alice), firstExpiry + PERIOD, "renovacion vigente apila");
        assertEq(usdt.balanceOf(address(pass)), PRICE * 2, "cobro dos veces");
    }

    function test_Renewal_FromNowIfExpired() public {
        _subscribeAs(alice);

        vm.warp(block.timestamp + PERIOD + 1 days); // ya expiró
        assertFalse(pass.isActive(alice));

        _subscribeAs(alice);
        assertEq(pass.expiresAt(alice), block.timestamp + PERIOD);
    }

    // ---- isActive / timeLeft ----

    function test_IsActive_FalseForStranger() public view {
        assertFalse(pass.isActive(bob));
    }

    function test_TimeLeft() public {
        _subscribeAs(alice);
        assertEq(pass.timeLeft(alice), PERIOD);

        vm.warp(block.timestamp + 10 days);
        assertEq(pass.timeLeft(alice), PERIOD - 10 days);

        vm.warp(block.timestamp + PERIOD);
        assertEq(pass.timeLeft(alice), 0);
    }

    // ---- withdraw ----

    function test_Withdraw_OnlyOwner() public {
        _subscribeAs(alice);
        vm.prank(bob);
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.withdraw();
    }

    function test_Withdraw_TransfersTokens() public {
        _subscribeAs(alice);
        _subscribeAs(bob); // contrato tiene 2 * PRICE

        uint256 before = usdt.balanceOf(address(this)); // owner = address(this)
        pass.withdraw();
        assertEq(usdt.balanceOf(address(this)), before + PRICE * 2, "owner cobra todo");
        assertEq(usdt.balanceOf(address(pass)), 0, "contrato queda en 0");
    }

    // ---- setPrice ----

    function test_SetPrice_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: solo el owner"));
        pass.setPrice(20_000000);
    }

    function test_SetPrice_Updates() public {
        pass.setPrice(20_000000);
        assertEq(pass.price(), 20_000000);
    }
}
