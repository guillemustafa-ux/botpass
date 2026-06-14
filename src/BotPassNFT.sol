// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Importamos contratos YA HECHOS y auditados de OpenZeppelin.
// ERC721 = el estándar de NFTs (ownerOf, transferFrom, balanceOf, etc.).
// Ownable = el patrón owner/onlyOwner, listo para usar.
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BotPass v5 — El pase de suscripción ES un NFT (ERC-721)
/// @notice Al suscribirse, el cliente recibe un NFT. El acceso vive en el NFT,
///         no en la wallet: si lo transfiere o lo vende, el acceso viaja con él.
///         El bot off-chain consulta ownerOf(tokenId) + isActive(tokenId).
/// @dev `is ERC721, Ownable` = HERENCIA: heredamos todo el comportamiento de
///      esos contratos y solo agregamos lo nuestro encima.
contract BotPassNFT is ERC721, Ownable {
    uint256 public price;    // precio por período, en wei
    uint256 public period;   // duración del período, en segundos
    uint256 public nextId = 1; // contador para asignar tokenIds únicos

    string private _baseTokenURI; // raíz de la metadata (imagen, nombre del pase)

    // Vencimiento por NFT (no por wallet): la clave es el tokenId.
    mapping(uint256 => uint256) public expiresAt;

    event PassMinted(address indexed to, uint256 indexed tokenId, uint256 expiry);
    event PassRenewed(uint256 indexed tokenId, uint256 newExpiry);

    /// @dev El constructor "pasa" argumentos a los constructores que heredamos:
    ///      ERC721 quiere nombre y símbolo; Ownable quiere quién es el dueño.
    constructor(uint256 _price, uint256 _period, string memory baseURI_)
        ERC721("BotPass", "BPASS")
        Ownable(msg.sender)
    {
        price = _price;
        period = _period;
        _baseTokenURI = baseURI_;
    }

    /// @notice Suscribirse: paga y recibe un NFT nuevo con su propio vencimiento.
    function subscribe() external payable returns (uint256 tokenId) {
        require(msg.value >= price, "BotPass: pago insuficiente");

        tokenId = nextId++;                          // 1, 2, 3, ...
        expiresAt[tokenId] = block.timestamp + period;
        _safeMint(msg.sender, tokenId);              // crea el NFT (heredado de ERC721)

        emit PassMinted(msg.sender, tokenId, expiresAt[tokenId]);
    }

    /// @notice Renovar un pase existente. Cualquiera puede pagar la renovación
    ///         de un tokenId (útil: te renuevan el pase de regalo).
    function renew(uint256 tokenId) external payable {
        require(msg.value >= price, "BotPass: pago insuficiente");
        _requireOwned(tokenId); // revierte si el NFT no existe (OZ v5)

        uint256 base = expiresAt[tokenId] > block.timestamp
            ? expiresAt[tokenId]
            : block.timestamp;
        expiresAt[tokenId] = base + period;

        emit PassRenewed(tokenId, expiresAt[tokenId]);
    }

    // ---- Lecturas (el bot consulta esto) ----

    function isActive(uint256 tokenId) external view returns (bool) {
        return expiresAt[tokenId] >= block.timestamp;
    }

    function timeLeft(uint256 tokenId) external view returns (uint256) {
        if (expiresAt[tokenId] <= block.timestamp) return 0;
        return expiresAt[tokenId] - block.timestamp;
    }

    // ---- Admin (onlyOwner viene de Ownable) ----

    function withdraw() external onlyOwner {
        (bool ok, ) = owner().call{value: address(this).balance}("");
        require(ok, "BotPass: retiro fallido");
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        price = _newPrice;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    /// @dev override: ERC721 arma tokenURI como _baseURI() + tokenId. Acá le
    ///      decimos cuál es esa raíz. (`override` = estamos reemplazando una
    ///      función que heredamos.)
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
