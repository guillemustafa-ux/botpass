// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BotPass — Suscripción on-chain por tiempo
/// @notice El cliente paga en ETH y recibe acceso por un período.
///         Tus bots off-chain consultan isActive(user) antes de
///         enviar señales. Pagar de nuevo extiende el vencimiento.
contract BotPass {
    // ---- Estado (vive en la blockchain, persiste para siempre) ----

    address public owner;   // quién cobra y administra (vos)
    uint256 public price;   // precio por período, en wei (1 ETH = 1e18 wei)
    uint256 public period;  // duración del período, en segundos

    // mapping: por cada wallet, el timestamp en que se le vence el acceso.
    // Si nunca se suscribió, vale 0 (el default de todo en Solidity).
    mapping(address => uint256) public expiresAt;

    // ---- Eventos (logs baratos que tu bot puede escuchar off-chain) ----

    event Subscribed(address indexed user, uint256 newExpiry, uint256 paid);
    event Withdrawn(address indexed to, uint256 amount);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);

    // ---- Constructor (corre UNA sola vez, al desplegar) ----

    constructor(uint256 _price, uint256 _period) {
        owner = msg.sender;   // quien despliega es el dueño
        price = _price;
        period = _period;
    }

    // ---- Modifier (chequeo reutilizable que se pega a una función) ----

    modifier onlyOwner() {
        require(msg.sender == owner, "BotPass: solo el owner");
        _;  // aquí se inserta el cuerpo de la función que use el modifier
    }

    // ---- Funciones que cambian estado ----

    /// @notice El cliente llama esto enviando ETH para suscribirse/renovar.
    /// @dev `payable` permite que la función reciba ETH (msg.value).
    function subscribe() external payable {
        require(msg.value >= price, "BotPass: pago insuficiente");

        // Si todavía tiene acceso vigente, sumamos sobre su vencimiento.
        // Si ya venció (o nunca pagó), arrancamos desde ahora.
        uint256 base = expiresAt[msg.sender] > block.timestamp
            ? expiresAt[msg.sender]
            : block.timestamp;

        expiresAt[msg.sender] = base + period;

        emit Subscribed(msg.sender, expiresAt[msg.sender], msg.value);
    }

    /// @notice El owner retira todo el ETH acumulado en el contrato.
    /// @dev Patrón seguro: usar .call y chequear el resultado.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = owner.call{value: amount}("");
        require(ok, "BotPass: retiro fallido");
        emit Withdrawn(owner, amount);
    }

    /// @notice El owner cambia el precio (en wei).
    function setPrice(uint256 _newPrice) external onlyOwner {
        emit PriceChanged(price, _newPrice);
        price = _newPrice;
    }

    // ---- Funciones de lectura (gratis, no cambian estado: `view`) ----

    /// @notice ¿Este usuario tiene acceso activo ahora mismo?
    ///         Tu bot llama esto antes de mandar señales.
    function isActive(address user) external view returns (bool) {
        return expiresAt[user] >= block.timestamp;
    }

    /// @notice Cuántos segundos de acceso le quedan (0 si ya venció).
    function timeLeft(address user) external view returns (uint256) {
        if (expiresAt[user] <= block.timestamp) return 0;
        return expiresAt[user] - block.timestamp;
    }
}
