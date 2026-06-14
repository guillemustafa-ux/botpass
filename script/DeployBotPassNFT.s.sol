// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {BotPassNFT} from "../src/BotPassNFT.sol";

/// @title Script de deploy del pase NFT (v5)
/// @notice Despliega BotPassNFT con parámetros iniciales. Se corre con:
///         forge script script/DeployBotPassNFT.s.sol --rpc-url <URL> --broadcast
/// @dev Todo lo que va entre startBroadcast() y stopBroadcast() se manda como
///      transacción real, firmada con la clave que se le pasa a forge por CLI.
contract DeployBotPassNFT is Script {
    function run() external returns (BotPassNFT pass) {
        // Parámetros iniciales del contrato (editables).
        uint256 price = 0.01 ether;                 // precio por período, en wei
        uint256 period = 30 days;                   // 30 días
        string memory baseURI = "https://botpass.xyz/meta/"; // raíz de metadata

        vm.startBroadcast();                        // <-- desde acá, transacciones reales
        pass = new BotPassNFT(price, period, baseURI);
        vm.stopBroadcast();

        console.log("BotPassNFT desplegado en:", address(pass));
        console.log("owner:", pass.owner());
        console.log("price (wei):", pass.price());
        console.log("period (s):", pass.period());
    }
}
