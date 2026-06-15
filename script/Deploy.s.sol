// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BotPassNFT} from "../src/BotPassNFT.sol";

/// @title Deploy — despliega BotPassNFT en cualquier red (Sepolia, Base/Arbitrum Sepolia)
/// @notice Lee la config de variables de entorno (.env) para no hardcodear nada
///         sensible. Corré:
///           forge script script/Deploy.s.sol:Deploy \
///             --rpc-url base_sepolia --broadcast --verify -vvvv
/// @dev `vm.envOr` usa un default si la variable no está seteada, así el deploy
///      no falla por una variable opcional vacía.
contract Deploy is Script {
    function run() external returns (BotPassNFT pass) {
        // Acepta PRIVATE_KEY con o sin prefijo "0x" (le agrega el 0x si falta).
        string memory pkStr = vm.envString("PRIVATE_KEY");
        if (bytes(pkStr).length == 64) {
            pkStr = string.concat("0x", pkStr);
        }
        uint256 pk = vm.parseUint(pkStr);

        // Parámetros del pase. Defaults pensados para una demo de testnet.
        uint256 price = vm.envOr("BOTPASS_PRICE", uint256(0.001 ether)); // por período
        uint256 period = vm.envOr("BOTPASS_PERIOD", uint256(30 days));   // duración
        string memory baseURI = vm.envOr("BOTPASS_BASE_URI", string("ipfs://"));

        vm.startBroadcast(pk);
        pass = new BotPassNFT(price, period, baseURI);
        vm.stopBroadcast();

        console.log("BotPassNFT desplegado en:", address(pass));
        console.log("  price (wei): ", price);
        console.log("  period (s):  ", period);
        console.log("Pega esta address en frontend/index.html (NETWORKS) y en el README.");
    }
}
