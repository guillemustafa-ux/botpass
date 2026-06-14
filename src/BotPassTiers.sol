// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BotPass v3 — Suscripción con planes por niveles (basic / pro / vip)
/// @notice Como v1 (paga en ETH), pero ahora hay varios planes con precio y
///         duración distintos. El bot off-chain consulta isActive(user) y
///         planOf(user) para saber QUÉ señales mandarle según su nivel.
contract BotPassTiers {
    // ---- enum: una lista cerrada de opciones con nombre ----
    // Por debajo es un número: Basic=0, Pro=1, Vip=2. Usar el nombre es más
    // claro y seguro que andar pasando 0/1/2 sueltos.
    enum Plan { Basic, Pro, Vip }

    // ---- struct: agrupa varios datos relacionados en un solo "paquete" ----
    // En vez de tres mappings separados (precio, duración, activo), guardamos
    // un PlanInfo por cada plan.
    struct PlanInfo {
        uint256 price;    // precio del plan, en wei
        uint256 period;   // duración del plan, en segundos
        bool    enabled;  // si está disponible para comprar (el owner lo prende/apaga)
    }

    // ---- Estado ----

    address public owner;

    // Config de cada plan. mapping(enum => struct).
    mapping(Plan => PlanInfo) public plans;

    mapping(address => uint256) public expiresAt;  // vencimiento por usuario
    mapping(address => Plan)    public planOf;     // qué plan tiene cada usuario

    // ---- Eventos ----

    event PlanConfigured(Plan indexed plan, uint256 price, uint256 period, bool enabled);
    event Subscribed(address indexed user, Plan indexed plan, uint256 newExpiry, uint256 paid);
    event Withdrawn(address indexed to, uint256 amount);

    // ---- Constructor ----
    // Arranca sin planes configurados; el owner los define con setPlan().
    constructor() {
        owner = msg.sender;
    }

    // ---- Modifier ----

    modifier onlyOwner() {
        require(msg.sender == owner, "BotPass: solo el owner");
        _;
    }

    // ---- Admin ----

    /// @notice El owner crea o actualiza un plan.
    /// @dev PlanInfo(...) construye el struct posicionalmente.
    function setPlan(Plan plan, uint256 price, uint256 period, bool enabled)
        external
        onlyOwner
    {
        plans[plan] = PlanInfo(price, period, enabled);
        emit PlanConfigured(plan, price, period, enabled);
    }

    // ---- Suscripción ----

    /// @notice El cliente elige y paga un plan. Renovar/cambiar de plan extiende
    ///         el vencimiento usando el período del plan que compra ahora, y
    ///         registra ese plan como el suyo.
    function subscribe(Plan plan) external payable {
        // memory: copiamos el struct a memoria para leerlo cómodo (más barato
        // que leer cada campo del storage por separado).
        PlanInfo memory p = plans[plan];
        require(p.enabled, "BotPass: plan no disponible");
        require(msg.value >= p.price, "BotPass: pago insuficiente");

        uint256 base = expiresAt[msg.sender] > block.timestamp
            ? expiresAt[msg.sender]
            : block.timestamp;

        expiresAt[msg.sender] = base + p.period;
        planOf[msg.sender] = plan;

        emit Subscribed(msg.sender, plan, expiresAt[msg.sender], msg.value);
    }

    /// @notice El owner retira el ETH recaudado.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = owner.call{value: amount}("");
        require(ok, "BotPass: retiro fallido");
        emit Withdrawn(owner, amount);
    }

    // ---- Lecturas ----

    function isActive(address user) external view returns (bool) {
        return expiresAt[user] >= block.timestamp;
    }

    function timeLeft(address user) external view returns (uint256) {
        if (expiresAt[user] <= block.timestamp) return 0;
        return expiresAt[user] - block.timestamp;
    }
}
