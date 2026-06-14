// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BotPassNFT} from "../src/BotPassNFT.sol";

contract BotPassNFTTest is Test {
    BotPassNFT internal pass;

    uint256 internal constant PRICE = 0.01 ether;
    uint256 internal constant PERIOD = 30 days;
    string internal constant BASE_URI = "https://botpass.xyz/meta/";

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        pass = new BotPassNFT(PRICE, PERIOD, BASE_URI); // address(this) = owner
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    // ---- subscribe / mint ----

    function test_Subscribe_MintsNFT() public {
        vm.prank(alice);
        uint256 id = pass.subscribe{value: PRICE}();

        assertEq(id, 1, "primer tokenId");
        assertEq(pass.ownerOf(1), alice, "alice es duena del NFT");
        assertEq(pass.balanceOf(alice), 1);
        assertTrue(pass.isActive(1));
        assertEq(pass.expiresAt(1), block.timestamp + PERIOD);
    }

    function test_Subscribe_RevertsIfInsufficient() public {
        vm.prank(alice);
        vm.expectRevert(bytes("BotPass: pago insuficiente"));
        pass.subscribe{value: PRICE - 1}();
    }

    function test_TokenIds_Increment() public {
        vm.prank(alice);
        uint256 a = pass.subscribe{value: PRICE}();
        vm.prank(bob);
        uint256 b = pass.subscribe{value: PRICE}();

        assertEq(a, 1);
        assertEq(b, 2);
    }

    // ---- LA CLAVE: el acceso viaja con el NFT ----

    function test_Transfer_AccessTravelsWithNFT() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}(); // alice tiene el pase #1, activo

        // alice le transfiere el NFT a bob (función heredada de ERC721).
        vm.prank(alice);
        pass.transferFrom(alice, bob, 1);

        // Ahora el dueño es bob, y el acceso (vencimiento por tokenId) sigue vivo.
        assertEq(pass.ownerOf(1), bob, "bob ahora es el dueno");
        assertEq(pass.balanceOf(alice), 0);
        assertEq(pass.balanceOf(bob), 1);
        assertTrue(pass.isActive(1), "el acceso viajo con el NFT");
    }

    // ---- renew ----

    function test_Renew_ExtendsExpiry() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();
        uint256 firstExpiry = pass.expiresAt(1);

        vm.warp(block.timestamp + 10 days);
        // Cualquiera puede pagar la renovación; acá la paga bob de regalo.
        vm.prank(bob);
        pass.renew{value: PRICE}(1);

        assertEq(pass.expiresAt(1), firstExpiry + PERIOD, "apila el periodo");
    }

    function test_Renew_RevertsForNonexistentToken() public {
        vm.prank(alice);
        vm.expectRevert(); // OZ revierte con ERC721NonexistentToken
        pass.renew{value: PRICE}(999);
    }

    function test_TimeLeft() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();
        assertEq(pass.timeLeft(1), PERIOD);

        vm.warp(block.timestamp + 10 days);
        assertEq(pass.timeLeft(1), PERIOD - 10 days);

        vm.warp(block.timestamp + PERIOD);
        assertEq(pass.timeLeft(1), 0);
    }

    // ---- metadata ----

    function test_TokenURI_UsesBaseURIPlusId() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();
        assertEq(pass.tokenURI(1), "https://botpass.xyz/meta/1");
    }

    function test_NameAndSymbol() public view {
        assertEq(pass.name(), "BotPass");
        assertEq(pass.symbol(), "BPASS");
    }

    // ---- admin ----

    function test_Withdraw_OnlyOwner() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();

        vm.prank(bob);
        vm.expectRevert(); // Ownable: OwnableUnauthorizedAccount
        pass.withdraw();
    }

    function test_Withdraw_TransfersBalance() public {
        vm.prank(alice);
        pass.subscribe{value: PRICE}();

        uint256 before = address(this).balance;
        pass.withdraw(); // owner = address(this)
        assertEq(address(this).balance, before + PRICE);
        assertEq(address(pass).balance, 0);
    }

    function test_SetPrice_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        pass.setPrice(0.02 ether);
    }

    receive() external payable {}
}
